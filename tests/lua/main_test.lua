local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")

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
  ["input turns into a ship.control command"] = function()
    sim.reset()
    actions.reset()
    game.init()
    local real = fk.input
    fk.input = setmetatable({ key = function(k) return k == "D" end, device = function() return "keyboard" end },
      { __index = real })
    local ok, err = pcall(function()
      game.input()
      game.input() -- unchanged input sends nothing more
      sim.step(game)
    end)
    fk.input = real
    assert(ok, err)
    assert(sim.get(game.ship, "spin").speed == 2.0)
  end,
  ["camera gives view and projection matrices"] = function()
    local view, projection = game.camera(480, 270)
    assert(#view == 16 and #projection == 16)
  end,
}
