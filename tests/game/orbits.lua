-- orbital-mechanics spec: bodies on Kepler orbits move with the simulation, come back after one period, and
-- their positions are the same on every platform (the recorded state hash).
local sim = require("fk.sim")
local frames = require("fk.frames")
local ladder = require("scale_ladder")

local RECORDED_HASH = "db558a86454400c1"

return scenario {
  seed = 1,
  timeout_s = 20,
  run = function(t)
    sim.reset()
    local f = ladder.build()
    local start = frames.convert(f.ship, { 0, 0, 0 }, f.planet)
    local period = fk.orbit.period(sim.get(f.ship, "orbit"))
    t.expect(math.abs(period - 5423) < 1, "the ship goes round in about 90 minutes")
    for step = 1, 600 do ladder.update(step * period / 600) end -- one period in 600 steps
    local p = frames.convert(f.ship, { 0, 0, 0 }, f.planet)
    t.expect(math.abs(p[1] - start[1]) + math.abs(p[3] - start[3]) < 1e4, "the ship is back after one period")
    ladder.update(period)
    p = frames.convert(f.ship, { 0, 0, 0 }, f.planet)
    t.expect(math.abs(p[1] - start[1]) + math.abs(p[3] - start[3]) < 1e-3, "exactly back after one period")
    ladder.update(ladder.DAY * 0.25)
    local q = sim.get(f.surface, "frame").q
    t.expect(math.abs(q[4] - math.cos(math.pi / 4)) < 1e-12, "the planet turned a quarter in a quarter day")
    ladder.update(3.15e7) -- a year later
    print("orbit state hash " .. sim.hash())
    t.expect(sim.hash() == RECORDED_HASH, "the orbit state hash differs from the recorded one")
  end,
}
