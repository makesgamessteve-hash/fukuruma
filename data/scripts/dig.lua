-- Digging (voxel-terrain spec). The suit blasts spheres out of the ground in front of it. Simulation: the digs are a
-- component (saved, hashed) of the current world, handed to the physics world, which treats the ground as a solid
-- with these holes (bodies and the suit fall into pits and walk through tunnels); a jump to another world leaves them
-- behind. Presentation: the dug walls are meshed in 8 m regions (planet:dig_mesh); the planet's ground leaves out
-- what lies inside a dig.
local sim = require("fk.sim")

local dig = {}

dig.RADIUS = 2.8     -- metres: a hole the 3.6 m suit can walk into
dig.REACH = 2.6      -- metres in front of the suit (the digs of a tunnel overlap)
dig.DEPTH = 0.6      -- the sphere's centre below the ground, in radii
dig.MAX = 256        -- digs kept per world (the oldest go first)
dig.COOLDOWN = 30    -- ticks between digs
dig.REGION = 8       -- metres: the dug walls are meshed per cube of this size
dig.CELL = 0.5       -- metres between the mesh's samples
dig.SHOWN = 16       -- the nearest digs the ground's drawing leaves out
dig.DECK = 81        -- no digging into the deck (half its size, metres)
dig.AIM = 2.2        -- metres above the feet: from inside a hole, the next one goes forward and down, with headroom

-- Sets up the component and the dig command. suit(): the suit's state {x, y (its feet), z, fx, fz}; world: the
-- physics world; allowed() (optional): whether the suit may dig now (the Commander is in it).
function dig.install(world, suit, allowed)
  dig.id = sim.create()
  sim.set(dig.id, "digs", { world = "", list = {}, at = 0 })
  sim.on("dig", function()
    local d = sim.get(dig.id, "digs")
    if sim.tick < d.at or (allowed and not allowed()) then return end
    local s = suit()
    local x, z = s.x + s.fx * dig.REACH, s.z + s.fz * dig.REACH
    local h = world:height(x, z)
    if not h or (math.abs(x) < dig.DECK and math.abs(z) < dig.DECK) then return end
    d.at = sim.tick + dig.COOLDOWN
    local list = d.list
    if #list >= dig.MAX * 4 then table.move(list, 5, #list, 1) for _ = 1, 4 do list[#list] = nil end end
    -- from the surface a pit; from inside one, a tunnel forward and a little down (its roof thickens as it goes)
    local y = math.min(h - dig.RADIUS * dig.DEPTH, s.y + dig.AIM)
    list[#list + 1], list[#list + 2], list[#list + 3], list[#list + 4] = x, y, z, dig.RADIUS
    world:digs(list, true) -- what rested on the ground may fall now
    dig.applied, dig.count = list, #list
    sim.emit("dig", { position = { x, h, z } })
  end)
end

-- Each tick, before the physics: a new world clears the digs; the physics world gets any new list (after a load, or a
-- new session: the bodies keep the sleep they were saved with).
function dig.tick(world, world_key)
  local d = sim.get(dig.id, "digs")
  if d.world ~= world_key then
    d.world, d.list = world_key, {}
  end
  if dig.applied ~= d.list or dig.count ~= #d.list then
    world:digs(d.list)
    dig.applied, dig.count = d.list, #d.list
  end
end

function dig.list() return sim.get(dig.id, "digs").list end

-- The digs nearest to eye, at most dig.SHOWN of them, as {x, y, z, r, ...} for the ground's drawing.
function dig.nearest(eye)
  local list = dig.list()
  local n = #list // 4
  if n <= dig.SHOWN then return list end
  local order = {}
  for i = 0, n - 1 do
    local dx, dz = list[4 * i + 1] - eye[1], list[4 * i + 3] - eye[3]
    order[#order + 1] = { i, dx * dx + dz * dz }
  end
  table.sort(order, function(a, b) return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1]) end)
  local out = {}
  for k = 1, dig.SHOWN do
    local i = order[k][1]
    for c = 1, 4 do out[#out + 1] = list[4 * i + c] end
  end
  return out
end

-- The helmet lamp (presentation): a warm light at the eye once it is below the ground, brighter the deeper (up to 1 m
-- down). Returns how bright, 0..1.
function dig.lamp(world, eye)
  local h = world:height(eye[1], eye[3])
  local k = h and math.min(1, h - eye[2] - 0.3) or 0
  if k <= 0 then return 0 end
  fk.gfx.light({ position = eye, color = { 1, 0.85, 0.65 }, intensity = 6 * k, radius = 12 })
  return k
end

-- How much of the sky's light reaches an eye below the ground (presentation): 1 above it, less the deeper. The
-- sky's ambient light is scaled by it, so tunnels are lit by the helmet lamp, not by a sky they cannot see.
function dig.daylight(world, eye)
  local h = world:height(eye[1], eye[3])
  local d = h and h - eye[2] or 0
  if d <= 0 then return 1 end
  return 0.06 + 0.94 * fk.math.exp(-d / 1.5)
end

-- The dug walls: meshes per region, rebuilt when the digs change (presentation). g: the range's ground.
function dig.draw(state, g)
  if not g then return 0 end
  local list = dig.list()
  if state.list ~= list or state.count ~= #list or state.g ~= g then
    state.list, state.count, state.g, state.meshes = list, #list, g, {}
    local regions, R = {}, dig.REGION
    for i = 1, #list, 4 do -- every region a dig reaches
      local r = list[i + 3]
      for x = math.floor((list[i] - r) / R), math.floor((list[i] + r) / R) do
        for y = math.floor((list[i + 1] - r) / R), math.floor((list[i + 1] + r) / R) do
          for z = math.floor((list[i + 2] - r) / R), math.floor((list[i + 2] + r) / R) do
            regions[x .. "/" .. y .. "/" .. z] = { x * R, y * R, z * R }
          end
        end
      end
    end
    local keys = {}
    for k in pairs(regions) do keys[#keys + 1] = k end
    table.sort(keys)
    local r, gr, b = g.surface:color(g.up[1], g.up[2], g.up[3])
    for _, k in ipairs(keys) do
      local mesh = g.surface:dig_mesh({ up = g.up, east = g.east, north = g.north, digs = list, lo = regions[k],
        cell = dig.CELL, n = math.floor(R / dig.CELL + 0.5), soil = { r * 0.6, gr * 0.5, b * 0.45 }, rock = { 0.34, 0.32, 0.3 } })
      if mesh then state.meshes[#state.meshes + 1] = mesh end
    end
  end
  for _, m in ipairs(state.meshes) do
    fk.gfx.draw(m, { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, -0.05, 0, 1 }, { roughness = 0.95, one_sided = true }) -- with the ground, under the deck; the normals face the open side
  end
  return #state.meshes
end

return dig
