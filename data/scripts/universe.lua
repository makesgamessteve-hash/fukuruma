-- Where the test range is in the universe (navigation-maps spec). The simulation keeps the current star and the
-- world the range stands on (the "universe" component) and handles the jump command; gravity follows the world.
-- The presentation turns that into the sky: the real star lights the range, turning with the world's day; the sky's
-- colour follows the world's air; the other bodies of the system hang in the sky (scaled space); the stars of the
-- galaxy shine at night or always on worlds without air.
local sim = require("fk.sim")
local galaxy = require("fk.galaxy")
local systems = require("gen.systems")
local frames = require("fk.frames")
local units = require("gen.units")

local planets = require("gen.planets")
local planet_view = require("planet_view")
local star_view = require("star_view")

local universe = {}

universe.RANGE = 20 -- light-years a jump reaches
local AU = units.AU
local TAU = 2 * fk.math.pi
local PREFERRED = { "terran", "ocean", "desert", "super_earth", "eyeball", "glacier", "barren", "ice", "iron", "lava",
  "carbon", "shattered", "mini_neptune", "ice_giant", "gas_giant", "hot_jupiter" }

-- The galaxy star with this seed in that sector.
function universe.star(sector, seed)
  for _, s in ipairs(galaxy.sector(sector[1], sector[2], sector[3])) do
    if s.seed == seed then return s end
  end
end

-- The world a range stands on: the first body of the most welcoming class.
function universe.place_for(sys)
  for _, class in ipairs(PREFERRED) do
    for i, b in ipairs(sys.bodies) do
      if b.class == class then return i end
    end
  end
  return nil -- no bodies at all: the range floats in space
end

-- Surface gravity (m/s^2) of a body, kept between 0.5 and 30 so walking still works.
function universe.gravity(body)
  if not body then return 0.5 end
  local g = units.G * body.mass * units.EARTH_MASS / (body.radius * body.radius)
  return math.max(0.5, math.min(30, g))
end

-- Where a new game starts: the nearest Sun-like star with a terran or ocean world (else the galaxy's home star).
function universe.home()
  local sunlike = function(s) return s.kind == "star" and s.mass >= 0.7 and s.mass <= 1.3 end
  for _, star in ipairs(galaxy.near(fk.galaxy.HOME, 60, sunlike)) do
    local sys = systems.generate(star)
    local p = universe.place_for(sys)
    if p and (sys.bodies[p].class == "terran" or sys.bodies[p].class == "ocean") then return star, sys, p end
  end
  local star = galaxy.home_star()
  local sys = systems.generate(star)
  return star, sys, universe.place_for(sys)
end

-- Simulation ------------------------------------------------------------------------------------------------------

-- Sets up the universe component at the home star and the jump command. on_gravity(g) is told the surface gravity.
function universe.install(on_gravity)
  local home, sys, place = universe.home()
  universe.id = sim.create()
  sim.set(universe.id, "universe", { seed = home.seed, sector = { home.sector[1], home.sector[2], home.sector[3] },
    place = place or 0, jumps = 0 })
  universe.on_gravity = on_gravity
  on_gravity(universe.gravity(sys.bodies[place]))
  sim.on("jump", function(args)
    local u = sim.get(universe.id, "universe")
    local from, to = universe.star(u.sector, u.seed), universe.star(args.sector, args.seed)
    if not to or galaxy.distance(from.position, to.position) > universe.RANGE or to.seed == u.seed then return end
    local target = systems.generate(to)
    local p = universe.place_for(target)
    u.seed, u.sector, u.place, u.jumps = to.seed, { args.sector[1], args.sector[2], args.sector[3] }, p or 0, u.jumps + 1
    universe.on_gravity(universe.gravity(target.bodies[p]))
    sim.emit("jump", { seed = to.seed })
  end)
end

function universe.state() return sim.get(universe.id, "universe") end

-- Presentation ----------------------------------------------------------------------------------------------------

local view = {} -- the current system, its sky map and the range's orientation, rebuilt when the star changes

local function star_position(sys, i, t)
  local s = sys.stars[i]
  return s.orbit and fk.orbit.state(s.orbit, t) or { 0, 0, 0 }
end

-- A body's position in the system (metres from the root) at time t.
local function position(sys, i, t)
  local b = sys.bodies[i]
  local base = { 0, 0, 0 }
  if b.around == "star" then base = star_position(sys, b.parent, t)
  elseif b.around == "body" then base = position(sys, b.parent, t) end
  if not b.orbit then return base end
  local p = fk.orbit.state(b.orbit, t)
  return { base[1] + p[1], base[2] + p[2], base[3] + p[3] }
end
universe.position = position

local function normalize(v)
  local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  return l > 0 and { v[1] / l, v[2] / l, v[3] / l } or { 0, 1, 0 }
end

-- The rotation taking unit vector a to unit vector b (shortest arc).
local function arc(a, b)
  local c = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
  if c < -0.999999 then return { 1, 0, 0, 0 } end
  local x, y, z = a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]
  local w = 1 + c
  local l = math.sqrt(x * x + y * y + z * z + w * w)
  return { x / l, y / l, z / l, w / l }
