-- doll-chain spec: from the range the chain stands to the south; the Commander boards the Walker, the Land Explorer
-- and the Continental Explorer in turn and looks out from each seat, then comes back down to the Exosuit on foot.
local sim = require("fk.sim")
local chain = require("chain")

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    t.frames(2)
    t.expect(chain.on_foot(), "a new game starts on foot")
    game.helmet.yaw, game.helmet.pitch = math.pi, 0.12 -- south, a little up
    t.frames(30)
    t.screenshot("chain_from_range")
    local seats = { { "walker", -0.12 }, { "land_explorer", -0.12 }, { "continental_explorer", -0.12 } }
    for _, s in ipairs(seats) do
      sim.send("board", { id = chain.up() })
      t.frames(30)
      t.expect(chain.current().kind == s[1], "at the " .. s[1] .. "'s controls")
      game.helmet.yaw, game.helmet.pitch = 0, s[2] -- back north, towards the range
      t.frames(20)
      t.screenshot("chain_seat_" .. s[1])
    end
    for _ = 1, 3 do
      sim.send("board", { id = chain.down() })
      t.frames(5)
    end
    t.expect(chain.on_foot(), "back down the chain to the Exosuit")
  end,
}
