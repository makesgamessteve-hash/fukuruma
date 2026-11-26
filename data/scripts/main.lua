-- Fukuruma game entry point. The engine calls init() once, tick() at a fixed 60 Hz and draw(alpha) every frame.
-- M1: the placeholder Jump Ship is a simulation entity that spins in tick() and is drawn interpolated.
local mat4 = require("mat4")
local jump_ship = require("jump_ship")
local sim = require("fk.sim")

local game = {}

function game.init()
  game.mesh = fk.gfx.mesh(jump_ship.build())
  game.ship = sim.create()
  sim.set(game.ship, "spin", { angle = 0, previous = 0, speed = 0.5 })
end

function game.tick()
  for _, spin in sim.each("spin") do
    spin.previous = spin.angle
    spin.angle = spin.angle + spin.speed * sim.dt
  end
end

function game.transform(width, height, angle)
  local projection = mat4.perspective(math.rad(45), width / height, 0.1, 100)
  local view = mat4.multiply(mat4.translation(0, 0, -9), mat4.rotation_x(0.45))
  return mat4.multiply(projection, mat4.multiply(view, mat4.rotation_y(angle)))
end

function game.draw(alpha)
  local spin = sim.get(game.ship, "spin")
  fk.gfx.clear(0.02, 0.025, 0.06)
  local width, height = fk.gfx.size()
  fk.gfx.draw(game.mesh, game.transform(width, height, spin.previous + (spin.angle - spin.previous) * alpha))
end

return game
