-- effects spec: walking raises dust at every footstep and shakes the camera a little; the scan pulse sends a
-- ring of light over the ground with a flash; the comfort setting turns the shake off.
local sim = require("fk.sim")
local feel = require("fk.feel")
local comfort = require("settings.comfort")

local function suit()
  for _, s in sim.each("suit") do return s end
end

return scenario {
  seed = 1,
  timeout_s = 30,
  run = function(t)
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 8, max_lights = 8, max_particles = 4000, hdr = true, bloom = true, dither = true })
    t.key("W", true)
    t.frames(100)
    t.expect(suit().vz > 2 and suit().z > 2, "W walks forward (+z)")
    t.expect(fk.gfx.particles(0) > 0, "footsteps raise dust")
    t.expect(feel.trauma > 0, "footsteps shake the camera a little")
    t.key("W", false)
    t.frames(60)
    t.expect(suit().vz == 0, "the suit stops")
    t.key("E", true)
    t.frames(1)
    t.key("E", false)
    t.frames(3)
    t.expect(feel.trauma > 0.1 and #feel.flashes == 1, "the scan shakes the camera and flashes")
    t.frames(11)
    t.screenshot("feel_scan")
    comfort.current.shake = 0
    local yaw, pitch = feel.shake()
    t.expect(yaw == 0 and pitch == 0, "no shake with the comfort setting off")
    comfort.current.shake = 1
  end,
}
