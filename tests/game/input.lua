-- input spec: keys, gamepad and touch move the Exosuit; sprint; remapping; touch controls on screen.
-- The camera looks along +z: right on screen is -x, up on the stick is +z.
local sim = require("fk.sim")
local actions = require("fk.actions")
local game -- require("game") works once main.lua has run, inside run()

local function want()
  local s = sim.get(game.suit, "suit")
  return s.wx, s.wz
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

return scenario {
  seed = 1,
  timeout_s = 20,
  run = function(t)
    game = require("game")
    local wx, wz = want()
    t.expect(wx == 0 and wz == 0, "standing")
    t.key("D", true); t.frames(2)
    t.expect(fk.input.device() == "keyboard" and select(1, want()) == -game.WALK, "D walks right")
    t.key("D", false); t.frames(2)
    t.expect(select(1, want()) == 0, "released")

    t.gamepad_axis("leftx", -1); t.frames(2)
    t.expect(fk.input.device() == "gamepad" and near(select(1, want()), game.WALK), "the left stick walks left")
    t.gamepad_axis("leftx", 0.1); t.frames(2)
    t.expect(select(1, want()) == 0, "inside the dead zone")
    t.gamepad_axis("lefty", -1); t.gamepad_button("a", true); t.frames(2)
    t.expect(near(select(2, want()), game.RUN), "stick up with A runs forward")
    t.gamepad_axis("lefty", 0); t.gamepad_button("a", false); t.frames(2)

    local w, h = fk.gfx.size()
    t.touch(1, 0.2, 0.7); t.frames(1)
    t.touch(1, 0.2 + actions.STICK_RANGE * h / w, 0.7); t.frames(2)
    t.expect(fk.input.device() == "touch" and near(select(1, want()), -game.WALK), "the touch stick walks right")
    t.touch(2, 0.86, 0.72); t.frames(2)
    t.expect(near(select(1, want()), -game.RUN), "the touch button sprints")
    t.screenshot("input_touch")
    t.touch(2); t.touch(1); t.frames(2)
    t.expect(select(1, want()) == 0 and #fk.input.touches() == 0, "fingers lifted")

    t.key("Space", true); t.frames(2)
    t.expect(actions.touch_controls() == nil, "touch controls hide after keyboard input")
    t.key("Space", false); t.frames(2)

    actions.bind("move_x", { negative = { "J" }, positive = { "L" } })
    t.key("D", true); t.frames(2)
    t.expect(select(1, want()) == 0, "D is no longer bound")
    t.key("D", false); t.key("L", true); t.frames(2)
    t.expect(select(1, want()) == -game.WALK, "L is bound now")
    t.key("L", false)
    t.mouse_button(1, true); t.frames(1)
    t.expect(fk.input.mouse_button(1), "mouse buttons") -- the device stays "touch": this is within 500 ms of a touch
    t.mouse_button(1, false)
  end,
}
