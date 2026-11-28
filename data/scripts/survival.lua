-- Exosuit survival and death modes (exosuit-survival and death-modes specs). The suit's systems, each 0..1:
-- oxygen (used up where the air cannot be breathed), filter (saturates with toxins; once full, toxins breach the suit),
-- power (spent faster in heat or cold; once empty, the heat or cold breaches it) and integrity (the suit itself:
-- toxins without a filter, radiation, no oxygen, falls and bites take it). Radiation adds up as a dose. Inside a doll
-- (seated or walking) everything is restored. Dolls take damage too (a sinkhole that gives way under them).
-- When the integrity is gone the Commander dies. What then depends on the run's mode, chosen for a new game:
--   clone: the Commander wakes in the Jump Ship's clone bay; the dolls stay where they are, a spare suit in the hold
--          the lost one came from;
--   legacy: the run ends; what was discovered goes into the codex (kept with fk.storage across runs) for the next
--           Commander.
local sim = require("fk.sim")
local save = require("fk.save")
local store = require("settings.store")
local chain = require("chain")
local sensors = require("sensors")
local environment = require("environment")
local interior = require("interior")

local survival = {}

survival.SETTING = { death = { "clone", "legacy" } } -- the game setting (menu): the mode of new runs
survival.RESTORE = 10       -- seconds for a doll to restore the suit from empty
survival.OXYGEN = 600       -- seconds of oxygen
survival.FILTER = 90        -- seconds of filter at toxin 1
survival.POWER = 1800       -- seconds of power in mild weather
survival.CHECK = 10         -- ticks between ground checks (sinkholes, discoveries)

function survival.setting()
  return store.load("game", { death = "clone" }, survival.SETTING)
end

function survival.save_setting(s) fk.storage.save("game", store.encode(s, survival.SETTING)) end

function survival.state() return sim.get(survival.id, "survival") end

-- The codex: what every Commander so far discovered {hazards = {kind = true}, worlds = {key = true}, species =
-- {name = true}, commanders = n}.
function survival.codex()
  local text = fk.storage.load("codex")
  local ok, codex = pcall(function() return text and save.decode(text) end)
  codex = ok and type(codex) == "table" and codex or {}
  codex.hazards, codex.worlds, codex.species = codex.hazards or {}, codex.worlds or {}, codex.species or {}
  codex.commanders = codex.commanders or 0
  return codex
end

function survival.codex_size(codex)
  local n = 0
  for _, group in ipairs({ codex.hazards, codex.worlds, codex.species }) do
    for _ in pairs(group) do n = n + 1 end
  end
  return n
end

