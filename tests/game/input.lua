-- input spec: keys, gamepad and touch turn the placeholder ship; remapping; touch controls on screen.
local sim = require("fk.sim")
local actions = require("fk.actions")

local function speed()
  for _, spin in sim.each("spin") do return spin.speed end
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

return scenario {
  seed = 1,
  timeout_s = 20,
  run = function(t)
    t.expect(speed() == 0.5, "idle speed")
    t.key("D", true); t.frames(2)
    t.expect(fk.input.device() == "keyboard" and speed() == 2.0, "D turns right")
    t.key("D", false); t.frames(2)
    t.expect(speed() == 0.5, "released")

    t.gamepad_axis("leftx", -1); t.frames(2)
    t.expect(fk.input.device() == "gamepad" and near(speed(), -1.0), "the left stick turns left")
    t.gamepad_axis("leftx", 0.1); t.frames(2)
    t.expect(speed() == 0.5, "inside the dead zone")
    t.gamepad_button("a", true); t.frames(2)
    t.expect(speed() == 1.0, "boost doubles the speed")
    t.gamepad_button("a", false); t.frames(2)

    local w, h = fk.gfx.size()
    t.touch(1, 0.2, 0.7); t.frames(1)
    t.touch(1, 0.2 + actions.STICK_RANGE * h / w, 0.7); t.frames(2)
    t.expect(fk.input.device() == "touch" and near(speed(), 2.0), "the touch stick turns right")
    t.touch(2, 0.85, 0.7); t.frames(2)
    t.expect(near(speed(), 4.0), "the touch button boosts")
    t.screenshot("input_touch")
    t.touch(2); t.touch(1); t.frames(2)
    t.expect(speed() == 0.5 and #fk.input.touches() == 0, "fingers lifted")

    t.key("Space", true); t.frames(2)
    t.expect(actions.touch_controls() == nil, "touch controls hide after keyboard input")
    t.key("Space", false); t.frames(2)

    actions.bind("turn", { negative = { "J" }, positive = { "L" } })
    t.key("D", true); t.frames(2)
    t.expect(speed() == 0.5, "D is no longer bound")
    t.key("D", false); t.key("L", true); t.frames(2)
    t.expect(speed() == 2.0, "L is bound now")
    t.key("L", false)
    t.mouse_button(1, true); t.frames(1)
    t.expect(fk.input.mouse_button(1), "mouse buttons") -- the device stays "touch": this is within 500 ms of a touch
    t.mouse_button(1, false)
  end,
}
