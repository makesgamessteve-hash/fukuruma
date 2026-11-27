-- terrain.lua, universe.ground and the near-ground drawing of planet_view (terrain-streaming spec).
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local terrain = require("terrain")
local universe = require("universe")
local planet_view = require("planet_view")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  return sim.get(game.suit, "suit")
end

local function walk(ticks, x, z)
  sim.send("move", { x = x, z = z, fx = x == 0 and 0 or (x < 0 and -1 or 1), fz = z == 0 and 0 or (z < 0 and -1 or 1) })
  for _ = 1, ticks do sim.step(game) end
end

return {
  ["the ground is the world's own, levelled under the deck"] = function()
    start()
    local g = universe.ground()
    assert(g and g.surface and g.radius > 1e6, "the home world has ground")
    sim.step(game) -- the first tick lays the tile
    local h0 = game.world:height(0, 0)
    assert(h0 and math.abs(h0) < 1e-3, "the site is level with the deck")
    assert(math.abs(g.up[1] * g.east[1] + g.up[2] * g.east[2] + g.up[3] * g.east[3]) < 1e-9, "a proper frame")
    assert(g.surface:height(g.up[1], g.up[2], g.up[3]) > 20, "the site is on land")
  end,
  ["a loaded game stands on the same ground"] = function()
    start()
    walk(2400, -6.3, 0) -- off the deck, 100 m and more
    local s = sim.get(game.suit, "suit")
    assert(s.x < -100, "walked off the deck")
    local snap = sim.snapshot()
    walk(300, 0, 6.3)
    local first = sim.hash()
    start() -- a new session: the tile under the suit is built afresh
    sim.restore(snap)
    walk(300, 0, 6.3)
    assert(sim.hash() == first, "the same steps on the same ground")
  end,
  ["the tile follows in steps and goes with the ground"] = function()
    local w = fk.physics.world({})
    local state = {}
    start()
    local g = universe.ground()
    assert(terrain.follow(state, w, g, 0, 0), "built")
    assert(not terrain.follow(state, w, g, 5, -5), "the same tile within a step")
    assert(terrain.follow(state, w, g, 30, 0), "moved on")
    assert(w:height(30, 0) and not w:height(200, 0))
    assert(not terrain.follow(state, w, nil, 0, 0) and w:height(30, 0) == nil, "no ground: no terrain")
    assert(not terrain.follow({}, w, nil, 0, 0))
  end,
  ["the ground is drawn from the eye, with the slices fitted to it"] = function()
    start()
    local g = universe.ground()
    local state = {}
    assert(terrain.draw(state, nil, { 0, 2, 0 }, { 0, 0, -1 }, 1, 300) == 0)
    local near = terrain.draw(state, g, { 0, 2, 0 }, { 0, 0, -1 }, 1, 300, true)
    assert(near > 0 and state.view.draws >= near, "chunks near the eye are drawn, some in two slices")
    local high = terrain.draw(state, g, { 0, 3e5, 0 }, { 0, -1, 0 }, 1, 300, true)
    assert(high > 0)
    local old = planet_view.KEEP
    planet_view.KEEP = 0
    terrain.draw(state, g, { 0, 4e6, 0 }, { 0, -1, 0 }, 1, 300) -- from space: one placement for the whole world
    planet_view.KEEP = old
  end,
  ["planet surfaces level sites and sample grids"] = function()
    local planets = require("gen.planets")
    local d = planets.describe({ class = "barren", radius = 2e6, temperature = 200, seed = 3 })
    local s = d.surface
    local before = s:height(0, 1, 0)
    s:flatten(0, 1, 0, 500)
    assert(s:height(0, 1, 0) == before, "the site keeps its height")
    local h = s:grid({ up = { 0, 1, 0 }, east = { 1, 0, 0 }, north = { 0, 0, 1 }, origin = { -40, -40 }, cell = 10, n = 8 })
    assert(#h == 81 and math.abs(h[41]) < 1e-6, "the centre is the reference")
    for i = 1, 81 do assert(math.abs(h[i]) < 1, "level within the site") end
    assert(not pcall(s.grid, s, { up = { 0, 2, 0 }, east = { 1, 0, 0 }, north = { 0, 0, 1 } }), "unit vectors")
    assert(not pcall(s.grid, s, { up = { 0, 1, 0 }, east = { 1, 0, 0 }, north = { 0, 0, 1 }, n = 0 }))
    assert(not pcall(s.grid, s, { east = { 1, 0, 0 } }))
    assert(not pcall(s.flatten, s, 0, 1, 0, -1))
  end,
}
