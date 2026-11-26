local game = require("main")

return {
  ["init creates the mesh"] = function()
    game.init()
    assert(game.mesh)
  end,
  ["update turns the ship"] = function()
    local before = game.angle
    game.update(0.5)
    assert(game.angle > before)
  end,
  ["draw runs without a window"] = function()
    game.init()
    game.draw()
  end,
  ["transform is a 4x4 matrix"] = function()
    assert(#game.transform(480, 270) == 16)
  end,
}
