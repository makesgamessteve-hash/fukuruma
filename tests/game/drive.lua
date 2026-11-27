-- vehicle-controllers spec: the Commander walks the Walker towards the range from its cab, then flies the Continental
-- Explorer higher; each seen from its seat.
local sim = require("fk.sim")
local chain = require("chain")

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    t.frames(2)
    sim.send("board", { id = chain.up() })
    t.frames(2)
    local walker = chain.current()
    sim.send("drive", { throttle = 1, turn = 0, lift = 0 })
    t.frames(360)
    t.expect(walker.z > -150 + 25, "the Walker has walked towards the range")
    sim.send("drive", { throttle = 0, turn = 0, lift = 0 })
    game.helmet.yaw, game.helmet.pitch = 0, -0.15
    t.frames(30)
    t.screenshot("drive_walker")
    for _ = 1, 2 do
      sim.send("board", { id = chain.up() })
      t.frames(2)
    end
    local c = chain.current()
    t.expect(c.kind == "continental_explorer")
    local y0 = c.y
    sim.send("drive", { throttle = 1, turn = 0.5, lift = 1 })
    t.frames(300)
    t.expect(c.y > y0 + 200 and c.yaw > 0.05, "it climbs and turns as it flies")
    game.helmet.yaw, game.helmet.pitch = 0.3, -0.2
    t.frames(20)
    t.screenshot("drive_continental")
  end,
}
