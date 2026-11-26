-- Browser touch path: passes once the game has seen a real touch (the browser test taps the canvas).
return scenario {
  timeout_s = 60,
  run = function(t)
    while fk.input.device() ~= "touch" do t.frames(1) end
    t.expect(true)
  end,
}
