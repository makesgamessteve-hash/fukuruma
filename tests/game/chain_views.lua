-- doll-chain presentation: the ship AI greets the Commander in the Walker's cab; the survey drone circles the doll the
-- Commander sits in at a distance scaled to its size; a deployed Walker eases out of the Land Explorer.
local sim = require("fk.sim")
local chain = require("chain")

return scenario {
  seed = 1,
  timeout_s = 120,
  run = function(t)
    local game = require("game")
    t.frames(2)
    sim.send("board", { id = chain.up() })
    game.helmet.yaw, game.helmet.pitch = 0, -0.12
    t.frames(20)
    t.expect(game.ai.text and game.ai.text:find("WELCOME ABOARD", 1, true), "the ship AI greets the Commander")
    t.screenshot("views_walker_ai")
    game.view = "drone"
    game.drone.yaw, game.drone.pitch = 2.4, 0.35
    t.frames(20)
    t.screenshot("views_walker_drone")
    game.view = "helmet"
    sim.send("board", { id = chain.up() })
    t.frames(5)
    sim.send("deploy", { kind = "walker" })
    game.view = "drone"
    t.frames(80) -- about half way out
    t.screenshot("views_deploying")
  end,
}
