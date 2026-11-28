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
  codex.artifacts, codex.names = codex.artifacts or {}, codex.names or {}
  codex.commanders = codex.commanders or 0
  return codex
end

function survival.codex_size(codex)
  local n = 0
  for _, group in ipairs({ codex.hazards, codex.worlds, codex.species, codex.artifacts or {} }) do
    for _ in pairs(group) do n = n + 1 end
  end
  return n
end

function survival.install()
  survival.id = sim.create()
  sim.set(survival.id, "survival", { oxygen = 1, filter = 1, power = 1, integrity = 1, dose = 0,
    mode = survival.setting().death, deaths = 0, over = false, found = { hazards = {}, worlds = {}, species = {}, artifacts = {} } })
  sim.on("mode", function(args) -- (a new run's mode; tests)
    if args.mode == "clone" or args.mode == "legacy" then survival.state().mode = args.mode end
  end)
end

local function hurt(s, amount)
  amount = amount * (survival.armour and survival.armour() or 1) -- (research.lua: tougher armour)
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
      local items = require("economy").state().items -- (economy.lua: crafted cartridges and kits)
      if s.filter <= 0 and (items.filter or 0) > 0 then s.filter, items.filter = 1, items.filter - 1 end -- a fresh cartridge
      local life = survival.FILTER * (survival.filter_factor and survival.filter_factor() or 1)
      if s.filter > 0 then s.filter = math.max(0, s.filter - dt * e.toxin / life)
      else hurt(s, dt * e.toxin * 0.05) end
    end
    local extreme = math.max(0, math.abs(e.temperature - 293) - 60) / 100
    s.power = math.max(0, s.power - dt * (1 + extreme * 20) / survival.POWER)
    if s.power <= 0 then hurt(s, dt * 0.02 * (1 + extreme)) end
    if e.fire > 0 then hurt(s, dt * e.fire * 0.08) end
    s.dose = s.dose + e.radiation * dt
    if e.radiation > 0 then hurt(s, dt * e.radiation * 0.01) end
  else -- inside a doll: air, a fresh filter, charge and repairs
    survival.restore()
  end
  local items = require("economy").state().items
  if s.integrity > 0 and s.integrity < 0.3 and (items.repair or 0) > 0 then -- a repair kit, used at once
    s.integrity, items.repair = math.min(1, s.integrity + 0.5), items.repair - 1
    sim.emit("repaired", { position = { chain.suit().x, chain.suit().y + 1, chain.suit().z }, strength = 0.5 })
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
    for _, c in pairs(sensors.state().contacts) do
      s.found.hazards[c.kind] = true
      if (c.kind == "grazer" or c.kind == "predator") and sensors.state().world then -- (ecology.lua: its species)
        s.found.species[require("ecology").species_cached(sensors.state().world)[c.kind].name] = true
      end
    end
    local key = sensors.state().world
    if key then
      s.found.worlds[key] = true
      if require("artifacts").progress(key).solved then s.found.artifacts[key] = true end -- (artifacts.lua: a solved ruin)
    end
  end
  if s.integrity <= 0 then die(s) end
end

-- The codex menu (codex spec; X): what is known, and names for the species found. Names are kept with the codex in
-- fk.storage, for every Commander after.
local SYLLABLES = { "al", "be", "cor", "da", "el", "fi", "gor", "hal", "in", "jo", "ka", "lu", "mer", "no" }

function survival.names_for(species)
  local rng, out = fk.rng("species-names", species), {}
  for i = 1, 3 do
    local n = ""
    for _ = 1, rng:range(2, 3) do n = n .. SYLLABLES[rng:range(1, #SYLLABLES)] end
    out[i] = n:upper()
  end
  return out
end

local function unnamed()
  local codex, out = survival.codex(), {}
  for name in pairs(survival.state().found.species) do
    if not codex.names[name] then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

function survival.install_codex()
  local dialogue = require("dialogue")
  dialogue.register("codex", { start = {}, nodes = {
    codex = {
      text = function()
        local codex, run = survival.codex(), survival.state().found
        local this = survival.codex_size({ hazards = run.hazards, worlds = run.worlds, species = run.species, artifacts = run.artifacts })
        local named = {}
        for k, v in pairs(codex.names) do named[#named + 1] = k .. " IS " .. v end
        table.sort(named)
        return string.format("CODEX: %d ENTRIES, %d THIS RUN, %d COMMANDERS. %s", survival.codex_size(codex), this,
          codex.commanders, table.concat(named, ". "))
      end,
      options = function()
        local out = {}
        for _, name in ipairs(unnamed()) do
          if #out < 3 then out[#out + 1] = { "Name the " .. name, go = "name", act = function(o) o.species = name end } end
        end
        out[#out + 1] = { "Done" }
        return out
      end },
    name = {
      text = function(o) return "NAME THE " .. o.species .. ":" end,
      options = function(o)
        local out = {}
        for _, n in ipairs(survival.names_for(o.species)) do
          out[#out + 1] = { n, go = "codex", act = function(open)
            local codex = survival.codex()
            codex.names[open.species] = n
            fk.storage.save("codex", save.encode(codex))
            sim.emit("named", { position = { chain.suit().x, chain.suit().y, chain.suit().z }, strength = 0.3 })
          end }
        end
        out[#out + 1] = { "Back", go = "codex" }
        return out
      end },
  } })
  sim.on("codex", function() if not dialogue.open() then dialogue.menu("codex", "codex") end end)
end

-- A tick of restoring the suit (inside a doll, or by an outpost's power).
function survival.restore()
  local s, r = survival.state(), sim.dt / survival.RESTORE
  s.oxygen, s.filter, s.power = math.min(1, s.oxygen + r), math.min(1, s.filter + r), math.min(1, s.power + r)
  s.integrity = math.min(1, s.integrity + r)
end

-- The visor's suit lines (presentation).
function survival.lines()
  local s = survival.state()
  local function pct(v) return string.format("%3d%%", math.floor(v * 100 + 0.5)) end
  return { "O2 " .. pct(s.oxygen) .. "  FILTER " .. pct(s.filter), "PWR " .. pct(s.power) .. "  HULL " .. pct(s.integrity),
    string.format("DOSE %.1f", s.dose) }
end

return survival
