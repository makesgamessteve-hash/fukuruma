-- Native settlements (native-settlements spec). Each world with air and a liveable climate has a few settlements of its
-- natives (factions.lua), placed and styled from the seed (a named stream): a ring of huts and towers around a fire,
-- built from hull parts in the settlement's colours. Its natives walk between the buildings at a low tick rate; they
-- are sensor signatures (kind "native"). How they meet the Commander follows their faction's attitude: hostile natives
-- throw spears at a suit that comes close; the others can be talked to (dialogue.lua).
local sim = require("fk.sim")
local chain = require("chain")
local sensors = require("sensors")
local universe = require("universe")
local factions = require("factions")

local settlements = {}

settlements.THINK = 12      -- ticks between the natives' steps
settlements.PER_WORLD = 2
settlements.NATIVES = 6     -- per settlement
settlements.REACH = { 1500, 4500 } -- metres from the range's origin
settlements.SPEAR = { range = 15, every = 2, harm = 0.05 } -- metres, seconds, integrity
settlements.TALK = 6        -- metres

sensors.HAZARDS.native = { signature = "bio", size = { 1.6, 1.9 }, stealth = 0.3, name = "NATIVE" }

-- Whether the current world can have natives: air and a climate life can stand.
function settlements.habitable()
  local v = universe.view()
  local site = v.sys and v.place and v.sys.bodies[v.place]
  local t = site and site.temperature or 288
  return v.air ~= nil and t > 150 and t < 420 -- (natives are adapted to their own world: hot or cold, not boiling or frozen)
end

