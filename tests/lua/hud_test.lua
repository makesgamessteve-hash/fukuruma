-- hud.lua (effects spec): the visor HUD and the survey drone's feed.
local hud = require("hud")

return {
  ["the heading is in whole degrees, clockwise from north"] = function()
    assert(hud.heading(0) == 0)
    assert(hud.heading(-math.pi / 2) == 90, "turning right (yaw down) is east")
    assert(hud.heading(math.pi / 2) == 270)
    assert(hud.heading(-2 * math.pi + 0.001) == 0, "wraps")
  end,
  ["the visor and the drone feed draw"] = function()
    hud.visor({ yaw = 0.3, speed = 2.6, scan = 1, turn_rate = 0, vignette = true })
    hud.visor({ yaw = -2, speed = 0, scan = 0.4, turn_rate = 4, vignette = true })
    hud.visor({ yaw = 1, speed = 6.3, scan = 0, turn_rate = 4, vignette = false })
    hud.drone(0.2)
    hud.drone(0.7)
  end,
}
