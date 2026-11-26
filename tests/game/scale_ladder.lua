-- reference-frames spec: the scale ladder. The camera stands by a 1 m cube, off a 144 km hull, off a planet and off
-- a star, all placed in one frame tree; each step matches its reference image. Depth slices keep each in front of
-- what is behind it, and scaled space draws the far bodies.
local ladder = require("scale_ladder")
local frames = require("fk.frames")

return scenario {
  seed = 1,
  timeout_s = 30,
  run = function(t)
    local game = require("game")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 8, max_lights = 8, hdr = true, bloom = true, dither = true })
    fk.gfx.palette(nil)
    ladder.build()
    local step = 1
    game.draw = function()
      local w, h = fk.gfx.size()
      ladder.draw(step, w / h)
    end
    local slices = {}
    for i, s in ipairs(ladder.STEPS) do
      step = i
      t.frames(40)
      t.screenshot("ladder_" .. s.name)
      local viewer = ladder.camera(i)
      slices[i] = select(2, viewer:draw_args(ladder.frames.planet, { 0, 0, 0 }, nil, ladder.PLANET_RADIUS))
    end
    t.expect(slices[1] == "planetary" and slices[3] == "celestial" and slices[4] == "celestial",
      "the planet moves from the planetary slice into scaled space as the camera backs away")
    local station = frames.create(ladder.frames.system, { position = { 100 * ladder.AU, 0, 0 } })
    local worst = 0
    for i = 0, 100 do -- 0.1 mm steps at 100 AU
      local rel = frames.viewer(station, { i * 1e-4, 0, 0 }):relative(station, { 1, 0, 0 })
      worst = math.max(worst, math.abs(rel[1] - (1 - i * 1e-4)))
    end
    t.expect(worst < 1e-3, "position jitter at 100 AU is below 1 mm")
  end,
}
