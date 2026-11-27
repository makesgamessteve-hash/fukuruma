-- Determinism across platforms (simulation spec): commands built from random streams, 120 ticks,
-- then the state hash must equal the value recorded below on Linux, Windows, macOS and in the browser.
local sim = require("fk.sim")

local RECORDED_HASH = "01cc9895106a7bcf"

return scenario {
  seed = 1,
  timeout_s = 10,
  run = function(t)
    sim.on("spawn", function(args)
      local id = sim.create()
      sim.set(id, "body", { x = args.x, y = args.y, mass = args.mass, label = args.label })
    end)
    sim.on("push", function(args)
      for id, body in sim.each("body") do
        body.x = body.x + args.dx / body.mass
        if body.x > 150 then sim.destroy(id) end
      end
    end)
    local rng = fk.rng("scenario", "spawn")
    for i = 1, 20 do
      sim.send("spawn", { x = rng:float() * 100, y = rng:range(-50, 50), mass = rng:range(1, 10), label = "body" .. i })
    end
    local start = sim.tick
    t.frames(10)
    t.expect(sim.tick == start + 10, "one tick per frame")
    for _ = 1, 110 do
      sim.send("push", { dx = rng:float() * 4 })
      t.frames(1)
    end
    print("simulation state hash " .. sim.hash() .. " after tick " .. sim.tick)
    t.expect(sim.hash() == RECORDED_HASH, "the state hash differs from the recorded one")
  end,
}
