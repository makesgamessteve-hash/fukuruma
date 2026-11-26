-- scale_ladder.lua (reference-frames spec): the frame tree and each step's drawing.
local ladder = require("scale_ladder")
local sim = require("fk.sim")
local frames = require("fk.frames")

return {
  ["the ladder builds its frames and draws every step"] = function()
    sim.reset()
    local f = ladder.build()
    assert(frames.parent(f.ship) == f.planet and frames.parent(f.planet) == f.system)
    local p = frames.convert(f.ship, { 0, 0, 0 }, f.system)
    assert(p[1] == ladder.AU and p[3] > ladder.PLANET_RADIUS, "the ship orbits the planet at 1 AU")
    for step = 1, #ladder.STEPS do ladder.draw(step, 16 / 9) end
    ladder.build() -- again: the meshes are kept
  end,
}
