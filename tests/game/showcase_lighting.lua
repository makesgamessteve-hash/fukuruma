-- rendering spec: the lit stage under different pipeline configurations, each against a reference image.
return scenario {
  seed = 1,
  timeout_s = 30,
  run = function(t)
    t.frames(60)
    t.screenshot("showcase_hdr")

    fk.gfx.configure({ supersample = 2 })
    t.frames(30)
    t.screenshot("showcase_supersampled")

    fk.gfx.configure({ supersample = 1, hdr = false, bloom = false, ao_samples = 0, shadow_cascades = 1,
      max_lights = 0, dither = false })
    t.frames(5)
    t.expect(fk.gfx.settings().hdr == false, "HDR is off")
    t.screenshot("showcase_ldr")

    fk.gfx.configure({ width = 640, height = 360, hdr = true, bloom = true, shadow_cascades = 4,
      shadow_size = 2048, ao_samples = 16, max_lights = 32, dither = true })
    t.frames(30)
    local w, h = fk.gfx.size()
    t.expect(w == 640 and h == 360, "the internal resolution changed")
    t.screenshot("showcase_640")
  end,
}