end

local function axis_angle(axis, angle)
  local s = fk.math.sin(angle / 2)
  return { axis[1] * s, axis[2] * s, axis[3] * s, fk.math.cos(angle / 2) }
end

universe.SUN_AT_START = normalize({ 0.55, 0.45, -0.7 }) -- where the star stands over the range when it arrives

-- The vector from the range's world (body place) to star i at time t (system axes).
local function offset_from(sys, place, i, t)
  local s, p = star_position(sys, i, t), position(sys, place, t)
  return { s[1] - p[1], s[2] - p[2], s[3] - p[3] }
end

local function rebuild(u)
  local star = universe.star(u.sector, u.seed)
  local sys = systems.generate(star)
  view = { seed = u.seed, star = star, sys = sys, place = sys.bodies[u.place] and u.place or nil }
  view.map = fk.gfx.starfield(fk.seed(), star.position, 100, 256) -- baked in the background
  local b = view.place and sys.bodies[view.place]
  view.air = b and b.atmosphere and b.atmosphere.pressure > 0.005 and b.atmosphere or nil
  view.optics = view.air and planets.describe(b).atmosphere or nil -- scattering coefficients for the sky
  if b then
    local tilt = b.tilt or 0
    view.axis = { fk.math.sin(tilt), fk.math.cos(tilt), 0 }
    if b.day and b.day > 0 then view.rate = TAU / b.day
    elseif b.orbit then view.rate = TAU / fk.orbit.period(b.orbit) -- locked: one turn per orbit
    else view.rate = 0 end
    local to_star = sys.stars[1] and normalize(offset_from(sys, view.place, 1, 0)) or nil
    view.start = to_star and arc(universe.SUN_AT_START, to_star) or { 0, 0, 0, 1 }
  else
    view.axis, view.rate, view.start = { 0, 1, 0 }, 0, { 0, 0, 0, 1 }
  end
end

-- The current view of the universe, rebuilt after a jump or a load.
function universe.view()
  local u = universe.state()
  if view.seed ~= u.seed or (view.place or 0) ~= u.place then rebuild(u) end
  return view
end

-- The range's orientation at time t: local axes (y up) into system axes.
local function orientation(v, t)
  return frames.multiply(axis_angle(v.axis, v.rate * t), v.start)
end

local SKY = { n2o2 = { 0.13, 0.17, 0.3 }, n2co2 = { 0.16, 0.2, 0.28 }, n2 = { 0.14, 0.16, 0.24 }, co2 = { 0.3, 0.2, 0.13 },
  sulfur = { 0.32, 0.27, 0.1 }, n2ch4 = { 0.3, 0.2, 0.08 }, co = { 0.22, 0.16, 0.12 }, h2he = { 0.2, 0.22, 0.3 } }

local PALETTE = { lava = { 0.9, 0.35, 0.1 }, iron = { 0.45, 0.4, 0.38 }, barren = { 0.5, 0.48, 0.45 }, desert = { 0.8, 0.62, 0.4 },
  terran = { 0.3, 0.5, 0.55 }, ocean = { 0.15, 0.35, 0.65 }, ice = { 0.85, 0.9, 0.95 }, glacier = { 0.75, 0.85, 0.95 },
  carbon = { 0.15, 0.14, 0.13 }, super_earth = { 0.45, 0.5, 0.4 }, mini_neptune = { 0.55, 0.75, 0.85 },
  ice_giant = { 0.45, 0.65, 0.9 }, gas_giant = { 0.85, 0.72, 0.55 }, hot_jupiter = { 0.6, 0.35, 0.25 },
  eyeball = { 0.6, 0.55, 0.5 }, shattered = { 0.4, 0.35, 0.33 }, comet = { 0.8, 0.85, 0.9 } }
universe.PALETTE = PALETTE

