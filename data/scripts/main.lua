-- Fukuruma game entry point. The engine calls init() once, then update(dt) and draw() every frame.
-- M0: a spinning placeholder Jump Ship.
local mat4 = require("mat4")
local jump_ship = require("jump_ship")

local game = { angle = 0 }

function game.init()
  game.mesh = fk.gfx.mesh(jump_ship.build())
end

function game.update(dt)
  game.angle = game.angle + dt * 0.5
end

function game.transform(width, height)
  local projection = mat4.perspective(math.rad(45), width / height, 0.1, 100)
  local view = mat4.multiply(mat4.translation(0, 0, -9), mat4.rotation_x(0.45))
  return mat4.multiply(projection, mat4.multiply(view, mat4.rotation_y(game.angle)))
end

function game.draw()
  fk.gfx.clear(0.02, 0.025, 0.06)
  fk.gfx.draw(game.mesh, game.transform(fk.gfx.size()))
end

return game
