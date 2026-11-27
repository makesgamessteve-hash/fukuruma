-- dig.lua (voxel-terrain spec): the dig command, its limits, and the dug walls.
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local dig = require("dig")
local universe = require("universe")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  return sim.get(game.suit, "suit")
end

local function place(s, x, z)
  sim.step(game)
  local h = game.world:height(x, z) or 0
  game.world:set(s.body, { position = { x, h + 1.85, z } })
  s.x, s.y, s.z, s.fx, s.fz = x, h, z, 0, 1
  for _ = 1, 3 do sim.step(game) end
end

return {
  ["digs open the ground in front of the suit, not on the deck"] = function()
    local s = start()
    sim.send("dig", {})
    sim.step(game)
    assert(#dig.list() == 0, "no digging into the deck")
    place(s, 0, 150)
    local heard = 0
    sim.listen("dig", function() heard = heard + 1 end)
    sim.send("dig", {})
    sim.step(game)
    assert(#dig.list() == 4 and heard == 1, "a dig")
    assert(math.abs(dig.list()[3] - (s.z + dig.REACH)) < 1e-6, "in front of the suit")
    sim.send("dig", {})
    sim.step(game)
    assert(#dig.list() == 4, "not again before the cooldown")
    for _ = 1, dig.COOLDOWN do sim.step(game) end
    sim.send("dig", {})
    sim.step(game)
    assert(#dig.list() == 8)
  end,
  ["the oldest digs go when there are too many, and a new world has none"] = function()
    local s = start()
    place(s, 0, 150)
    local d = sim.get(dig.id, "digs")
    for i = 1, dig.MAX do
      local n = #d.list
      d.list[n + 1], d.list[n + 2], d.list[n + 3], d.list[n + 4] = i, -50, 150, 1
    end
    sim.send("dig", {})
    sim.step(game)
    assert(#d.list == dig.MAX * 4 and d.list[1] == 2, "the oldest went")
    local near = dig.nearest({ 0, 0, 150 })
    assert(#near == dig.SHOWN * 4, "only the nearest are left out of the ground's drawing")
    assert(#dig.nearest({ 0, 0, 0 }) == dig.SHOWN * 4)
    d.world = "elsewhere"
    sim.step(game)
    assert(#dig.list() == 0, "another world: no digs")
  end,
  ["dug walls are meshed where the digs are"] = function()
    local s = start()
    place(s, 0, 150)
    sim.send("dig", {})
    sim.step(game)
    local state = {}
    assert(dig.draw(state, universe.ground()) > 0, "walls")
    local first = state.meshes
    dig.draw(state, universe.ground())
    assert(state.meshes == first, "kept until the digs change")
    assert(dig.draw({}, nil) == 0)
    local g = universe.ground()
    assert(g.surface:dig_mesh({ up = g.up, east = g.east, north = g.north, digs = {}, lo = { 0, 0, 0 } }) == nil,
      "no digs: no walls")
    assert(not pcall(g.surface.dig_mesh, g.surface, { up = g.up, east = g.east, north = g.north, digs = { 1, 2 } }))
    assert(not pcall(g.surface.dig_mesh, g.surface, { up = g.up, east = g.east, north = g.north, digs = {}, n = 99 }))
    assert(not pcall(game.world.digs, game.world, { 1, 2, 3 }))
    assert(not pcall(game.world.digs, game.world, { 1, 2, 3, 0 }), "a radius above 0")
  end,
  ["underground, the helmet lamp comes on and the sky's light fades"] = function()
    local s = start()
    place(s, 0, 150)
    local h = game.world:height(0, 150)
    assert(dig.lamp(game.world, { 0, h + 2, 150 }) == 0 and dig.daylight(game.world, { 0, h + 2, 150 }) == 1, "above")
    assert(dig.lamp(game.world, { 0, h - 0.5, 150 }) > 0, "just below: dim")
    assert(dig.lamp(game.world, { 0, h - 3, 150 }) == 1, "deep: full")
    local shallow, deep = dig.daylight(game.world, { 0, h - 0.5, 150 }), dig.daylight(game.world, { 0, h - 6, 150 })
    assert(shallow < 1 and deep < shallow and deep > 0.05, "less sky the deeper")
    assert(dig.lamp(game.world, { 1e7, 0, 1e7 }) == 0 and dig.daylight(game.world, { 1e7, 0, 1e7 }) == 1, "off the ground")
  end,
}