function survival.install()
  survival.id = sim.create()
  sim.set(survival.id, "survival", { oxygen = 1, filter = 1, power = 1, integrity = 1, dose = 0,
    mode = survival.setting().death, deaths = 0, over = false, found = { hazards = {}, worlds = {}, species = {} } })
  sim.on("mode", function(args) -- (a new run's mode; tests)
    if args.mode == "clone" or args.mode == "legacy" then survival.state().mode = args.mode end
  end)
end

local function hurt(s, amount)
  local before = s.integrity
  s.integrity = math.max(0, s.integrity - amount)
  if math.ceil(before * 4) > math.ceil(s.integrity * 4) and s.integrity > 0 then -- below each quarter: a breach
    local p = chain.suit()
    sim.emit("breach", { position = { p.x, p.y, p.z }, integrity = math.ceil(s.integrity * 4) / 4, strength = 0.8 })
  end
end
survival.hurt = function(amount) hurt(survival.state(), amount) end

local function die(s)
  local p = chain.suit()
  s.deaths = s.deaths + 1
  sim.emit("death", { position = { p.x, p.y, p.z }, mode = s.mode, strength = 1 })
  if s.mode == "legacy" then -- the run ends; the codex carries what was found
    s.over = true
    local codex = survival.codex()
    for group, list in pairs(s.found) do
      for k in pairs(list) do codex[group][k] = true end
    end
    codex.commanders = codex.commanders + 1
    fk.storage.save("codex", save.encode(codex))
    return
  end
  local cs = chain.state() -- clone mode: the suit is lost where it fell; a spare waits in the hold it came from
  local suit = chain.current()
  if suit.kind == "exosuit" then
    for i, d in ipairs(cs.dolls) do
      if d == suit then table.remove(cs.dolls, i) break end
    end
    local parent = suit.parent and chain.find(suit.parent)
    if parent then parent.hold.exosuit = (parent.hold.exosuit or 0) + 1 end
  end
  for _, d in ipairs(cs.dolls) do
    if d.kind == "jump_ship" then
      local bay
      for _, f in ipairs(interior.layout("jump_ship").fixtures) do
        if f[1] == "clone" then bay = f end
      end
      cs.at, cs.walk = d.id, { doll = d.id, x = bay[2], z = bay[3] }
    end
  end
  s.oxygen, s.filter, s.power, s.integrity = 1, 1, 1, 1
  sim.emit("clone", { position = { p.x, p.y, p.z }, strength = 1 })
end

-- Each tick (after the chain's and the sensors'): the suit's systems where the Commander is; sinkholes; discoveries.
function survival.tick()
  local s = survival.state()
  if s.over then return end
  local dt = sim.dt
  if chain.on_foot() then
    local p = chain.suit()
    local e = environment.at(p.x, p.z)
    if not e.breathable then s.oxygen = math.max(0, s.oxygen - dt / survival.OXYGEN) end
    if s.oxygen <= 0 then hurt(s, dt * 0.1) end
    if e.toxin > 0 then
      if s.filter > 0 then s.filter = math.max(0, s.filter - dt * e.toxin / survival.FILTER)
      else hurt(s, dt * e.toxin * 0.05) end
    end
    local extreme = math.max(0, math.abs(e.temperature - 293) - 60) / 100
    s.power = math.max(0, s.power - dt * (1 + extreme * 20) / survival.POWER)
    if s.power <= 0 then hurt(s, dt * 0.02 * (1 + extreme)) end
    if e.fire > 0 then hurt(s, dt * e.fire * 0.08) end
    s.dose = s.dose + e.radiation * dt
    if e.radiation > 0 then hurt(s, dt * e.radiation * 0.01) end
  else -- inside a doll: air, a fresh filter, charge and repairs
    local r = dt / survival.RESTORE
    s.oxygen, s.filter, s.power = math.min(1, s.oxygen + r), math.min(1, s.filter + r), math.min(1, s.power + r)
    s.integrity = math.min(1, s.integrity + r)
  end
  if sim.tick % survival.CHECK == 0 then
    for _, h in ipairs(sensors.hazards()) do -- a sinkhole gives way under whatever stands on it
      if h.kind == "sinkhole" and not h.collapsed then
        for _, d in ipairs(chain.state().dolls) do
          local dx, dz = d.x - h.x, d.z - h.z
          if chain.here(d) and require("dolls").by_id[d.kind].place == "ground" and dx * dx + dz * dz < h.size * h.size * 0.25 then
            h.collapsed = true
            if d.kind == "exosuit" then hurt(s, 0.6) else d.damage = math.min(1, (d.damage or 0) + 0.4) end
            sim.emit("collapse", { position = { d.x, d.y, d.z }, kind = d.kind, strength = 1 })
          end
        end
      end
    end
    for _, c in pairs(sensors.state().contacts) do s.found.hazards[c.kind] = true end
    if sensors.state().world then s.found.worlds[sensors.state().world] = true end
  end
  if s.integrity <= 0 then die(s) end
end

-- The visor's suit lines (presentation).
function survival.lines()
  local s = survival.state()
  local function pct(v) return string.format("%3d%%", math.floor(v * 100 + 0.5)) end
  return { "O2 " .. pct(s.oxygen) .. "  FILTER " .. pct(s.filter), "PWR " .. pct(s.power) .. "  HULL " .. pct(s.integrity),
    string.format("DOSE %.1f", s.dose) }
end

return survival
