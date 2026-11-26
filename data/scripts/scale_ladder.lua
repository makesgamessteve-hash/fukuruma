-- The scale ladder (reference-frames and orbital-mechanics specs): a 1 m cube beside a 144 km Jump Ship hull in
-- orbit 300 km above an Earth-sized, turning planet that orbits a Sun-like star at 1 AU, all in one frame tree. The camera can stand at four steps: by
-- the cube, off the hull, off the planet and off the star. Everything is drawn relative to the camera, in the
-- depth slice its distance needs, with scaled space for the far bodies.
local frames = require("fk.frames")
local shapes = require("shapes")
local jump_ship = require("jump_ship")
local mat4 = require("mat4")

local ladder = {}

ladder.AU = 1.495978707e11
ladder.STAR_RADIUS = 6.96e8
ladder.PLANET_RADIUS = 6.371e6
ladder.HULL_LENGTH = 1.44e5
local HULL_SCALE = ladder.HULL_LENGTH / 6.6 -- the placeholder hull is 6.6 units long
local ORBIT = ladder.PLANET_RADIUS + 3e5
ladder.MU_STAR, ladder.MU_PLANET = 1.32712440018e20, 3.986004418e14 -- m^3/s^2
ladder.DAY = 86164 -- seconds per turn of the planet

-- The steps: the camera's frame (by name), its position there, and where it looks (a point in the same frame).
ladder.STEPS = {
  { name = "cube", frame = "ship", eye = { -2.6, 2.0e4 + 1.2, 2.4 }, target = { 0, 2.0e4, 0 } },
  { name = "hull", frame = "ship", eye = { -1.6e5, 8e4, 1.9e5 }, target = { 0, 0, 0 } },
  { name = "planet", frame = "planet", eye = { -1.7e7, 5e6, 1.3e7 }, target = { 0, 0, 0 } },
  { name = "star", frame = "system", eye = { 1.5e9, 1.2e9, 4.2e9 }, target = { 0, 0, 0 } },
}

-- Builds the frame tree in the simulation (with the planet's and the ship's orbits and the planet's turning) and
-- the meshes.
function ladder.build()
  local f = {}
  f.system = frames.create()
  f.planet = frames.create(f.system) -- does not turn: the ship's orbit is in it
  frames.orbit(f.planet, { a = ladder.AU, e = 0.0167, mu = ladder.MU_STAR })
  f.surface = frames.create(f.planet) -- turns with the planet
  frames.spin(f.surface, { 0.4, 1, 0 }, math.pi * 2 / ladder.DAY)
  f.ship = frames.create(f.planet)
  frames.orbit(f.ship, { a = ORBIT, mu = ladder.MU_PLANET, anomaly = -math.pi / 2 }) -- starts on +z
  frames.update(0)
  ladder.frames = f
  ladder.meshes = ladder.meshes or {
    cube = fk.gfx.mesh(shapes.box(1, 1, 1, { 0.9, 0.5, 0.15 })),
    hull = fk.gfx.mesh(jump_ship.build()),
    planet = fk.gfx.mesh(shapes.sphere(1, 48, { 0.2, 0.42, 0.6 })),
    star = fk.gfx.mesh(shapes.sphere(1, 32, { 1, 1, 1 })),
  }
  return f
end

-- The camera of a step: a viewer and the view matrix (looking from the viewer's position at the target).
function ladder.camera(step)
  local s = ladder.STEPS[step]
  local viewer = frames.viewer(ladder.frames[s.frame], s.eye)
  local dir = { s.target[1] - s.eye[1], s.target[2] - s.eye[2], s.target[3] - s.eye[3] }
  return viewer, mat4.look_at({ 0, 0, 0 }, dir)
end

local function normalized(v)
  local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  return { v[1] / l, v[2] / l, v[3] / l }
end

-- Moves the bodies to the simulation time t (call from the simulation tick).
function ladder.update(t) frames.update(t) end

function ladder.draw(step, aspect)
  local f, m = ladder.frames, ladder.meshes
  local viewer, view = ladder.camera(step)
  fk.gfx.camera(view, mat4.perspective(math.rad(60), aspect, 0.05, frames.LOCAL_FAR))
  fk.gfx.clear(0.0, 0.0, 0.005)
  fk.gfx.sun({ direction = normalized(viewer:relative(f.system, { 0, 0, 0 })), color = { 1, 0.95, 0.88 }, intensity = 3 })
  fk.gfx.grade({ exposure = -1.5 })
  fk.gfx.ambient({ sky = { 0.05, 0.06, 0.09 }, ground = { 0.02, 0.02, 0.03 }, intensity = 1 })
  local function draw(mesh, frame, p, radius, scale, opts)
    local matrix, slice = viewer:draw_args(frame, p, nil, radius, scale)
    opts = opts or {}
    opts.slice = slice
    fk.gfx.draw(mesh, matrix, opts)
  end
  draw(m.star, f.system, { 0, 0, 0 }, 1, ladder.STAR_RADIUS, { emission = { 40, 34, 26 } })
  draw(m.planet, f.surface, { 0, 0, 0 }, 1, ladder.PLANET_RADIUS, { roughness = 0.8 })
  draw(m.hull, f.ship, { 0, 0, 0 }, 3.4, HULL_SCALE, { roughness = 0.5, metalness = 0.5 })
  draw(m.cube, f.ship, { 0, 2.0e4, 0 }, 0.87, 1, { roughness = 0.4 })
end

return ladder
