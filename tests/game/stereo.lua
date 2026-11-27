-- webxr spec: the stereo view, both eyes side by side (the VR headset's two views), from the range towards the
-- Walker; then one view again.
return scenario {
  seed = 1,
  timeout_s = 60,
  run = function(t)
    local game = require("game")
    t.frames(2)
    fk.gfx.stereo(0.064)
    game.helmet.yaw, game.helmet.pitch = math.pi, 0.08
    t.frames(20)
    t.screenshot("stereo_side_by_side")
    t.expect(not pcall(fk.gfx.stereo, -1), "the distance between the eyes is not negative")
    fk.gfx.stereo()
    t.frames(2)
    -- a headset's frames (web/xr.js reports them): the head turned 90 degrees to the left turns the view, in stereo
    t.xr(0.064, 0, math.sin(math.pi / 4), 0, math.cos(math.pi / 4))
    t.frames(3)
    t.expect(math.abs(game.helmet.yaw - math.pi / 2) < 1e-3 and game.xr, "the player's head is the Commander's head")
    local sim = require("fk.sim")
    local suit = sim.get(game.suit, "suit")
    local scans = 0
    sim.listen("scan", function() scans = scans + 1 end)
    t.xr_pad(0, -1, 0, 0, 2) -- the left stick forward, right A
    t.frames(30)
    t.expect(math.abs(suit.vx) + math.abs(suit.vz) > 0.5 and scans == 1, "the controllers walk and scan")
    t.xr_pad(0, 0, 0, 0, 0)
    t.xr()
    t.frames(2)
    t.expect(not game.xr, "the session has ended")
  end,
}
