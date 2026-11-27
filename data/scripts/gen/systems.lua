-- Star systems (CONCEPT 4.2): from a galaxy star (fk.galaxy) to a system descriptor of plain data: its stars, planets,
-- moons, rings, belts, comets and disks, with Kepler orbits (fk.orbit elements, metres) on rails. System archetypes are
-- a registry (systems.archetype) that mods can extend. Deterministic: one fk.rng stream per system, gen.units helpers.
local units = require("gen.units")
local classes = require("gen.planet_classes")

local AU, sqrt, floor = units.AU, math.sqrt, math.floor
local pow, cbrt, uniform, log_uniform = units.pow, units.cbrt, units.uniform, units.log_uniform
local TAU = 2 * fk.math.pi
local HILL_STABLE = 2 * sqrt(3) -- adjacent planets closer than this many mutual Hill radii are unstable

local systems = { archetypes = {}, order = {} }

-- def: id, hosts = {galaxy kinds}, weight (number), build(kit, rng, system, primary_index).
function systems.archetype(def)
  assert(type(def.id) == "string" and type(def.build) == "function" and def.hosts, "an archetype needs id, hosts and build")
  if not systems.archetypes[def.id] then systems.order[#systems.order + 1] = def.id end
  systems.archetypes[def.id] = def
end

-- The kit archetypes build with ------------------------------------------------------------------------------------

local kit = {}

-- Adds a star from a galaxy star (or from {kind, mass, seed}); returns its index.
function kit.star(sys, rng, src)
  local s = src.luminosity and src or fk.galaxy.physics(src.kind, src.mass, src.seed or rng:int())
  local i = #sys.stars + 1
  sys.stars[i] = { name = i == 1 and sys.name or sys.name .. " " .. string.char(64 + i), kind = s.kind, class = s.class,
    mass = s.mass, radius = s.radius * units.SUN_RADIUS, luminosity = s.luminosity, temperature = s.temperature,
    color = { s.color[1], s.color[2], s.color[3] } }
  return i
end

local function orbit(a, e, mu, rng, incl)
  return { a = a, e = e, i = incl or 0, node = rng:float() * TAU, periapsis = rng:float() * TAU, anomaly = rng:float() * TAU, mu = mu }
end

-- Two stars on orbits about their common barycentre (the system's root), a_au apart.
function kit.binary(sys, rng, i, j, a_au, e)
  local s1, s2 = sys.stars[i], sys.stars[j]
  local m, a = s1.mass + s2.mass, a_au * AU
  local mu = units.MU_SUN * m
  local base = orbit(a, e, mu, rng)
  for k, pair in ipairs({ { s1, s2 }, { s2, s1 } }) do
    local share = pair[2].mass / m -- each star's distance from the barycentre, and the mu that keeps the period
    pair[1].orbit = { a = a * share, e = e, i = 0, node = base.node, periapsis = base.periapsis + (k - 1) * TAU / 2,
      anomaly = base.anomaly, mu = mu * share * share * share }
  end
  sys.separation = a_au
end

-- A star on a wide orbit about the root.
function kit.companion(sys, rng, j, a_au, e)
  local total = 0
  for _, s in ipairs(sys.stars) do total = total + s.mass end
  sys.stars[j].orbit = orbit(a_au * AU, e, units.MU_SUN * total, rng, uniform(rng, 0, 0.3))
end

local function planet_radius(mass) -- Earth radii from Earth masses
  if mass < 2 then return pow(mass, 0.28) end
  if mass < 130 then return 0.8 * pow(mass, 0.59) end
  return 11.2
end

local function eccentricity(rng)
  local r = rng:float()
  if r < 0.7 then return uniform(rng, 0, 0.05) end
  if r < 0.95 then return uniform(rng, 0.05, 0.15) end
  return uniform(rng, 0.15, 0.35)
end

local function draw_mass(rng, a_au, frost, host_mass)
  local r = rng:float()
  local mass
  if a_au < frost then
    if a_au < 0.1 and r < 0.03 then mass = log_uniform(rng, 100, 1000)
    elseif r < 0.1 then mass = log_uniform(rng, 4, 20)
    else mass = log_uniform(rng, 0.05, 8) end
  else
    if r < 0.45 then mass = log_uniform(rng, 50, 1500) * (host_mass < 1 and host_mass or 1)
    elseif r < 0.7 then mass = log_uniform(rng, 10, 30)
    else mass = log_uniform(rng, 0.01, 2) end
  end
  if host_mass < 0.4 and mass > 50 and rng:chance(0.7) then mass = log_uniform(rng, 1, 10) end
  return mass
end

local function hill(a, e, mass, host_mass) -- metres; mass in Earth masses, host in solar masses
  return a * (1 - e) * cbrt(mass / (3 * host_mass * units.EARTH_PER_SUN))
end

-- A body's physical facts, class, atmosphere and look-up data. kind: "planet" or "moon".
local function body(sys, rng, kind, name, mass, a_au, L, host_mass, extra)
  local water = a_au > (sys.frost or 3) and uniform(rng, 0.5, 1) or rng:float()
  local p = { mass = mass, radius = planet_radius(mass), au = a_au, water = water, iron = rng:chance(0.15),
    carbon = rng:chance(0.02), shattered = kind == "planet" and rng:chance(0.004), locked = false }
  p.temperature = math.max(30, units.temperature(L, a_au, 0.3) + (extra and extra.heat or 0))
  p.locked = mass < 10 and a_au < 0.3 * cbrt(host_mass)
  local class = classes.classify(p)
  local b = { name = name, kind = kind, class = class.id, mass = mass, radius = p.radius * units.EARTH_RADIUS,
    temperature = p.temperature, water = p.water, locked = p.locked, seed = rng:int(),
    atmosphere = mass >= 0.1 and classes.atmosphere(class, rng) or nil, albedo = class.albedo,
    tilt = uniform(rng, 0, 0.5), day = p.locked and 0 or log_uniform(rng, 8, 60) * 3600 }
  return b
end

local LETTERS = "bcdefghijklmnopqrstuvwxyz"

local function add_moons(sys, rng, planet_index, host_mass, L)
  local p = sys.bodies[planet_index]
  local mass_e, a_p = p.mass, p.orbit.a
  local count
  if mass_e >= 10 then count = rng:range(1, 6)
  elseif mass_e >= 0.3 then count = rng:chance(0.4) and (rng:chance(0.25) and 2 or 1) or 0
  else count = 0 end
  local r_hill = hill(a_p, p.orbit.e, mass_e, host_mass)
  local a, outer = p.radius * uniform(rng, 3, 6), 0.4 * r_hill
  local moons = {}
  for n = 1, count do
    if a > outer then break end
    local m = mass_e >= 10 and log_uniform(rng, 0.0005, 0.03) or log_uniform(rng, 0.0005, 0.02)
    local heat = (mass_e >= 10 and n == 1 and rng:chance(0.2)) and 900 or 0 -- tidal heating of an inner moon (Io)
    local moon = body(sys, rng, "moon", p.name .. " " .. units.ROMAN[n], m, p.au, L, host_mass, { heat = heat })
    moon.around, moon.parent = "body", planet_index
    moon.orbit = orbit(a, uniform(rng, 0, 0.03), units.G * (mass_e + m) * units.EARTH_MASS, rng, uniform(rng, 0, 0.05))
    moon.au = p.au
    sys.bodies[#sys.bodies + 1] = moon
    moons[#moons + 1] = moon
    a = a * uniform(rng, 1.5, 2.5)
  end
  -- Rings inside the Roche limit (about 2.3 radii for icy debris), clear of the innermost moon.
  if rng:chance(mass_e >= 10 and 0.4 or 0.03) then
    local inner, outer_ring = p.radius * uniform(rng, 1.2, 1.5), p.radius * 2.3
    if moons[1] then outer_ring = math.min(outer_ring, 0.9 * moons[1].orbit.a * (1 - moons[1].orbit.e)) end
    if outer_ring > inner * 1.1 then p.rings = { inner = inner, outer = outer_ring, opacity = uniform(rng, 0.3, 0.9) } end
  end
end

-- Planets around a host (around: "root" or "star", parent: the star's index) between inner_au and outer_au, spaced
-- by mutual Hill radii with occasional resonance chains, then thinned until every neighbour pair is stable.
function kit.planets(sys, rng, around, parent, host_mass, L, inner_au, outer_au, max_count, opts)
  opts = opts or {}
  local frost = L > 0 and 2.7 * sqrt(L) or 0.01
  local placed = {}
  local a = inner_au * uniform(rng, 1, 2)
  for _ = 1, max_count do
    if a > outer_au then break end
    local mass = opts.mass and opts.mass(rng, a, frost) or draw_mass(rng, a, frost, host_mass)
    placed[#placed + 1] = { a = a, mass = mass, e = eccentricity(rng) }
    local x = cbrt(2 * mass / (3 * host_mass * units.EARTH_PER_SUN))
    local ratio
    if rng:chance(0.12) then ratio = rng:chance(0.5) and 1.3104 or 1.5874 -- 3:2 or 2:1 in period
    else
      local k = uniform(rng, 8, 16)
      if 1 - k * x / 2 <= 0.1 then break end
      ratio = (1 + k * x / 2) / (1 - k * x / 2)
    end
    a = a * math.max(ratio, 1.15)
  end
  -- Stability: neighbours at least HILL_STABLE mutual Hill radii apart from periapsis to apoapsis.
  local i = 2
  while placed[i] do
    local p, q = placed[i - 1], placed[i]
    local rh = cbrt((p.mass + q.mass) / (3 * host_mass * units.EARTH_PER_SUN)) * (p.a + q.a) / 2
    local gap = q.a * (1 - q.e) - p.a * (1 + p.e)
    if gap >= HILL_STABLE * rh then i = i + 1
    elseif q.e > 0 or p.e > 0 then q.e, p.e = 0, 0
    else table.remove(placed, i) end
  end
  local first = #sys.bodies + 1
  local host_name = around == "star" and sys.stars[parent].name or sys.name
  for n, pl in ipairs(placed) do
    local name = host_name .. " " .. LETTERS:sub(n, n)
    local b = body(sys, rng, "planet", name, pl.mass, pl.a, L, host_mass, opts)
    b.around, b.parent, b.au = around, parent, pl.a
    b.orbit = orbit(pl.a * AU, pl.e, units.MU_SUN * host_mass + units.MU_EARTH * pl.mass, rng, uniform(rng, 0, 0.05))
    b.trojans = pl.mass >= 50 and rng:chance(0.3) or nil
    sys.bodies[#sys.bodies + 1] = b
  end
  local last = #sys.bodies
  for k = first, last do add_moons(sys, rng, k, host_mass, L) end
  -- Asteroid belts in a wide gap, and sometimes a cold belt beyond the last planet.
  local prev
  for k = first, last do
    local b = sys.bodies[k]
    if prev and b.au / prev.au > 2.2 and not opts.no_belts and #sys.belts < 2 then
      sys.belts[#sys.belts + 1] = { kind = "asteroid", around = around, parent = parent, inner = prev.au * 1.3 * AU, outer = b.au / 1.3 * AU }
    end
    prev = b
  end
  if prev and rng:chance(0.5) and not opts.no_belts then
    sys.belts[#sys.belts + 1] = { kind = "kuiper", around = around, parent = parent, inner = prev.au * 1.5 * AU, outer = prev.au * 3 * AU }
  end
  return first, last
end

-- Comets on eccentric, tilted orbits.
function kit.comets(sys, rng, around, parent, host_mass, n, min_periapsis_au)
  for k = 1, n do
    local a = log_uniform(rng, 5, 60) * sqrt(host_mass > 0.1 and host_mass or 0.1)
    local e = uniform(rng, 0.6, 0.97)
    if a * (1 - e) < min_periapsis_au then e = 1 - min_periapsis_au / a end
    if e > 0 then
      local c = { name = sys.name .. " comet " .. k, kind = "comet", class = "comet", mass = 1e-9, radius = uniform(rng, 1e3, 2e4),
        temperature = 40, seed = rng:int(), around = around, parent = parent, au = a }
      c.orbit = orbit(a * AU, e, units.MU_SUN * host_mass, rng, uniform(rng, 0, 0.6))
      sys.bodies[#sys.bodies + 1] = c
    end
  end
end

function kit.disk(sys, kind, inner_au, outer_au) sys.disk = { kind = kind, inner = inner_au * AU, outer = outer_au * AU } end

systems.kit = kit

-- Archetypes -------------------------------------------------------------------------------------------------------

local function star_inner(s) return math.max(0.02 * cbrt(s.mass), 3 * s.radius / AU) end

local function planet_count(rng, mass)
  if mass < 0.08 then return rng:range(0, 3) end
  return rng:range(1, mass < 0.5 and 6 or 9)
end

local function lone(kit_, rng, sys, i, around, outer)
  local s = sys.stars[i]
  local inner = star_inner(s)
  kit_.planets(sys, rng, around or "root", around == "star" and i or 0, s.mass, s.luminosity, inner,
    outer or 30 * sqrt(s.mass) + 5, planet_count(rng, s.mass))
  kit_.comets(sys, rng, around or "root", around == "star" and i or 0, s.mass, rng:range(0, 4), math.max(0.05, inner))
end

systems.archetype({ id = "single", hosts = { "star", "brown_dwarf" }, weight = 0.55, build = function(k, rng, sys)
  lone(k, rng, sys, 1)
end })

systems.archetype({ id = "close_binary", hosts = { "star" }, weight = 0.10, build = function(k, rng, sys)
  local s1 = sys.stars[1]
  local j = k.star(sys, rng, { kind = "star", mass = s1.mass * uniform(rng, 0.3, 1) })
  local a, e = uniform(rng, 0.05, 0.4), uniform(rng, 0, 0.2)
  k.binary(sys, rng, 1, j, a, e)
  local m, L = s1.mass + sys.stars[j].mass, s1.luminosity + sys.stars[j].luminosity
  k.planets(sys, rng, "root", 0, m, L, 3.5 * a * (1 + e), 30 * sqrt(m) + 5, planet_count(rng, m))
  k.comets(sys, rng, "root", 0, m, rng:range(0, 3), 3.5 * a)
end })

systems.archetype({ id = "wide_binary", hosts = { "star" }, weight = 0.12, build = function(k, rng, sys)
  local j = k.star(sys, rng, { kind = "star", mass = sys.stars[1].mass * uniform(rng, 0.2, 1) })
  local a, e = uniform(rng, 50, 400), uniform(rng, 0, 0.4)
  k.binary(sys, rng, 1, j, a, e)
  local reach = a * (1 - e) / 3.5
  lone(k, rng, sys, 1, "star", reach)
  lone(k, rng, sys, j, "star", reach)
end })

systems.archetype({ id = "triple", hosts = { "star" }, weight = 0.05, build = function(k, rng, sys)
  local s1 = sys.stars[1]
  local j = k.star(sys, rng, { kind = "star", mass = s1.mass * uniform(rng, 0.3, 1) })
  local close, e = uniform(rng, 0.05, 0.3), uniform(rng, 0, 0.15)
  k.binary(sys, rng, 1, j, close, e)
  local t = k.star(sys, rng, { kind = "star", mass = s1.mass * uniform(rng, 0.1, 0.6) })
  local far, ef = uniform(rng, 80, 500), uniform(rng, 0, 0.3)
  k.companion(sys, rng, t, far, ef)
  local m = s1.mass + sys.stars[j].mass
  k.planets(sys, rng, "root", 0, m, s1.luminosity + sys.stars[j].luminosity, 3.5 * close * (1 + e), far * (1 - ef) / 3.5,
    planet_count(rng, m))
  lone(k, rng, sys, t, "star", far * (1 - ef) / 3.5)
end })

systems.archetype({ id = "brown_dwarf_companion", hosts = { "star" }, weight = 0.10, build = function(k, rng, sys)
  local j = k.star(sys, rng, { kind = "brown_dwarf", mass = uniform(rng, 0.013, 0.075) })
  local a, e = uniform(rng, 5, 60), uniform(rng, 0, 0.3)
  k.binary(sys, rng, 1, j, a, e)
  lone(k, rng, sys, 1, "star", a * (1 - e) / 3.5)
end })

systems.archetype({ id = "young_disk", hosts = { "star" }, weight = 0.08, build = function(k, rng, sys)
  local s = sys.stars[1]
  sys.young = true
  k.disk(sys, "protoplanetary", 0.1, 100 * sqrt(s.mass))
  k.planets(sys, rng, "root", 0, s.mass, s.luminosity, 1, 50, rng:range(0, 2),
    { no_belts = true, mass = function(r) return log_uniform(r, 10, 300) end })
end })

systems.archetype({ id = "white_dwarf_debris", hosts = { "white_dwarf" }, weight = 1, build = function(k, rng, sys)
  local s = sys.stars[1]
  k.disk(sys, "debris", 0.004, 0.02)
  k.planets(sys, rng, "root", 0, s.mass, s.luminosity, 1, 30, rng:range(0, 4))
end })

systems.archetype({ id = "pulsar", hosts = { "neutron_star" }, weight = 1, build = function(k, rng, sys)
  local s = sys.stars[1]
  sys.pulsar = { period = log_uniform(rng, 0.002, 2), tilt = uniform(rng, 0.2, 1.2) }
  k.planets(sys, rng, "root", 0, s.mass, s.luminosity, 0.1, 3, rng:range(1, 4), { heat = 250 }) -- irradiated worlds
end })

systems.archetype({ id = "black_hole", hosts = { "black_hole" }, weight = 1, build = function(k, rng, sys)
  local s = sys.stars[1]
  local isco = 6 * units.G * s.mass * units.SUN_MASS / (299792458 * 299792458)
  sys.disk = { kind = "accretion", inner = isco, outer = isco * uniform(rng, 200, 2000) }
  k.planets(sys, rng, "root", 0, s.mass, 0, 1, 50, rng:range(0, 3), { no_belts = true })
end })

systems.archetype({ id = "red_giant", hosts = { "giant" }, weight = 1, build = function(k, rng, sys)
  local s = sys.stars[1]
  local edge = 3 * s.radius / AU -- the inner planets were swallowed; their wreckage circles at the edge
  sys.belts[#sys.belts + 1] = { kind = "debris", around = "root", parent = 0, inner = edge * AU, outer = edge * 1.5 * AU }
  k.planets(sys, rng, "root", 0, s.mass, s.luminosity, math.max(edge * 2, 1), 40, rng:range(1, 5))
end })

systems.archetype({ id = "rogue", hosts = { "rogue_planet" }, weight = 1, build = function(_, rng, sys, _, src)
  local mass = src.mass * units.EARTH_PER_SUN
  local b = body(sys, rng, "planet", sys.name, mass, 1, 0, src.mass, { heat = rng:chance(0.3) and 200 or 0 })
  b.around, b.parent, b.au = "root", 0, 0
  sys.bodies[1] = b
  local a = b.radius * uniform(rng, 5, 10) -- no star: its moons only need to stay clear of each other
  for n = 1, mass >= 0.3 and rng:range(0, 3) or 0 do
    local m = log_uniform(rng, 0.001, 0.02)
    local moon = body(sys, rng, "moon", b.name .. " " .. units.ROMAN[n], m, 1, 0, src.mass)
    moon.around, moon.parent, moon.au = "body", 1, 0
    moon.orbit = orbit(a, uniform(rng, 0, 0.05), units.G * (mass + m) * units.EARTH_MASS, rng)
    sys.bodies[#sys.bodies + 1] = moon
    a = a * uniform(rng, 1.6, 2.5)
  end
end })

-- Generation -------------------------------------------------------------------------------------------------------

-- The system of a galaxy star (a table from fk.galaxy), curated by the Wonder Director: plain data, the same on every
-- platform.
function systems.generate(star)
  local rng = fk.rng("system", star.seed)
  local sys = { seed = star.seed, name = units.name(rng), galaxy = { star.position[1], star.position[2], star.position[3] },
    stars = {}, bodies = {}, belts = {}, marvels = {} }
  local weights = {}
  for _, id in ipairs(systems.order) do
    local a = systems.archetypes[id]
    for _, host in ipairs(a.hosts) do
      if host == star.kind then weights[id] = a.weight end
    end
  end
  sys.archetype = units.pick(rng, weights)
  if star.kind ~= "rogue_planet" then kit.star(sys, rng, star) end
  local L = sys.stars[1] and sys.stars[1].luminosity or 0
  if L > 0 then
    sys.habitable = { inner = sqrt(L / 1.1) * AU, outer = sqrt(L / 0.53) * AU }
    sys.frost = 2.7 * sqrt(L)
  end
  systems.archetypes[sys.archetype].build(kit, rng, sys, 1, star)
  return require("gen.wonders").curate(sys)
end

return systems
