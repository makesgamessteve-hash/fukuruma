-- script-runtime spec: init once, then tick before draw in every frame.
local counter = require("counter")
return scenario {
  run = function(t)
    t.frames(2) -- the scenario starts after frame 1, so three frames have run now
    t.expect(counter.init == 1 and counter.tick == 3 and counter.draw == 3, "init once, three ticks, three draws")
    t.expect(table.concat(counter.order, " ") == "init tick draw tick draw tick draw", table.concat(counter.order, " "))
  end,
}
