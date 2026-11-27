-- universe.lua and navmap.lua (navigation-maps spec).
local sim = require("fk.sim")
local universe = require("universe")
local navmap = require("navmap")
local systems = require("gen.systems")
local galaxy = require("fk.galaxy")

local function fake_input(keys)
  local real = fk.input
  fk.input = setmetatable({ key = function(k) return keys[k] == true end, button = function() return false end,
    axis = function() return 0 end, mouse_button = function() return false end, touches = function() return {} end },
    { __index = real })
  return function() fk.input = real end
end

local function start()
  sim.reset()
  local g
  universe.install(function(x) g = x end)
  return g
end

return {
  ["a new game starts on a welcoming world, and jumps move the range"] = function()
    local g = start()
    local v = universe.view()
    local here = v.sys.bodies[v.place]
    assert(here.class == "terran" or here.class == "ocean")
    assert(g > 0.5 and g < 30 and math.abs(g - universe.gravity(here)) < 1e-12)
    local target
    for _, s in ipairs(galaxy.near(v.star.position, universe.RANGE)) do
      if s.seed ~= v.star.seed then target = s break end
    end
    sim.send("jump", { sector = target.sector, seed = target.seed })
    local jumped = 0
    sim.listen("jump", function() jumped = jumped + 1 end)
    sim.step({})
    assert(jumped == 1 and universe.state().seed == target.seed and universe.state().jumps == 1)
    assert(universe.view().seed == target.seed, "the view follows")
    sim.send("jump", { sector = target.sector, seed = target.seed }) -- the same star: nothing happens
    local far = galaxy.near(v.star.position, 60)
    sim.send("jump", { sector = far[#far].sector, seed = far[#far].seed }) -- out of range: nothing happens
    sim.step({})
    assert(jumped == 1 and universe.state().jumps == 1)
  end,
  ["light, sky and bodies over the range"] = function()
    start()
    local l = universe.light(0)
    assert(math.abs(l.sun.direction[2] - universe.SUN_AT_START[2]) < 1e-9, "the star stands where the range arrives")
    assert(l.sun.intensity > 0 and l.stars < 1 and l.atmosphere and l.atmosphere.radius > 0, "the air makes the sky")
    local night
    for t = 0, 3e5, 2000 do
      local x = universe.light(t)
      if x.sun.direction[2] < -0.2 then night = x break end
    end
    assert(night and night.sun.intensity == 0 and night.stars > 0.9, "the world turns: night falls and the stars come out")
    local sphere = fk.gfx.mesh(require("shapes").sphere(1, 8, { 1, 1, 1 }))
    universe.draw_sky(0, sphere, l)
    assert(universe.gravity(nil) == 0.5)
    local empty = { bodies = {} }
    assert(universe.place_for(empty) == nil)
    local rogue = fk.galaxy.physics("rogue_planet", 3e-6, 5)
    rogue.seed, rogue.position = 5, { 26000, 0, 0 }
    local sys = systems.generate(rogue)
    assert(universe.place_for(sys) == 1)
  end,
  ["the maps open, choose, scrub time and jump"] = function()
    start()
    navmap.toggle()
    assert(navmap.open and navmap.mode == "galaxy")
    local restore = fake_input({ Right = true })
    navmap.update(1 / 60)
    restore()
    assert(navmap.selected == 2)
    restore = fake_input({ Left = true })
    navmap.update(1 / 60)
    restore()
    navmap.draw(0.1)
    navmap.draw(0.6)
    restore = fake_input({ Tab = true })
    navmap.update(1 / 60)
    restore()
    assert(navmap.mode == "system")
    restore = fake_input({ Up = true })
    navmap.update(1 / 60)
    restore()
    navmap.update(1)
    assert(navmap.speed == 1 and navmap.time_offset > 0)
    restore = fake_input({ Down = true })
    navmap.update(1 / 60)
    navmap.update(1 / 60)
    restore()
    navmap.update(1 / 60)
    navmap.draw(0.2)
    restore = fake_input({ Tab = true, Right = true })
    navmap.update(1 / 60)
    restore()
    assert(navmap.mode == "galaxy")
    restore = fake_input({ Return = true })
    local target = navmap.update(1 / 60)
    restore()
    assert(target and target.seed and not navmap.open, "Enter jumps to a star in range and closes the map")
    navmap.toggle()
    navmap.selected = #require("fk.galaxy").near(universe.view().star.position, 30) - 1 -- far away: out of range
    restore = fake_input({ Return = true })
    assert(navmap.update(1 / 60) == nil and navmap.open)
    restore()
    navmap.draw(0)
    restore = fake_input({ Escape = true })
    navmap.update(1 / 60)
    restore()
    assert(not navmap.open)
    navmap.draw(0)
  end,
}
