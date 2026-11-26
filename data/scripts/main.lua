-- Fukuruma game entry point. The engine calls init() once; then every frame input(), the due tick()s
-- (fixed 60 Hz) and draw(alpha).
-- M1: a lit stage at dusk. The placeholder Jump Ship hovers over the ground and is a simulation entity,
-- turned with A/D, the arrow keys, the left stick or the touch stick, and sped up with Space, the A button
-- or the touch button.
local mat4 = require("mat4")
local jump_ship = require("jump_ship")
local sim = require("fk.sim")
local actions = require("fk.actions")
local touch_view = require("touch_view")
local shapes = require("shapes")

local game = {}

function game.init()
  game.mesh = fk.gfx.mesh(jump_ship.build())
  game.ground = fk.gfx.mesh(shapes.plane(240, { 0.34, 0.3, 0.26 }))
  game.crate = fk.gfx.mesh(shapes.box(1, 1, 1, { 0.55, 0.5, 0.42 }))
  game.pillar = fk.gfx.mesh(shapes.box(0.5, 2.4, 0.5, { 0.6, 0.6, 0.62 }))
  game.beacon = fk.gfx.mesh(shapes.sphere(0.22, 16, { 1, 0.7, 0.35 }))
  game.orb = fk.gfx.mesh(shapes.sphere(0.6, 24, { 0.85, 0.75, 0.55 }))
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

local GROUND_Y = -1.6

function game.camera(width, height)
  local projection = mat4.perspective(math.rad(45), width / height, 0.1, 100)
  local view = mat4.multiply(mat4.translation(0, -0.2, -11), mat4.rotation_x(0.38))
  return view, projection
end

function game.draw(alpha)
  local spin = sim.get(game.ship, "spin")
  local angle = spin.previous + (spin.angle - spin.previous) * alpha
  fk.gfx.camera(game.camera(fk.gfx.size()))
  fk.gfx.clear(0.13, 0.17, 0.3) -- dusk sky
  fk.gfx.sun({ direction = { -0.7, 0.42, 0.35 }, color = { 1, 0.78, 0.55 }, intensity = 5 })
  fk.gfx.ambient({ sky = { 0.35, 0.45, 0.7 }, ground = { 0.28, 0.22, 0.16 }, intensity = 0.5 })
  fk.gfx.grade({ exposure = -0.6, contrast = 1.1, saturation = 1.1 })
  fk.gfx.light({ position = { 3.2, GROUND_Y + 2.8, 1.2 }, color = { 1, 0.62, 0.3 }, intensity = 14, radius = 9 })

  fk.gfx.draw(game.ground, mat4.translation(0, GROUND_Y, 0), { roughness = 0.95 })
  fk.gfx.draw(game.crate, mat4.translation(-2.6, GROUND_Y + 0.5, 1.4), { roughness = 0.8 })
  fk.gfx.draw(game.crate, mat4.multiply(mat4.translation(-1.7, GROUND_Y + 0.5, 2.2), mat4.rotation_y(0.6)), { roughness = 0.8 })
  fk.gfx.draw(game.pillar, mat4.translation(3.2, GROUND_Y + 1.2, 1.2), { roughness = 0.5, metalness = 0.3 })
  fk.gfx.draw(game.beacon, mat4.translation(3.2, GROUND_Y + 2.62, 1.2), { emission = { 8, 4, 1.2 } })
  fk.gfx.draw(game.orb, mat4.translation(2.2, GROUND_Y + 0.6, 3.0), { roughness = 0.15, metalness = 1 })
  fk.gfx.draw(game.mesh, mat4.multiply(mat4.translation(0, 0.9, 0), mat4.rotation_y(angle)), { roughness = 0.35, metalness = 0.6 })
  touch_view.draw(actions.touch_controls())
end

return game
