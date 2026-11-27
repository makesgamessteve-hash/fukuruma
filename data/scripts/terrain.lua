-- The ground under the range (terrain-streaming spec). Simulation: a heightfield tile of the world's real surface
-- follows the suit, so bodies and the suit stand on the same ground that is drawn; the tile is a pure function of
-- the world and where the suit stands (snapped to a grid), so a loaded game rebuilds the same ground. Presentation:
-- the world's surface is drawn from the planet chunks down to the ground, the levelled site under the deck.
local planet_view = require("planet_view")
local frames = require("fk.frames")

local terrain = {}

terrain.CELL = 2   -- metres between the tile's heights
terrain.N = 48     -- cells along its edge (96 m)
terrain.SNAP = 16  -- the tile's centre moves in steps of this many metres

-- Puts the tile around (x, z) for ground g into the physics world, if it is not there already. Returns true when it
-- was rebuilt.
function terrain.follow(state, world, g, x, z)
  if not g then
    if state.key then world:terrain(nil) end
    state.key = nil
    return false
  end
  local cx, cz = math.floor(x / terrain.SNAP + 0.5) * terrain.SNAP, math.floor(z / terrain.SNAP + 0.5) * terrain.SNAP
  local key = tostring(g) .. "/" .. cx .. "/" .. cz
  if state.key == key then return false end
  state.key = key
  local half = terrain.N * terrain.CELL / 2
  local origin = { cx - half, cz - half }
  world:terrain({ origin = origin, cell = terrain.CELL, friction = 0.9, heights = g.surface:grid({ up = g.up, east = g.east,
    north = g.north, origin = origin, cell = terrain.CELL, n = terrain.N }) })
  return true
end

-- Draws ground g's world seen from eye (local axes, metres) looking along forward within half_angle (radians, to the
-- view's corners). Returns the number of chunks drawn.
function terrain.draw(state, g, eye, forward, half_angle, focal, wait)
  if not g then return 0 end
  wait = wait or scenario ~= nil -- test scenarios wait for the ground, so their pictures do not depend on the machine
  if state.view_of ~= g then state.view, state.view_of = planet_view.new(g.desc, 0), g end
  -- The planetary slice starts just short of the nearest ground that could be in view, so its depth precision goes
  -- where the ground is (from orbit, the slice would otherwise spend it on empty space).
  local dx, dy, dz = eye[1] - g.centre[1], eye[2] - g.centre[2], eye[3] - g.centre[3]
  local clear = math.sqrt(dx * dx + dy * dy + dz * dz) - g.radius - (g.desc.relief or 0)
  fk.gfx.slices({ planetary = { math.max(frames.LOCAL_FAR, clear * 0.5), frames.PLANETARY[2] } })
  return state.view:draw(g.centre, g.to_local, focal, wait, { eye = eye, look = { forward, half_angle }, air = false })
end

return terrain