-- The light over the range at time t (seconds): sun direction (local), colour, intensity, sky colour, ambient,
-- star-map strength and the rotation from local into galaxy axes.
function universe.light(t)
  local v = universe.view()
  local q = orientation(v, t)
  local inv = frames.conjugate(q)
  local out = { rotation = q, air = v.air }
  local sys = v.sys
  local day = 0
  if v.place and sys.stars[1] then
    local off = offset_from(sys, v.place, 1, t)
    local d = normalize(frames.rotate(inv, off))
    local au = math.sqrt(off[1] * off[1] + off[2] * off[2] + off[3] * off[3]) / AU
    local flux = sys.stars[1].luminosity / (au * au)
    day = math.max(0, math.min(1, (d[2] + 0.1) / 0.35))
    local warm = v.air and math.max(0, math.min(1, d[2] * 1.6)) or 1 -- low suns redden in air
    local c = sys.stars[1].color
    out.sun = { direction = d, color = { c[1], c[2] * (0.55 + 0.45 * warm), c[3] * (0.3 + 0.7 * warm) },
      intensity = 5 * fk.math.pow(math.max(flux, 1e-6), 0.4) * math.max(0, math.min(1, (d[2] + 0.05) / 0.15)) }
  else
    out.sun = { direction = { 0, -1, 0 }, color = { 0, 0, 0 }, intensity = 0 }
  end
  if v.place and sys.stars[2] then -- a binary's second star: its own coloured light, no shadows
    local off = offset_from(sys, v.place, 2, t)
    local d = normalize(frames.rotate(inv, off))
    local au = math.sqrt(off[1] * off[1] + off[2] * off[2] + off[3] * off[3]) / AU
    local flux = sys.stars[2].luminosity / (au * au)
    out.sun2 = { direction = d, color = sys.stars[2].color,
      intensity = 5 * fk.math.pow(math.max(flux, 1e-6), 0.4) * math.max(0, math.min(1, (d[2] + 0.05) / 0.15)) }
  end
  local sky = v.air and (SKY[v.air.gas] or SKY.n2) or { 0, 0, 0 }
  local thin = v.air and math.max(0, math.min(1, (fk.math.log(v.air.pressure) / fk.math.log(10) + 2) / 2)) or 0
  local k = day * thin
  out.background = { 0, 0, 0 } -- space: the air's own scattering makes the sky (fk.gfx.atmosphere)
  if v.optics then
    local o, R = v.optics, sys.bodies[v.place].radius
    local ground = PALETTE[sys.bodies[v.place].class] or PALETTE.barren
    out.atmosphere = { centre = { 0, -R, 0 }, radius = R, top = o.top, height = o.height, rayleigh = o.rayleigh, mie = o.mie,
      absorb = o.absorb, ground = ground }
  end
  out.ambient = { sky = { 0.02 + 0.33 * k, 0.02 + 0.43 * k, 0.03 + 0.67 * k }, ground = { 0.02 + 0.26 * day, 0.02 + 0.2 * day, 0.02 + 0.14 * day } }
  out.stars = 1 - k
  out.galaxy_rotation = q -- system axes are galaxy axes
  return out
end



-- Draws the system's other bodies and stars in the sky over the range at time t, in local axes.
-- Draws the system's other bodies and stars in the sky over the range at time t, in local axes: real planets (with
-- their surfaces and air) when they look larger than a few pixels, small spheres when they are points of light.
-- focal: pixels per radian of the view.
function universe.draw_sky(t, sphere, light, focal)
  local v = universe.view()
  local sys = v.sys
  local inv = frames.conjugate(light.rotation)
  local here = v.place and position(sys, v.place, t) or { 0, 0, 0 }
  focal = focal or 300
  v.planets, v.stars = v.planets or {}, v.stars or {}
  local function relative(p)
    local rel = frames.rotate(inv, { p[1] - here[1], p[2] - here[2], p[3] - here[3] })
    return rel, math.sqrt(rel[1] * rel[1] + rel[2] * rel[2] + rel[3] * rel[3])
  end
  for i, s in ipairs(sys.stars) do
    local rel, d = relative(star_position(sys, i, t))
    if rel[2] >= -0.02 * d then
      v.stars[i] = v.stars[i] or star_view.new({ radius = math.max(s.radius, 1e4), color = s.color, pulsar = i == 1 and sys.pulsar },
        sys.seed + i)
      star_view.draw(v.stars[i], rel, t)
    end
  end
  for i, b in ipairs(sys.bodies) do
    if i ~= v.place and b.kind ~= "comet" then
      local rel, d = relative(position(sys, i, t))
      if d > b.radius * 1.01 and rel[2] >= -0.02 * d then -- above the horizon
        if b.radius / d * focal > 4 then
          if not v.planets[i] then v.planets[i] = planet_view.new(planets.describe(b), b.seed) end
          -- the body's axes: tilted, and turned by its day (presentation only)
          local spin = b.day and b.day > 0 and t * 2 * fk.math.pi / b.day or 0
          local q = frames.multiply(inv, frames.multiply({ fk.math.sin((b.tilt or 0) / 2), 0, 0, fk.math.cos((b.tilt or 0) / 2) },
            { 0, fk.math.sin(spin / 2), 0, fk.math.cos(spin / 2) }))
          v.planets[i]:draw(rel, q, focal, false, { sun = light.sun.direction, air = false })
        else
          local c = PALETTE[b.class] or PALETTE.barren
          local slice, at, k = frames.place_in_slices(rel, b.radius)
          fk.gfx.draw(sphere, frames.matrix(frames.IDENTITY, at, b.radius * k), { slice = slice, roughness = 0.9, color = c })
        end
      end
    end
  end
end

return universe
