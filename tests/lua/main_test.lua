local game = require("main")
local sim = require("fk.sim")

return {
  ["init creates the ship entity and its mesh"] = function()
    sim.reset()
    game.init()
    assert(game.mesh and sim.get(game.ship, "spin").angle == 0)
  end,
  ["tick turns the ship by a fixed step"] = function()
    sim.reset()
    game.init()
    sim.step(game)
    local spin = sim.get(game.ship, "spin")
    assert(spin.previous == 0 and math.abs(spin.angle - 0.5 / 60) < 1e-12)
  end,
  ["draw interpolates without a window"] = function()
    sim.reset()
    game.init()
    sim.step(game)
    game.draw(0.5)
  end,
  ["transform is a 4x4 matrix"] = function()
    assert(#game.transform(480, 270, 0) == 16)
  end,
}
