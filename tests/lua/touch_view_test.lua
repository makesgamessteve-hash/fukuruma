local touch_view = require("touch_view")

return {
  ["draws nothing outside touch mode"] = function()
    touch_view.init()
    touch_view.draw(nil)
  end,
  ["draws the stick and buttons"] = function()
    touch_view.init()
    touch_view.draw({
      stick = { x = 0.2, y = 0.7, r = 0.12, knob_x = 0.25, knob_y = 0.7 },
      buttons = { { name = "boost", x = 0.85, y = 0.7, r = 0.1, held = true }, { name = "b", x = 0.7, y = 0.7, r = 0.1, held = false } },
    })
  end,
}
