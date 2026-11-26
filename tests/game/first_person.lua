-- effects and input specs: the sandbox is seen through the Commander's eyes. The mouse, the right stick and a
-- finger on the right half of a touch screen turn the view; walking goes where the Commander looks. V opens the
-- survey drone's outside view, which only looks: the suit holds still until V returns to the helmet.
local sim = require("fk.sim")
local game -- require("game") works once main.lua has run, inside run()

local function suit() return sim.get(game.suit, "suit") end

return scenario {
  seed = 1,
  timeout_s = 20,
  run = function(t)
    game = require("game")
    t.frames(30)
    t.expect(game.view == "helmet", "starts in the helmet")
    t.screenshot("first_person_helmet")

    t.mouse_move(-0.5, 0); t.frames(1) -- half a screen to the left: 1.5 rad
    t.expect(math.abs(game.helmet.yaw - 1.5) < 1e-6, "the mouse turns the view left")
    t.key("W", true); t.frames(60)
    local s = suit()
    t.expect(s.x > 1.5 and s.lx > 0.99, "W walks where the Commander looks (+x)")
    t.key("W", false); t.frames(2)

    local yaw = game.helmet.yaw
    t.gamepad_axis("rightx", 1); t.frames(20)
    t.gamepad_axis("rightx", 0); t.frames(1)
    t.expect(game.helmet.yaw < yaw - 0.5, "the right stick turns the view right")

    yaw = game.helmet.yaw
    t.touch(1, 0.6, 0.5); t.frames(1)
    t.touch(1, 0.7, 0.5); t.frames(1)
    t.touch(1); t.frames(1)
    t.expect(math.abs(game.helmet.yaw - (yaw - 0.4)) < 1e-6, "dragging on the right half turns the view")

    t.key("V", true); t.frames(1); t.key("V", false)
    t.expect(game.view == "drone", "V opens the outside view")
    local x = suit().x
    t.key("W", true); t.key("E", true); t.frames(30)
    t.expect(suit().wx == 0 and suit().wz == 0 and math.abs(suit().x - x) < 0.5, "the suit holds still")
    t.key("W", false); t.key("E", false)
    t.frames(30)
    t.screenshot("first_person_drone")
    t.key("V", true); t.frames(1); t.key("V", false); t.frames(1)
    t.expect(game.view == "helmet", "V returns to the Commander's eyes")
  end,
}
