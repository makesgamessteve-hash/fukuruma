-- scatter.lua and the instancing API (biomes-and-scatter spec).
local scatter = require("scatter")
local planets = require("gen.planets")
local frames = require("fk.frames")

local function ground(class)
  local desc = planets.describe({ class = class, radius = 2e6, temperature = 290, seed = 6, atmosphere = { gas = "n2o2", pressure = 1 } })
  local up = { 0, 1, 0 }
  return { desc = desc, surface = desc.surface, radius = 2e6, up = up, east = { 1, 0, 0 }, north = { 0, 0, 1 },
    to_local = { 0, 0, 0, 1 }, centre = { 0, -2e6, 0 } }
end

return {
  ["the ground's kind says what grows"] = function()
    assert(scatter.chances(0.3, 0.3, 0.3, 0.8).rock, "steep ground: rocks")
    local snow = scatter.chances(0.9, 0.92, 0.95, 0)
    assert(snow.rock and not snow.grass, "snow: a few rocks")
    local green = scatter.chances(0.2, 0.45, 0.15, 0.1)
    assert(green.grass > 1 and green.tree and green.shrub, "green ground: grass, shrubs and trees")
    local dry = scatter.chances(0.7, 0.55, 0.35, 0.1)
    assert(dry.rock and not dry.grass, "dry ground: rocks")
    assert(scatter.chances(0.3, 0.3, 0.4, 0.1).rock, "anything else: a few rocks")
  end,
  ["the same place always gets the same plants, and none on the deck"] = function()
    local g = ground("terran")
    scatter.density = 1
    local a, b = scatter.build(g, 0, 300, 1), scatter.build(g, 0, 300, 1)
    for _, kind in ipairs({ "grass", "shrub", "rock", "tree" }) do
      assert(#a[kind] == #b[kind] and #a[kind] % 8 == 0)
      for i = 1, #a[kind] do assert(a[kind][i] == b[kind][i]) end
    end
    local deck = scatter.build(g, 0, 0, 1)
    for _, kind in ipairs({ "grass", "shrub", "rock", "tree" }) do
      for i = 1, #deck[kind], 8 do
        assert(math.abs(deck[kind][i]) > scatter.DECK - 2 or math.abs(deck[kind][i + 2]) > scatter.DECK - 2, "not on the deck")
      end
    end
    scatter.density = 0.3
    local sparse = scatter.build(g, 0, 300, 1)
    assert(#sparse.rock <= #a.rock, "a lower level draws fewer")
    scatter.density = 1
  end,
  ["plants are drawn as instances and rebuilt when the eye moves on"] = function()
    local g = ground("terran")
    local state = {}
    local n = scatter.draw(state, g, { 0, 2, 300 })
    assert(n >= 0 and state.instances.grass)
    local first = state.instances
    scatter.draw(state, g, { 5, 2, 290 })
    assert(state.instances == first, "the same grid within a step")
    scatter.draw(state, g, { 40, 2, 300 })
    assert(state.instances ~= first, "a new grid further on")
    assert(scatter.draw(state, nil, { 0, 0, 0 }) == 0)
    scatter.density = 0
    assert(scatter.draw({}, g, { 0, 0, 0 }) == 0)
    scatter.density = 1
  end,
  ["instances and wind are checked"] = function()
    local i = fk.gfx.instances({ 0, 0, 0, 1, 0, 1, 0, 0 })
    assert(i)
    assert(not pcall(fk.gfx.instances, { 1, 2, 3 }), "eight numbers each")
    assert(not pcall(fk.gfx.instances, { 0, 0, 0, 1, 0, 1, 0, "x" }))
    local m = fk.gfx.mesh({ positions = { 0, 0, 0, 1, 0, 0, 0, 1, 0 }, colors = { 1, 1, 1, 1, 1, 1, 1, 1, 1 }, indices = { 1, 2, 3 } })
    local I = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
    fk.gfx.draw(m, I, { instances = i })
    fk.gfx.draw(m, I, { instances = fk.gfx.instances({}) }) -- none: nothing drawn
    assert(not pcall(fk.gfx.draw, m, I, { instances = {} }))
    fk.gfx.wind({ direction = { 1, 1 }, strength = 2, time = 3 })
    fk.gfx.wind({})
    assert(not pcall(fk.gfx.wind, { direction = { 0, 0 } }))
  end,
}
