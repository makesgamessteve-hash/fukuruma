-- Sensors and scanning (sensor-system spec). Every hazard has a signature: a size (metres), a kind (thermal, bio, EM,
-- seismic, chemical or exotic) and a stealth (0..1). Each doll's suite (its definition's sensors field) sees what is
-- within its range, at least its resolution in size and of a kind it covers. Passive scans run on their own: the
-- doll the Commander is in, and any doll on autopilot. An active ping (the scan command) reaches twice as far, resolves
-- half as small and sees through stealth, but every hostile within its reach hears it. What was seen is kept as
-- contacts, which age: a contact shows where something was when it was last seen.
-- Hazards are made per world from the world's seed (a named stream), within HAZARD_RANGE of the range's origin, and
-- the hazard registry (sensors.HAZARDS) is open to mods. Simulation state: positions follow fk.math only.
local sim = require("fk.sim")
local dolls = require("dolls")
local chain = require("chain")

local sensors = {}

sensors.HAZARDS = { -- kind = {signature, size = {min, max} metres, stealth, hostile, roam (metres), name}
  sinkhole = { signature = "seismic", size = { 12, 60 }, stealth = 0.7, name = "SINKHOLE" },
  gas_pocket = { signature = "chemical", size = { 0.05, 0.4 }, stealth = 0.3, name = "GAS POCKET" },
  radiation = { signature = "EM", size = { 0.02, 0.3 }, stealth = 0.2, name = "RADIATION" },
  predator = { signature = "bio", size = { 1.5, 4 }, stealth = 0.5, hostile = true, roam = 60, name = "PREDATOR" },
  vent = { signature = "thermal", size = { 2, 8 }, stealth = 0.1, name = "HOT VENT" },
}
sensors.ORDER = { "sinkhole", "gas_pocket", "radiation", "predator", "vent" } -- (the stream's order: deterministic)
sensors.COUNT = 40          -- hazards per world
sensors.HAZARD_RANGE = 4000 -- metres from the range's origin
sensors.CLEAR = 120         -- metres around the origin left clear (the landing site)
sensors.PASSIVE = 30        -- ticks between passive scans
sensors.STALE = 60          -- seconds: older contacts are shown as stale

function sensors.state() return sim.get(sensors.id, "sensors") end

function sensors.install()
  sensors.id = sim.create()
  sim.set(sensors.id, "sensors", { worlds = {}, contacts = {}, world = nil, next = 1 })
  chain.hazard_ahead, chain.sensor_screen = sensors.ahead, sensors.screen
end

-- The hazards of the world the range is on (made the first time it is visited).
function sensors.hazards()
  local s = sensors.state()
  return s.world and s.worlds[s.world] or {}
end

local function make(key)
  local rng, list, s = fk.rng("hazards", key), {}, sensors.state()
  for _ = 1, sensors.COUNT do
    local kind = sensors.ORDER[rng:range(1, #sensors.ORDER)]
    local def = sensors.HAZARDS[kind]
    local r = sensors.CLEAR + rng:float() * (sensors.HAZARD_RANGE - sensors.CLEAR)
    local a = rng:float() * 2 * math.pi
    local size = def.size[1] + rng:float() * (def.size[2] - def.size[1])
    list[#list + 1] = { id = s.next, kind = kind, x = r * fk.math.cos(a), z = r * fk.math.sin(a), size = size,
      phase = rng:float() * 2 * math.pi }
    list[#list].hx, list[#list].hz = list[#list].x, list[#list].z
    s.next = s.next + 1
  end
  return list
end

-- A hazard added by hand (tests, mods, scripted events): kind, x, z, size; returns it.
function sensors.place(kind, x, z, size)
  local s = sensors.state()
  local h = { id = s.next, kind = kind, x = x, z = z, hx = x, hz = z, size = size, phase = 0 }
  s.next = s.next + 1
  local list = sensors.hazards()
  if s.world then s.worlds[s.world] = list end
  list[#list + 1] = h
  return h
end

-- Can suite (a doll's sensors) see hazard h at distance dist? active: a ping.
function sensors.sees(suite, h, dist, active)
  local def = sensors.HAZARDS[h.kind]
  local covered = false
  for _, k in ipairs(suite.kinds) do covered = covered or k == def.signature end
  if not covered then return false end
  local range = active and suite.range * 2 or suite.range * (1 - def.stealth * 0.6)
  return dist <= range and h.size >= suite.resolution * (active and 0.5 or 1)
end

local function seen(h, by)
  sensors.state().contacts["h" .. h.id] = { id = h.id, tick = sim.tick, x = h.x, z = h.z, size = h.size, kind = h.kind, by = by }
end

-- A scan by doll d (passive, or active: a ping). Returns how many hazards it saw.
function sensors.scan(d, active)
  local suite = dolls.by_id[d.kind].sensors
  if not suite then return 0 end
  local n = 0
  for _, h in ipairs(sensors.hazards()) do
    local dx, dz = h.x - d.x, h.z - d.z
    local dy = d.y - chain.ground(h.x, h.z)
    local dist = math.sqrt(dx * dx + dz * dz + dy * dy) -- (products, not ^: pow differs between platforms)
    if sensors.sees(suite, h, dist, active) then
      seen(h, d.kind)
      n = n + 1
    end
    if active and sensors.HAZARDS[h.kind].hostile and dist <= suite.range * 2 and not h.alerted then
      h.alerted = true -- it heard the ping
      sim.emit("alerted", { position = { h.x, chain.ground(h.x, h.z), h.z }, id = h.id, strength = 0.6 })
    end
  end
  return n
end

-- The contacts (ageing scan data), each with age (seconds) and stale, nearest to (x, z) first.
function sensors.contacts(x, z)
  local list = {}
  for _, c in pairs(sensors.state().contacts) do
    local age = (sim.tick - c.tick) * sim.dt
    list[#list + 1] = { id = c.id, x = c.x, z = c.z, size = c.size, kind = c.kind, by = c.by, age = age,
      stale = age > sensors.STALE, dist = math.sqrt((c.x - x) * (c.x - x) + (c.z - z) * (c.z - z)) }
  end
  table.sort(list, function(a, b)
    if a.dist ~= b.dist then return a.dist < b.dist end
    return a.id < b.id
  end)
  return list
end

-- The contact in doll d's way: in front of it, within its stopping distance and across its path, big enough to
-- matter to it (a tenth of its size); or nil.
function sensors.ahead(d)
  local size = dolls.by_id[d.kind].size_m
  local fx, fz = fk.math.sin(d.yaw or 0), fk.math.cos(d.yaw or 0)
  local reach = math.max(150, size * 3)
  for _, c in pairs(sensors.state().contacts) do
    local dx, dz = c.x - d.x, c.z - d.z
    local along, across = dx * fx + dz * fz, math.abs(dx * fz - dz * fx)
    if c.size >= size * 0.1 and along > 0 and along < reach + c.size and across < size * 0.5 + c.size then return c end
  end
end

-- Each tick: on a new world, its hazards; roaming hazards move (alerted ones faster); passive scans.
function sensors.tick(world_key)
  local s = sensors.state()
  if s.world ~= world_key then
    s.world = world_key
    s.worlds[world_key] = s.worlds[world_key] or make(world_key)
    s.contacts = {} -- scan data is of a world
  end
  local t = sim.tick * sim.dt
  for _, h in ipairs(sensors.hazards()) do
    local roam = sensors.HAZARDS[h.kind].roam
    if roam then
      local w = (h.alerted and 0.2 or 0.05)
      h.x, h.z = h.hx + roam * fk.math.cos(h.phase + t * w), h.hz + roam * fk.math.sin(h.phase + t * w)
    end
  end
  if sim.tick % sensors.PASSIVE == 0 then
    local current = chain.current()
    sensors.scan(current, false)
    for _, d in ipairs(chain.state().dolls) do
      if d.auto and d ~= current and chain.here(d) then sensors.scan(d, false) end
    end
  end
end

-- The cockpit's sensor screen.
function sensors.screen(d)
  local n, stale = 0, 0
  for _, c in ipairs(sensors.contacts(d.x, d.z)) do
    n = n + 1
    if c.stale then stale = stale + 1 end
  end
  return { "SENSORS", n .. " CONTACTS" .. (stale > 0 and (" " .. stale .. " OLD") or "") }
end

-- A contact's label: what, how far, how old.
function sensors.label(c)
  local dist = c.dist >= 1000 and string.format("%.1f KM", c.dist / 1000) or string.format("%.0f M", c.dist)
  return sensors.HAZARDS[c.kind].name .. " " .. dist .. (c.stale and string.format(" %.0fS AGO", c.age) or "")
end

return sensors