-- The settlements of world key: {x, z, radius, buildings = {{x, z, kind, size}}, color, roof}.
function settlements.of(key)
  local rng, list = fk.rng("settlements", key), {}
  for _ = 1, settlements.PER_WORLD do
    local r = settlements.REACH[1] + rng:float() * (settlements.REACH[2] - settlements.REACH[1])
    local a = rng:float() * 2 * math.pi
    local s = { x = r * fk.math.cos(a), z = r * fk.math.sin(a), radius = 25 + rng:float() * 15, buildings = {},
      color = { 0.4 + rng:float() * 0.4, 0.3 + rng:float() * 0.3, 0.2 + rng:float() * 0.25 },
      roof = { 0.2 + rng:float() * 0.5, 0.15 + rng:float() * 0.3, 0.1 + rng:float() * 0.2 } }
    for i = 1, rng:range(5, 9) do
      local b = (i - 1) / 9 * 2 * math.pi + rng:float() * 0.4
      s.buildings[i] = { x = s.radius * fk.math.cos(b), z = s.radius * fk.math.sin(b), kind = rng:chance(0.25) and "tower" or "hut",
        size = 4 + rng:float() * 4 }
    end
    list[#list + 1] = s
  end
  return list
end

-- Adds world key's natives to its hazards (a sensors.world_hooks entry).
function settlements.populate(key, list, next_id)
  if not settlements.habitable() then return end
  for si, s in ipairs(settlements.of(key)) do
    for i = 1, settlements.NATIVES do
      local b = s.buildings[(i - 1) % #s.buildings + 1]
      list[#list + 1] = { id = next_id(), kind = "native", settlement = si, x = s.x + b.x * 0.6, z = s.z + b.z * 0.6,
        hx = s.x, hz = s.z, size = 1.75, phase = i, target = i, stride = 0 }
    end
  end
end

function settlements.install()
  local present = false
  for _, f in ipairs(sensors.world_hooks) do present = present or f == settlements.populate end
  if not present then sensors.world_hooks[#sensors.world_hooks + 1] = settlements.populate end
end

-- The native nearest (x, z) within reach, or nil.
function settlements.native_near(x, z, reach)
  local best, found = reach * reach, nil
  for _, h in ipairs(sensors.hazards()) do
    if h.kind == "native" then
      local dx, dz = h.x - x, h.z - z
      if dx * dx + dz * dz <= best then best, found = dx * dx + dz * dz, h end
    end
  end
  return found
end

-- The natives' faction on the current world.
function settlements.faction()
  local key = sensors.state().world
  return key and factions.of(key).natives
end

-- Each tick: the natives walk between their buildings; hostile ones throw spears at a suit close by.
function settlements.tick(hurt)
  if sim.tick % settlements.THINK ~= 0 then return end
  local key = sensors.state().world
  if not key then return end
  local places, f = settlements.of(key), factions.of(key).natives
  local hostile = factions.attitude(f) == "hostile"
  local p, outside = chain.suit(), chain.on_foot()
  local dt = sim.dt * settlements.THINK
  for _, h in ipairs(sensors.hazards()) do
    if h.kind == "native" then
      local s = places[h.settlement]
      local b = s.buildings[(h.target - 1) % #s.buildings + 1]
      local tx, tz = s.x + b.x * 0.6, s.z + b.z * 0.6
      local dx, dz = p.x - h.x, p.z - h.z
      local close = outside and dx * dx + dz * dz < settlements.SPEAR.range * settlements.SPEAR.range
      if close and not hostile then tx, tz = h.x, h.z end -- (they stop to look at the suit)
      local mx, mz = tx - h.x, tz - h.z
      local d = math.sqrt(mx * mx + mz * mz)
      if d < 0.5 then h.target = h.target + 1 + (sim.tick // settlements.THINK + h.id) % 3
      else
        local step = math.min(d, 1.2 * dt)
        h.x, h.z, h.stride = h.x + mx / d * step, h.z + mz / d * step, h.stride + step
        h.hx_dir, h.hz_dir = mx / d, mz / d
      end
      local fs = factions.state()
      if close and hostile and sim.tick >= (fs.spear_at or 0) then
        fs.spear_at = sim.tick + settlements.SPEAR.every / sim.dt -- (in the factions' state: saved)
        hurt(settlements.SPEAR.harm)
        sim.emit("spear", { position = { p.x, p.y + 1.5, p.z }, strength = 0.6 })
      end
    end
  end
end

-- Draws the settlements and their natives near eye (presentation).
function settlements.draw(state, eye)
  local key = sensors.state().world
  if not key or not settlements.habitable() then return 0 end
  local hull, mat4 = require("dolls.hull"), require("mat4")
  state.meshes = state.meshes or {}
  local n = 0
  for i, s in ipairs(settlements.of(key)) do
    local dx, dz = s.x - eye[1], s.z - eye[3]
    if dx * dx + dz * dz < 2000 * 2000 then
      local id = key .. i
      if not state.meshes[id] then
        local parts = { { "box", at = { 0, 0.3, 0 }, size = { 3, 0.6, 3 }, color = { 0.25, 0.22, 0.2 } } } -- the fire pit
        for _, b in ipairs(s.buildings) do
          if b.kind == "tower" then
            parts[#parts + 1] = { "box", at = { b.x, b.size * 1.2, b.z }, size = { b.size * 0.5, b.size * 2.4, b.size * 0.5 }, color = s.color }
            parts[#parts + 1] = { "box", at = { b.x, b.size * 2.5, b.z }, size = { b.size * 0.8, b.size * 0.3, b.size * 0.8 }, color = s.roof }
          else
            parts[#parts + 1] = { "box", at = { b.x, b.size * 0.35, b.z }, size = { b.size, b.size * 0.7, b.size }, color = s.color }
            parts[#parts + 1] = { "box", at = { b.x, b.size * 0.8, b.z }, size = { b.size * 1.15, b.size * 0.25, b.size * 1.15 }, color = s.roof }
          end
        end
        state.meshes[id] = fk.gfx.mesh(hull.build(parts, 1))
      end
      local y = chain.ground(s.x, s.z)
      fk.gfx.draw(state.meshes[id], mat4.translation(s.x, y - 0.2, s.z), { roughness = 0.85 })
      fk.gfx.light({ position = { s.x, y + 1.5, s.z }, color = { 1, 0.55, 0.25 }, intensity = 25, radius = 30 })
      n = n + 1
    end
  end
  state.body = state.body or fk.gfx.mesh(hull.build({
    { "box", at = { 0, 1.25, 0 }, size = { 0.5, 0.7, 0.3 }, color = { 0.55, 0.4, 0.3 } },
    { "box", at = { 0, 1.75, 0.02 }, size = { 0.3, 0.3, 0.3 }, color = { 0.6, 0.45, 0.35 } } }, 1))
  state.leg = state.leg or fk.gfx.mesh(hull.build({ { "box", at = { 0, -0.45, 0 }, size = { 0.16, 0.9, 0.16 }, color = { 0.3, 0.25, 0.2 } } }, 1))
  for _, h in ipairs(sensors.hazards()) do
    local dx, dz = h.x - eye[1], h.z - eye[3]
    if h.kind == "native" and dx * dx + dz * dz < 300 * 300 then
      local yaw = h.hx_dir and math.atan(h.hx_dir, h.hz_dir) or 0
      local base = mat4.multiply(mat4.translation(h.x, chain.ground(h.x, h.z), h.z), mat4.rotation_y(yaw))
      fk.gfx.draw(state.body, base, { roughness = 0.8 })
      local swing = math.sin(h.stride / 1.4 * 2 * math.pi) * 0.4
      for side = -1, 1, 2 do
        fk.gfx.draw(state.leg, mat4.multiply(base, mat4.multiply(mat4.translation(side * 0.13, 0.9, 0), mat4.rotation_x(swing * side))),
          { roughness = 0.8 })
      end
    end
  end
  return n
end

return settlements
