-- The environment model (environment-model spec): what the air, the heat and the ground do to a body standing at a
-- point of the world. The world gives its air (gas, pressure) and temperature; the world's seed gives its toxic zones
-- (a biome of bad air: a named stream, the same every time); hazards near the point add their own (sensors.lua: gas
-- pockets poison, radiation irradiates, vents heat, fires burn). Simulation: fk.math only.
local universe = require("universe")
local sensors = require("sensors")

local environment = {}

-- How poisonous each gas is to breathe or to touch at one bar (0..1 a second's harm before the filter).
environment.TOXIC = { sulfur = 1, co = 0.8, n2ch4 = 0.4, co2 = 0.2 }
environment.ZONES = 6            -- toxic zones per world
environment.ZONE_RANGE = 6000    -- metres from the range's origin
environment.CLEAR = 300          -- metres around the origin without a zone (the landing site)
environment.fires = nil          -- function(x, z) -> heat 0..1 of fire there (fire.lua)

local zones = {} -- derived from the world's key: a cache, not state

-- The toxic zones of world key: {x, z, radius, toxin}.
function environment.zones(key)
  if zones[key] then return zones[key] end
  local rng, list = fk.rng("toxic-zones", key), {}
  for _ = 1, environment.ZONES do
    local r = environment.CLEAR + 400 + rng:float() * (environment.ZONE_RANGE - environment.CLEAR - 400)
    local a = rng:float() * 2 * math.pi
    list[#list + 1] = { x = r * fk.math.cos(a), z = r * fk.math.sin(a), radius = 150 + rng:float() * 450,
      toxin = 0.4 + rng:float() * 0.8 }
  end
  zones[key] = list
  return list
end

local function near(h, x, z, reach)
  local dx, dz = h.x - x, h.z - z
  local d2 = dx * dx + dz * dz
  return d2 < reach * reach and 1 - math.sqrt(d2) / reach or 0
end

-- The environment at (x, z) on the current world: {temperature (K), pressure (bar), breathable, toxin (0..),
-- radiation (0..), fire (0..1)}.
function environment.at(x, z)
  local v = universe.view()
  local site = v.sys and v.place and v.sys.bodies[v.place]
  local air = v.air
  local e = { temperature = site and site.temperature or 288, pressure = air and air.pressure or 0, toxin = 0,
    radiation = air and 0 or 0.2, fire = 0 } -- (no air: the star's radiation reaches the ground)
  e.breathable = air ~= nil and air.gas == "n2o2" and air.pressure > 0.5 and air.pressure < 3
  if air then e.toxin = (environment.TOXIC[air.gas] or 0) * math.min(air.pressure, 3) end
  local key = sensors.state().world
  if key then
    for _, zone in ipairs(environment.zones(key)) do e.toxin = e.toxin + zone.toxin * math.min(1, 2 * near(zone, x, z, zone.radius)) end
  end
  for _, h in ipairs(sensors.hazards()) do
    if h.kind == "gas_pocket" then e.toxin = e.toxin + 1.5 * near(h, x, z, 12)
    elseif h.kind == "radiation" then e.radiation = e.radiation + 2 * near(h, x, z, 30)
    elseif h.kind == "vent" then e.temperature = e.temperature + 250 * near(h, x, z, 10 + h.size) end
  end
  if environment.fires then
    e.fire = environment.fires(x, z)
    e.temperature = e.temperature + 600 * e.fire
  end
  return e
end

return environment
