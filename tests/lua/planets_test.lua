-- gen/planets.lua, fk.planet and planet_view.lua (planet-descriptors and planet-rendering specs).
local planets = require("gen.planets")
local planet_view = require("planet_view")
local classes = require("gen.planet_classes")

local function fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(text, 1, true), "expected '" .. text .. "', got " .. tostring(err))
end

local function body(class, extra)
  local b = { class = class, radius = 6.371e6, temperature = 288, seed = 77 }
  for k, v in pairs(extra or {}) do b[k] = v end
  return b
end

return {
  ["every class has a recipe and a describable surface"] = function()
    for _, c in ipairs(classes.list) do
      if not c.id:find("^test_") then
        local d = planets.describe(body(c.id, { atmosphere = { gas = "n2o2", pressure = 1 } }))
        assert(d.surface and d.radius == 6.371e6 and d.atmosphere.top > d.radius, c.id)
        local h = d.surface:height(0.3, 0.8, 0.5)
        assert(h >= -d.relief * 3 and h <= d.relief * 3, c.id .. " height in range")
        local r, g, b = d.surface:color(0.3, 0.8, 0.5)
        assert(r >= 0 and g >= 0 and b >= 0, c.id)
      end
    end
    local unknown = planets.describe(body("comet"))
    assert(unknown.surface and not unknown.atmosphere, "an unknown class looks barren")
    local cold = planets.describe(body("terran", { temperature = 200 }))
    local r, g, b = cold.surface:color(0, 1, 0)
    assert(r > 0.7 and b > 0.7, "cold poles are ice")
    local thick = planets.describe(body("desert", { atmosphere = { gas = "sulfur", pressure = 90 } }))
    assert(thick.atmosphere.mie == planets.AIR.sulfur.mie * 50, "very deep air is capped")
    assert(planets.describe(body("super_earth", { temperature = 500 })).surface)
    local a, b2 = planets.describe(body("ocean")), planets.describe(body("ocean"))
    assert(a.surface:height(0.1, 0.2, 0.9) == b2.surface:height(0.1, 0.2, 0.9), "the same body, the same planet")
  end,
  ["chunks build in the background with skirts"] = function()
    local d = planets.describe(body("terran"))
    local req = d.surface:chunk(2, 1, 1, 0)
    local mesh, centre, bound = req:mesh()
    assert(mesh and #centre == 3 and bound > 0 and req:ready())
    assert(req:mesh() == mesh, "the same mesh every time")
    local x, y, z = fk.planet.direction(4, 0, 0)
    assert(x == 0 and y == 0 and z == 1)
    d.surface:chunk(0, 3, 7, 7) -- never read: its job finishes before it is collected
    fails(function() d.surface:chunk(6, 0, 0, 0) end, "the face must be from 0 to 5")
    fails(function() d.surface:chunk(0, 30, 0, 0) end, "the level must be from 0 to 24")
    fails(function() d.surface:chunk(0, 1, 2, 0) end, "inside the face")
    fails(function() fk.planet.direction(9, 0, 0) end, "the face must be from 0 to 5")
    fails(function() d.surface:height(0, 0, 0) end, "must not be zero")
    fails(function() fk.planet.new({ radius = -1 }) end, "radius must be above 0")
    fails(function() fk.planet.new({}) end, "'height' must be a noise graph")
    assert(fk.planet.new({ bands = true }):height(1, 0, 0) == 0, "giants have no relief")
  end,
  ["the view splits near the camera, culls the far side and forgets old chunks"] = function()
    local d = planets.describe(body("barren"))
    local v = planet_view.new(d)
    local far = #v:select({ 0, 0, 6.371e6 * 20 }, 300, true)
    local near = #v:select({ 0, 0, 6.371e6 * 1.05 }, 300, true)
    assert(near > far and far >= 1, "more chunks up close")
    local drawn = v:draw({ 0, 0, -6.371e6 * 3 }, { 0, 0, 0, 1 }, 300, false, { sun = { 1, 0, 0 } })
    assert(drawn >= 0)
    planet_view.KEEP = 0
    v:draw({ 0, 0, -6.371e6 * 3 }, { 0, 0, 0, 1 }, 300, true)
    planet_view.KEEP = 300
    local ringed = planet_view.new(planets.describe(body("gas_giant", { radius = 7e7,
      rings = { inner = 9e7, outer = 1.4e8, opacity = 0.7, gaps = 2, polar = true } })), 3)
    assert(ringed.rings)
    ringed:draw({ 0, 0, -3e8 }, { 0, 0, 0, 1 }, 300, true, { sun = { 0, -1, 0 } })
    ringed:draw({ 0, 0, -3e8 }, { 0, 0, 0, 1 }, 300, true, { sun = { 0, 1, 0 } })
    local thin = planet_view.new(planets.describe(body("gas_giant", { radius = 7e7, rings = { inner = 9e7, outer = 1.4e8, opacity = 0.01 } })), 3)
    assert(thin.rings == nil, "rings too thin to see make no mesh")
  end,
}
