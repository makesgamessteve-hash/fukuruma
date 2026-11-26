-- scale_ladder.lua (reference-frames spec): the frame tree and each step's drawing.
local ladder = require("scale_ladder")
local sim = require("fk.sim")
local frames = require("fk.frames")

return {
  ["the ladder builds its frames and draws every step"] = function()
    sim.reset()
    local f = ladder.build()
    assert(frames.parent(f.ship) == f.planet and frames.parent(f.planet) == f.system)
    local p, q = frames.convert(f.ship, { 0, 0, 0 }, f.system), frames.convert(f.planet, { 0, 0, 0 }, f.system)
    local d = math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
    assert(math.abs(q[1] - ladder.AU * (1 - 0.0167)) < 1 and math.abs(d - ladder.PLANET_RADIUS - 3e5) < 1e-3,
      "the planet starts at its periapsis near 1 AU, the ship 300 km above it")
    ladder.update(60)
    for step = 1, #ladder.STEPS do ladder.draw(step, 16 / 9) end
    ladder.build() -- again: the meshes are kept
  end,
}
