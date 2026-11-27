-- gen/systems.lua, gen/planet_classes.lua and gen/checks.lua (star-systems spec).
local systems = require("gen.systems")
local classes = require("gen.planet_classes")
local checks = require("gen.checks")
local units = require("gen.units")
local galaxy = require("fk.galaxy")

local function star(kind, mass, seed)
  local s = fk.galaxy.physics(kind, mass, seed)
  s.seed, s.position = seed, { 26000, 0, 0 }
  return s
end

return {
  ["every archetype builds a checked system"] = function()
    local seen = {}
    for i, s in ipairs(galaxy.near(fk.galaxy.HOME, 25)) do
      local sys = systems.generate(s)
      assert(checks.system(sys) == nil, checks.system(sys))
      seen[sys.archetype] = true
      if i > 150 then break end
    end
    for _, kind in ipairs({ "white_dwarf", "neutron_star", "black_hole", "giant", "rogue_planet" }) do
      for seed = 1, 6 do
        local sys = systems.generate(star(kind, kind == "rogue_planet" and 6e-6 or 1.4, seed))
        assert(checks.system(sys) == nil, checks.system(sys))
        seen[sys.archetype] = true
      end
    end
    for seed = 1, 60 do seen[systems.generate(star("star", 1, seed)).archetype] = true end
    for _, id in ipairs(systems.order) do assert(seen[id] or id:find("^test_"), "archetype " .. id) end
  end,
  ["a system is plain, repeatable data"] = function()
    local s = galaxy.home_star()
    local a, b = systems.generate(s), systems.generate(s)
    assert(a.name == b.name and #a.bodies == #b.bodies and a.bodies[1].orbit.a == b.bodies[1].orbit.a)
    assert(a.stars[1].class == "G" and a.habitable.inner < a.habitable.outer and a.frost > 2)
    local p, v = fk.orbit.state(a.bodies[1].orbit, 1e6)
    assert(#p == 3 and #v == 3)
  end,
  ["classes and archetypes are registries"] = function()
    assert(classes.classify({ mass = 1, temperature = 290, water = 0.5, au = 1 }).id == "terran")
    assert(classes.classify({ mass = 300, temperature = 1200 }).id == "hot_jupiter")
    assert(classes.classify({ mass = 0.5, temperature = 100, water = 0 }).id == "ice")
    classes.register({ id = "test_glass", albedo = 0.5, rule = function(p) return p.glass end }, "barren")
    assert(classes.classify({ mass = 1, temperature = 100000, water = 0, glass = true }).id == "lava", "order matters")
    assert(classes.list[#classes.list].id == "barren" and classes.by_id.test_glass)
    assert(not pcall(classes.register, { id = "test_glass", rule = function() end }))
    assert(classes.atmosphere(classes.by_id.barren, fk.rng("t")) == nil)
    systems.archetype({ id = "test_empty", hosts = { "brown_dwarf" }, weight = 0, build = function() end })
    assert(systems.archetypes.test_empty and not pcall(systems.archetype, { id = "x" }))
    systems.archetype({ id = "test_empty", hosts = { "brown_dwarf" }, weight = 0, build = function() end }) -- replaced
    local r = fk.rng("units")
    assert(units.pick(r, { a = 0, b = 1 }) == "b" and #units.name(r) >= 4)
    assert(units.cbrt(-1) == 0 and math.abs(units.cbrt(27) - 3) < 1e-12)
  end,
  ["the checks catch broken systems"] = function()
    local sys = systems.generate(galaxy.home_star())
    local planets = {}
    for _, b in ipairs(sys.bodies) do if b.kind == "planet" and b.orbit then planets[#planets + 1] = b end end
    local saved = planets[2].orbit.a
    planets[2].orbit.a = planets[1].orbit.a * 1.0001
    assert(checks.system(sys):find("too close"))
    planets[2].orbit.a = saved
    planets[1].orbit.e = 2
    assert(checks.system(sys):find("eccentricity"))
    planets[1].orbit.e = 0
    local fake = { bodies = { { name = "P", kind = "planet", mass = 300, radius = 7e7, around = "root", parent = 0,
      orbit = { a = 7.5e11, e = 0, mu = 1.3e20 }, rings = { inner = 8e7, outer = 1.5e8 } },
      { name = "M", kind = "moon", parent = 1, mass = 0.01, radius = 1e6, orbit = { a = 1.2e8, e = 0, mu = 1e17 } } } }
    assert(checks.system(fake):find("crosses the rings"))
    fake.bodies[1].rings.outer = 5e8
    assert(checks.system(fake):find("Roche"))
    fake.bodies[1].rings = nil
    fake.bodies[2].orbit.a = 1e11
    assert(checks.system(fake):find("Hill sphere"))
    fake.bodies[2].orbit.a = 1e8
    assert(checks.system(fake):find("grazes"))
  end,
}
