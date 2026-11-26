-- Fukuruma game entry point. The engine calls init() once; then every frame input(), the due tick()s
-- (fixed 60 Hz) and draw(alpha, dt).
-- M1 sandbox: the Exosuit (3.6 m) walks and runs over a lit test range, with wind, music and sound effects. Move with WASD, the arrow keys, the
-- left stick or the touch stick; sprint with Shift, the A button or the touch button; scan with E, the X
-- button or the scan button. Escape, Start or the touch button at the top right opens the settings.
-- Simulation (sim.*) uses only arithmetic and sqrt, so it is the same on every platform; animation, camera
-- and effects are presentation.
local mat4 = require("mat4")
local jump_ship = require("jump_ship")
local sim = require("fk.sim")
local actions = require("fk.actions")
local anim = require("fk.anim")
local spring = require("fk.spring")
local camera = require("fk.camera")
local feel = require("fk.feel")
local touch_view = require("touch_view")
local shapes = require("shapes")
local graphics = require("settings.graphics")
local comfort = require("settings.comfort")
local audio = require("settings.audio")
local music = require("fk.music")
local reverb = require("fk.reverb")
local menu = require("menu")
local feedback = require("feedback")

local game = {}

game.WALK, game.RUN = 2.6, 6.3 -- m/s, matched to the clips' strides
local ACCEL = 9                -- m/s^2 towards the wanted velocity
local GROUND_SIZE = 160

function game.init()
  game.graphics = graphics.load(fk.gfx.device())
  graphics.apply(game.graphics)
  comfort.load()
  audio.load()
  feel.reset()
  music.load({ surface = "music/surface.ogg", discovery = "music/discovery.ogg" })
  music.play("surface", 4)
  game.wind = fk.audio.play("wind_loop", { loop = true, bus = "ambient", volume = 0.45 })
  reverb.clear()
  reverb.zone({ center = { 6, 3, 4 }, radius = 7, room = 0.85, damping = 0.3, wet = 0.35 }) -- the beacon tower rings

  game.suit_model = fk.gfx.model("models/exosuit.glb")
  game.pose = fk.anim.pose(game.suit_model)
  local locomotion = anim.blend1d(game.suit_model, {
    { clip = "idle", at = 0 },
    { clip = "walk", at = game.WALK, events = { { at = 0.25, name = "foot_l" }, { at = 0.75, name = "foot_r" } } },
    { clip = "run", at = game.RUN, events = { { at = 0.25, name = "foot_l" }, { at = 0.75, name = "foot_r" } } },
  }, "speed")
  game.machine = anim.machine({ model = game.suit_model, start = "move", states = { move = { tree = locomotion } } })
  game.antenna = spring.new(2.2, 0.25)
  game.rig = camera.chase({ distance = 9, height = 4.2, look_height = 2.2, mass = 1, fov = 50 })

  game.ground = fk.gfx.mesh(shapes.plane(GROUND_SIZE, { 1, 1, 1 }, 4))
  game.deck = fk.gfx.texture("textures/test_ground.jpg")
  game.ship = fk.gfx.mesh(jump_ship.build())
  game.crate = fk.gfx.mesh(shapes.box(1.6, 1.6, 1.6, { 0.55, 0.5, 0.42 }))
  game.pillar = fk.gfx.mesh(shapes.box(0.8, 6, 0.8, { 0.6, 0.6, 0.62 }))
  game.beacon = fk.gfx.mesh(shapes.sphere(0.35, 16, { 1, 0.7, 0.35 }))
  game.spheres = fk.gfx.model("models/showcase_materials.glb")
  touch_view.init()

  game.suit = sim.create()
  sim.set(game.suit, "suit", { x = 0, z = 0, vx = 0, vz = 0, fx = 0, fz = 1, wx = 0, wz = 0 })
  sim.on("move", function(args)
    local body = sim.get(game.suit, "suit")
    body.wx, body.wz = args.x, args.z
  end)
  sim.on("scan", function()
    local body = sim.get(game.suit, "suit")
    sim.emit("scan", { position = { body.x, 0, body.z } })
  end)
  feel.listen(sim, { scan = feedback.scan }, function() return game.listener() end)
  sim.listen("scan", function() -- a scan swells the discovery theme for a while
    music.play("discovery", 2)
    game.discovery_until = feel.time + 25
  end)

  actions.define("move_x", { kind = "axis", negative = { "A", "Left" }, positive = { "D", "Right" }, gamepad = "leftx", touch = "stick_x" })
  actions.define("move_y", { kind = "axis", negative = { "W", "Up" }, positive = { "S", "Down" }, gamepad = "lefty", touch = "stick_y" })
  actions.define("sprint", { kind = "button", keys = { "Left Shift", "Right Shift" }, gamepad = { "a" }, touch = "sprint" })
  actions.define("scan", { kind = "button", keys = { "E" }, gamepad = { "x" }, touch = "scan" })
  actions.define("menu", { kind = "button", keys = { "Escape" }, gamepad = { "start" }, touch = "menu" })
  actions.touch_button("sprint", 0.86, 0.72, 0.09)
  actions.touch_button("scan", 0.72, 0.84, 0.07)
  actions.touch_button("menu", 0.94, 0.1, 0.06)
  game.control = { x = 0, z = 0 }
end

function game.listener() return { position = game.suit_position(), mass = 1 } end

function game.suit_position()
  local body = sim.get(game.suit, "suit")
  return { body.x, 0, body.z }
end

