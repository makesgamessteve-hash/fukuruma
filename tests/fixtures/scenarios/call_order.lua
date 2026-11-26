-- script-runtime spec: init once, then input, tick and draw in every frame.
local counter = require("counter")
return scenario {
  run = function(t)
    t.frames(2) -- the scenario starts after frame 1, so three frames have run now
    t.expect(counter.init == 1 and counter.input == 3 and counter.tick == 3 and counter.draw == 3, "init once, three frames")
    local order = table.concat(counter.order, " ")
    t.expect(order == "init input tick draw input tick draw input tick draw", order)
  end,
}
