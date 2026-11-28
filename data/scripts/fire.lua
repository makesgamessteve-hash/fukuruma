-- Fire and destruction (fire-and-destruction spec). Fire burns on a grid of CELL-metre cells: a flare or an explosion
-- lights one; every SPREAD ticks each burning cell may light its four neighbours, more likely the drier the world's
-- vegetation (a named stream per world, tick and cell: the same every time); a cell burns for BURN seconds and then is
-- ash that does not burn again. A gas pocket in a burning cell explodes: it is gone, the suit near it is hurt and the
-- creatures near it are knocked down. Standing in fire burns the suit (environment.lua). Flames, smoke and their light
-- are presentation.
local sim = require("fk.sim")
local chain = require("chain")
local sensors = require("sensors")
local universe = require("universe")

local fire = {}

fire.CELL = 8      -- metres
fire.SPREAD = 30   -- ticks
fire.BURN = 12     -- seconds
fire.MAX = 300     -- burning cells at most
fire.BLAST = 12    -- metres an exploding gas pocket reaches

function fire.state() return sim.get(fire.id, "fire") end

function fire.install()
  fire.id = sim.create()
  sim.set(fire.id, "fire", { cells = {}, ash = {}, world = nil })
  require("environment").fires = fire.at
end

local function cell(x, z) return math.floor(x / fire.CELL), math.floor(z / fire.CELL) end
local function key(i, j) return i .. "," .. j end

-- How readily the world's vegetation burns (0..1): none without air or where it is too cold or too hot for plants.
function fire.dryness()
  local v = universe.view()
  local site = v.sys and v.place and v.sys.bodies[v.place]
  local t = site and site.temperature or 288
  if not v.air or t < 240 or t > 360 then return 0 end
  return math.max(0.2, math.min(1, (t - 250) / 70))
end

-- Lights the cell at (x, z) (unless it is ash or burning). Returns whether it caught.
function fire.ignite(x, z)
  local s = fire.state()
  local i, j = cell(x, z)
  local k = key(i, j)
  local n = 0
  for _ in pairs(s.cells) do n = n + 1 end
  if s.cells[k] or s.ash[k] or n >= fire.MAX then return false end
  s.cells[k] = { i = i, j = j, out = sim.tick + fire.BURN / sim.dt }
  return true
end

-- 1 inside a burning cell, else 0.
function fire.at(x, z)
  local i, j = cell(x, z)
  return fire.state().cells[key(i, j)] and 1 or 0
end

local function explode(h, hurt)
  h.gone = true
  local p = chain.suit()
  local dx, dz = p.x - h.x, p.z - h.z
  local d = math.sqrt(dx * dx + dz * dz)
  if chain.on_foot() and d < fire.BLAST then hurt(0.35 * (1 - d / fire.BLAST)) end
  for _, o in ipairs(sensors.hazards()) do
    local ox, oz = o.x - h.x, o.z - h.z
    if (o.kind == "predator" or o.kind == "grazer") and ox * ox + oz * oz < fire.BLAST * fire.BLAST then o.stunned = sim.tick + 8 / sim.dt end
  end
  sim.emit("explosion", { position = { h.x, chain.ground(h.x, h.z) + 1, h.z }, strength = 1 })
end

function fire.tick(world_key, hurt)
  local s = fire.state()
  if s.world ~= world_key then s.world, s.cells, s.ash = world_key, {}, {} end -- (fires are of a world)
  if sim.tick % fire.SPREAD ~= 0 or next(s.cells) == nil then return end
  local dry, burning = fire.dryness(), {}
  for k, c in pairs(s.cells) do burning[#burning + 1] = { k, c } end
  table.sort(burning, function(a, b) return a[1] < b[1] end) -- (pairs order is not deterministic)
  for _, entry in ipairs(burning) do
    local k, c = entry[1], entry[2]
    if c.out <= sim.tick then
      s.cells[k], s.ash[k] = nil, true
    else
      local rng = fk.rng("fire", world_key, sim.tick, c.i, c.j)
      for _, n in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        if rng:float() < dry * 0.3 then fire.ignite((c.i + n[1] + 0.5) * fire.CELL, (c.j + n[2] + 0.5) * fire.CELL) end
      end
    end
  end
  local list = sensors.hazards()
  for i = #list, 1, -1 do
    local h = list[i]
    if h.kind == "gas_pocket" and fire.at(h.x, h.z) > 0 then
      explode(h, hurt)
      table.remove(list, i)
    end
  end
end

-- Flames, smoke and light over the burning cells near eye (presentation). Returns how many cells it drew.
function fire.draw(eye, dt, now)
  local n, lights = 0, 0
  local list = {}
  for _, c in pairs(fire.state().cells) do
    local x, z = (c.i + 0.5) * fire.CELL, (c.j + 0.5) * fire.CELL
    local dx, dz = x - eye[1], z - eye[3]
    if dx * dx + dz * dz < 250 * 250 then list[#list + 1] = { x, z, dx * dx + dz * dz } end
  end
  table.sort(list, function(a, b) return a[3] < b[3] end)
  for i, c in ipairs(list) do
    if i > 40 then break end
    local y = chain.ground(c[1], c[2])
    local count = math.max(1, math.floor(30 * dt + 0.5))
    fk.gfx.emit({ count = count, position = { c[1], y + 0.3, c[2] }, radius = fire.CELL * 0.45, direction = { 0, 1, 0 },
      spread = 0.3, speed_min = 1.5, speed_max = 3.5, life_min = 0.4, life_max = 0.9, size = 0.9, size_end = 0.2,
      color = { 1, 0.45, 0.1 }, intensity = 8, alpha = 1, alpha_end = 0, glow = true })
    fk.gfx.emit({ count = count, position = { c[1], y + 2, c[2] }, radius = fire.CELL * 0.4, direction = { 0, 1, 0 },
      spread = 0.25, speed_min = 1, speed_max = 2, life_min = 2, life_max = 4, size = 1.5, size_end = 4,
      color = { 0.12, 0.11, 0.1 }, alpha = 0.5, alpha_end = 0 })
    if lights < 4 then
      fk.gfx.light({ position = { c[1], y + 1.5, c[2] }, color = { 1, 0.5, 0.2 }, intensity = 30 * (0.85 + 0.15 * math.sin(now * 17 + i)),
        radius = 30 })
      lights = lights + 1
    end
    n = n + 1
  end
  return n
end

return fire