-- Input becomes commands, only when something changes. The camera looks along +z, so up on the stick is +z
-- and right is -x. The menu pauses the controls.
function game.input()
  actions.update()
  if actions.pressed("menu") then menu.toggle() end
  local x, y = actions.value("move_x"), actions.value("move_y")
  local len = math.sqrt(x * x + y * y)
  if len > 1 then x, y = x / len, y / len end
  local speed = actions.held("sprint") and game.RUN or game.WALK
  if menu.open then x, y = 0, 0 end
  local wx, wz = -x * speed, -y * speed
  if wx ~= game.control.x or wz ~= game.control.z then
    game.control = { x = wx, z = wz }
    sim.send("move", { x = wx, z = wz })
  end
  if actions.pressed("scan") and not menu.open then sim.send("scan", {}) end
end

-- The suit accelerates towards the wanted velocity and turns to face where it goes.
function game.tick()
  for _, b in sim.each("suit") do
    local dx, dz = b.wx - b.vx, b.wz - b.vz
    local d = math.sqrt(dx * dx + dz * dz)
    local step = ACCEL * sim.dt
    if d <= step then b.vx, b.vz = b.wx, b.wz
    else b.vx, b.vz = b.vx + dx / d * step, b.vz + dz / d * step end
    local half = GROUND_SIZE / 2 - 2
    b.x = math.max(-half, math.min(half, b.x + b.vx * sim.dt))
    b.z = math.max(-half, math.min(half, b.z + b.vz * sim.dt))
    local v = math.sqrt(b.vx * b.vx + b.vz * b.vz)
    if v > 0.1 then
      local fx, fz = b.fx + (b.vx / v - b.fx) * 0.15, b.fz + (b.vz / v - b.fz) * 0.15
      local f = math.sqrt(fx * fx + fz * fz)
      if f > 1e-6 then b.fx, b.fz = fx / f, fz / f end
    end
  end
end

-- Where the suit is drawn: between the last two ticks (alpha), facing its direction.
local function suit_matrix(body, alpha)
  return mat4.multiply(mat4.translation(body.x + body.vx * sim.dt * (alpha - 1), 0, body.z + body.vz * sim.dt * (alpha - 1)),
    mat4.rotation_y(math.atan(body.fx, body.fz)))
end

-- The suit: animation from its speed, footstep effects at the feet, the antenna on a spring.
local function draw_suit(body, alpha, dt)
  local speed = math.sqrt(body.vx * body.vx + body.vz * body.vz)
  local model = suit_matrix(body, alpha)
  for _, event in ipairs(game.machine:update(dt, { speed = speed })) do
    local foot = game.pose:global(event == "foot_l" and "foot_l" or "foot_r")
    local x, _, z = mat4.apply(model, foot[13], foot[14], foot[15])
    feel.play(feedback.footstep, { x, 0.05, z }, math.min(1, 0.35 + speed / game.RUN), game.listener())
  end
  game.machine:apply(game.pose)
  local sway = game.antenna:update(-speed * 0.06, dt)
  game.pose:rotate("antenna", { 1, 0, 0 }, sway)
  fk.gfx.draw(game.suit_model, model, { pose = game.pose })
end

local function draw_stage(dt)
  fk.gfx.clear(0.13, 0.17, 0.3) -- dusk sky
  fk.gfx.sun({ direction = { 0.55, 0.45, -0.7 }, color = { 1, 0.78, 0.55 }, intensity = 5 }) -- low, behind the camera
  fk.gfx.ambient({ sky = { 0.35, 0.45, 0.7 }, ground = { 0.28, 0.22, 0.16 }, intensity = 0.5 })
  fk.gfx.grade({ exposure = -0.6, contrast = 1.1, saturation = 1.1 })
  fk.gfx.light({ position = { 6, 5.8, 4 }, color = { 1, 0.62, 0.3 }, intensity = 22, radius = 14 })
  fk.gfx.draw(game.ground, mat4.identity(), { texture = game.deck, roughness = 0.9 })
  for i, p in ipairs({ { -6, 5 }, { -4.6, 7.2 }, { 9, -4 } }) do
    fk.gfx.draw(game.crate, mat4.multiply(mat4.translation(p[1], 0.8, p[2]), mat4.rotation_y(i * 0.7)), { roughness = 0.8 })
  end
  fk.gfx.draw(game.pillar, mat4.translation(6, 3, 4), { roughness = 0.5, metalness = 0.3 })
  fk.gfx.draw(game.beacon, mat4.translation(6, 6.35, 4), { emission = { 8, 4, 1.2 } })
  fk.gfx.draw(game.spheres, mat4.translation(-7, 0, 12))
  game.ship_angle = (game.ship_angle or 0) + dt * 0.3
  fk.gfx.draw(game.ship, mat4.multiply(mat4.translation(-30, 20, 95), mat4.multiply(mat4.rotation_y(game.ship_angle),
    mat4.multiply(mat4.rotation_x(0.15), { 4, 0, 0, 0, 0, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0, 1 }))), { roughness = 0.35, metalness = 0.6 })
end

function game.draw(alpha, dt)
  dt = dt or 0
  local pdt = feel.update(dt) -- presentation time: 0 during hit-pause
  fk.gfx.particles(pdt)
  local body = sim.get(game.suit, "suit")
  draw_stage(pdt)
  draw_suit(body, alpha, pdt)
  local w, h = fk.gfx.size()
  game.rig:update(dt, game.suit_position(), 0, { body.vx, 0, body.vz })
  local view, projection = game.rig:matrices(w / h, { feel.shake() })
  fk.gfx.camera(view, projection)
  local eye = game.rig:eye()
  fk.audio.listener({ position = eye, right = { view[1], view[5], view[9] } })
  reverb.update(game.suit_position())
  if music.current == "discovery" and feel.time > game.discovery_until then music.play("surface", 6) end
  feel.draw()
  touch_view.draw(actions.touch_controls())
  menu.draw(game.graphics, dt)
end

return game
