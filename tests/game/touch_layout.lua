-- touch-controls spec: a touch layout per doll. On foot the suit's buttons; tapping UP boards the Walker, whose
-- layout has its own buttons; DOWN goes back to the Exosuit; in a flying doll CLIMB lifts it.
local chain = require("chain")
local sim = require("fk.sim")

local function tap(t, x, y)
  t.touch(1, x, y); t.frames(2)
  t.touch(1); t.frames(2)
end

local function has(names, wanted)
  for _, n in ipairs(names) do
    if n == wanted then return true end
  end
  return false
end

return scenario {
  seed = 1,
  timeout_s = 120,
  run = function(t)
    local game = require("game")
    t.touch(1, 0.5, 0.2); t.frames(1); t.touch(1); t.frames(1) -- the game sees a touch screen
    t.expect(fk.input.device() == "touch")
    local names = game.touch_layout()
    t.expect(has(names, "sprint") and has(names, "dig") and has(names, "board_up") and not has(names, "deploy"),
      "on foot: run, dig, up to the Walker")
    game.helmet.yaw, game.helmet.pitch = math.pi, 0.1
    t.frames(10)
    t.screenshot("touch_on_foot")
    tap(t, 0.74, 0.6) -- UP
    t.expect(chain.current().kind == "walker", "UP boarded the Walker")
    names = game.touch_layout()
    t.expect(has(names, "board_down") and has(names, "recall") and not has(names, "sprint"), "the Walker's own buttons")
    game.helmet.yaw, game.helmet.pitch = 0, -0.1
    t.frames(10)
    t.screenshot("touch_walker")
    tap(t, 0.86, 0.8) -- DOWN
    t.expect(chain.on_foot(), "DOWN went back to the Exosuit")
    for _ = 1, 3 do
      sim.send("board", { id = chain.up() })
      t.frames(1)
    end
    t.expect(chain.current().kind == "continental_explorer" and has(game.touch_layout(), "lift_up"))
    local y0 = chain.current().y
    t.touch(1, 0.52, 0.72); t.frames(60); t.touch(1); t.frames(1) -- CLIMB held for a second
    t.expect(chain.current().y > y0 + 10, "CLIMB lifts the flying doll")
  end,
}
