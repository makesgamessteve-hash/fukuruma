-- physics spec: the Exosuit is a physics character. Walking into a crate shoves it along with a thud; the beacon
-- tower stops the suit; the resulting state is the same on every platform (the recorded hash).
local sim = require("fk.sim")

local RECORDED_HASH = "564d075b3afa2826"

return scenario {
  seed = 1,
  timeout_s = 20,
  run = function(t)
    local game = require("game")
    local s = sim.get(game.suit, "suit")
    s.x, s.z = 5, -4
    game.world:set(s.body, { position = { 5, 1.8, -4 } })
    game.helmet.yaw = math.pi / 2 -- look along +x, at the crate at (9, -4)
    local impacts = 0
    sim.listen("impact", function() impacts = impacts + 1 end)
    t.frames(10)
    t.key("W", true); t.frames(150); t.key("W", false)
    local crate = game.world:get(game.crates[3]).position
    t.expect(crate[1] > 11, "the crate was shoved along")
    t.expect(impacts > 0, "with a thud")
    game.helmet.pitch = -0.7 -- the crate is far below the eyes of a 3.6 m suit
    t.frames(40)
    t.screenshot("physics_push")
    game.helmet.pitch = 0
    s.x, s.z = 6, 1
    game.world:set(s.body, { position = { 6, 1.8, 1 } })
    game.helmet.yaw = 0 -- along +z, at the beacon tower at (6, 4)
    t.key("W", true); t.frames(120); t.key("W", false); t.frames(2)
    t.expect(math.abs(s.z - 2.8) < 0.05, "the beacon tower stops the suit")
    print("physics state hash " .. sim.hash())
    t.expect(sim.hash() == RECORDED_HASH, "the state hash differs from the recorded one")
  end,
}
