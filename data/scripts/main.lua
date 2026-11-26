-- Fukuruma game entry point. The engine calls init() once; then every frame input(), the due tick()s
-- (fixed 60 Hz) and draw(alpha).
-- M1: the placeholder Jump Ship is a simulation entity, turned with A/D, the arrow keys, the left stick
-- or the touch stick, and sped up with Space, the A button or the touch button.
local mat4 = require("mat4")
local jump_ship = require("jump_ship")
local sim = require("fk.sim")
local actions = require("fk.actions")
local touch_view = require("touch_view")

local game = {}

function game.init()
  game.mesh = fk.gfx.mesh(jump_ship.build())
  touch_view.init()
  game.ship = sim.create()
  sim.set(game.ship, "spin", { angle = 0, previous = 0, speed = 0.5 })
  sim.on("ship.control", function(args)
    sim.get(args.ship, "spin").speed = (0.5 + args.turn * 1.5) * (args.boost and 2 or 1)
  end)
  actions.define("turn", { kind = "axis", negative = { "A", "Left" }, positive = { "D", "Right" },
    gamepad = "leftx", touch = "stick_x" })
  actions.define("boost", { kind = "button", keys = { "Space" }, gamepad = { "a" }, touch = "boost" })
  actions.touch_button("boost", 0.85, 0.7, 0.1)
  game.control = { turn = 0, boost = false }
end

-- Input becomes commands; a command is sent only when an action changes.
function game.input()
  actions.update()
  local turn, boost = actions.value("turn"), actions.held("boost")
  if turn ~= game.control.turn or boost ~= game.control.boost then
    game.control = { turn = turn, boost = boost }
    sim.send("ship.control", { ship = game.ship, turn = turn, boost = boost })
  end
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
  touch_view.draw(actions.touch_controls())
end

return game
