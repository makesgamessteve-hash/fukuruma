-- M0 boot test: the game starts, renders the placeholder for two seconds and matches the reference image.
return scenario {
  seed = 1,
  timeout_s = 10,
  run = function(t)
    t.frames(120)
    local width, height = fk.gfx.size()
    t.expect(width > 0 and height > 0, "the frame has a size")
    t.screenshot("boot")
  end,
}
