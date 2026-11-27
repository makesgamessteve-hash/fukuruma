-- The sandbox, seen through the Commander's eyes from inside the Exosuit (3.6 m), on a lit test range with
-- wind, music and sound effects. Look with the mouse, the right stick or by dragging on the right half of a
-- touch screen; walk with WASD, the arrow keys, the left stick or the touch stick, towards where you look;
-- sprint with Shift, A or RUN; scan with E, X or SCAN. V, the gamepad's Back button or VIEW opens the survey
-- drone's outside view, which is for looking only. Escape, Start or MENU opens the settings; F5 saves, F9 loads.
-- The suit is a physics character: it climbs low steps, stops at walls and the beacon tower, and pushes the crates.
-- The range stands on a world of a generated star system; M, Y or MAP opens the galaxy and system maps, from which the
-- Jump Ship jumps the range to another star (the sky, the light and gravity follow).
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
local save = require("fk.save")
local tween = require("fk.tween")
local hud = require("hud")
local frames = require("fk.frames")
local universe = require("universe")
local navmap = require("navmap")
local terrain = require("terrain")

local game = {}

game.WALK, game.RUN = 2.6, 6.3 -- m/s, matched to the clips' strides
local ACCEL = 9                -- m/s^2 towards the wanted velocity
local GROUND_SIZE = 160
local SCAN_COOLDOWN = 120      -- ticks between scans
local EYE = { 0, 0.26, 0.22 }  -- the eyes behind the visor, from the head joint
local SUIT_RADIUS, SUIT_HEIGHT = 0.8, 3.6
local CRATES = { { -6, 5 }, { -4.6, 7.2 }, { 9, -4 } }
local CRATE_SIZE, CRATE_MASS = 1.6, 400 -- kg: the suit can push them

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
  game.helmet = camera.helmet({ fov = comfort.current.fov })
  game.drone = camera.orbit({ distance = 12, height = 2 })
  game.view = "helmet" -- or "drone": the outside view, for orientation only
  game.frame_dt = 1 / 60

  game.ground = fk.gfx.mesh(shapes.plane(GROUND_SIZE, { 1, 1, 1 }, 4))
  game.deck = fk.gfx.texture("textures/test_ground.jpg")
  game.ship = fk.gfx.mesh(jump_ship.build())
  game.crate = fk.gfx.mesh(shapes.box(1.6, 1.6, 1.6, { 0.55, 0.5, 0.42 }))
  game.pillar = fk.gfx.mesh(shapes.box(0.8, 6, 0.8, { 0.6, 0.6, 0.62 }))
  game.beacon = fk.gfx.mesh(shapes.sphere(0.35, 16, { 1, 0.7, 0.35 }))
  game.spheres = fk.gfx.model("models/showcase_materials.glb")
  touch_view.init()

  -- The physics world: the deck, the beacon tower, the crates and the suit; beyond the deck, the world's own ground
  -- (terrain.follow).
  game.world = fk.physics.world({ gravity = { 0, -9.81, 0 } })
  game.world:add({ shape = "box", size = { GROUND_SIZE, 1, GROUND_SIZE }, position = { 0, -0.5, 0 }, friction = 0.8 })
  game.ground_tile, game.ground_view = {}, {}
  game.world:add({ shape = "box", size = { 0.8, 6, 0.8 }, position = { 6, 3, 4 } })
  game.crates = {}
  for i, p in ipairs(CRATES) do
    local a = i * 0.35 -- half of the yaw i * 0.7
    game.crates[i] = game.world:add({ shape = "box", size = { CRATE_SIZE, CRATE_SIZE, CRATE_SIZE }, mass = CRATE_MASS,
      position = { p[1], CRATE_SIZE / 2, p[2] }, rotation = { 0, fk.math.sin(a), 0, fk.math.cos(a) }, friction = 0.6 })
  end
  local body = game.world:character({ radius = SUIT_RADIUS, height = SUIT_HEIGHT, position = { 0, SUIT_HEIGHT / 2, 0 },
    step = 0.5, slope = 40, push = 800 })
  sim.attach("physics", { state = function() return game.world:state() end, restore = function(data) game.world:restore(data) end })
  -- The range stands on a world of the current star system; its gravity is the world's.
  universe.install(function(g) game.world:gravity({ 0, -g, 0 }) end)
  game.sky_sphere = fk.gfx.mesh(shapes.sphere(1, 24, { 1, 1, 1 }))

  game.suit = sim.create()
  sim.set(game.suit, "suit", { x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0, fx = 0, fz = 1, wx = 0, wz = 0, lx = 0, lz = 1,
    scan_at = 0, body = body })
  sim.on("move", function(args) -- the wanted velocity and the direction the Commander looks
    local body = sim.get(game.suit, "suit")
    body.wx, body.wz, body.lx, body.lz = args.x, args.z, args.fx, args.fz
  end)
  sim.on("scan", function()
    local body = sim.get(game.suit, "suit")
    if sim.tick < body.scan_at then return end
    body.scan_at = sim.tick + SCAN_COOLDOWN
    sim.emit("scan", { position = { body.x, 0, body.z } })
  end)
  feel.listen(sim, { scan = feedback.scan, impact = feedback.impact, jump = feedback.jump }, function() return game.listener() end)
  sim.listen("jump", function() game.jump_fx = 0 end) -- the streaks and the flash (presentation)
  sim.listen("scan", function() -- a scan swells the discovery theme for a while
    music.play("discovery", 2)
    game.discovery_until = feel.time + 25
  end)

  actions.define("move_x", { kind = "axis", negative = { "A", "Left" }, positive = { "D", "Right" }, gamepad = "leftx", touch = "stick_x" })
  actions.define("move_y", { kind = "axis", negative = { "W", "Up" }, positive = { "S", "Down" }, gamepad = "lefty", touch = "stick_y" })
  actions.define("sprint", { kind = "button", keys = { "Left Shift", "Right Shift" }, gamepad = { "a" }, touch = "sprint" })
  actions.define("scan", { kind = "button", keys = { "E" }, gamepad = { "x" }, touch = "scan" })
  actions.define("look_x", { kind = "axis", gamepad = "rightx" })
  actions.define("look_y", { kind = "axis", gamepad = "righty" })
  actions.define("view", { kind = "button", keys = { "V" }, gamepad = { "back" }, touch = "view" })
  actions.define("menu", { kind = "button", keys = { "Escape" }, gamepad = { "start" }, touch = "menu" })
  actions.define("map", { kind = "button", keys = { "M" }, gamepad = { "y" }, touch = "map" })
  actions.define("save", { kind = "button", keys = { "F5" } })
  actions.define("load", { kind = "button", keys = { "F9" } })
  menu.actions = { save = function() game.save() end, load = function() game.load() end }
  actions.touch_button("sprint", 0.86, 0.72, 0.09)
  actions.touch_button("scan", 0.72, 0.84, 0.07)
  actions.touch_button("menu", 0.94, 0.1, 0.06)
  actions.touch_button("view", 0.94, 0.27, 0.05)
  actions.touch_button("map", 0.94, 0.42, 0.05)
  game.control = { x = 0, z = 0, fx = 0, fz = 1 }
end

function game.listener() return { position = game.suit_position(), mass = 1 } end

function game.suit_position()
  local body = sim.get(game.suit, "suit")
  return { body.x, body.y, body.z }
end

-- A short notice at the top of the screen ("Game saved"), fading out.
function game.notice(text)
  game.toast = { text = text, fade = tween.new(1, 0, 2.5, "cubic_in_out") }
  fk.audio.play("ui_confirm", { bus = "ui", volume = 0.7 })
end

-- Saves between ticks, so the snapshot is a whole tick.
function game.save()
  save.write("quick")
  game.notice("Game saved")
end

function game.load()
  if not save.read("quick") then return game.notice("No saved game yet") end
  local s = sim.get(game.suit, "suit")
  game.control = { x = s.wx, z = s.wz, fx = s.lx, fz = s.lz } -- the input compares against the loaded wish
  game.helmet.yaw, game.helmet.pitch = math.atan(s.lx, s.lz), 0  -- look where the loaded suit looked
  game.notice("Game loaded")
end

-- Turns the view (the helmet, or the drone in the outside view) by the mouse, the right stick or the look finger.
local function look()
  local w, h = fk.gfx.size()
  local dt = game.frame_dt
  local right = actions.value("look_x") * 2.6 * dt
  local up = -actions.value("look_y") * 2.0 * dt
  if game.captured then
    local _, _, mdx, mdy = fk.input.mouse()
    right, up = right + mdx * 3.0, up - mdy * 3.0 * h / w
  end
  local tdx, tdy = actions.touch_look()
  right, up = right + tdx * 4.0, up - tdy * 4.0 * h / w
  if game.view == "drone" then game.drone:look(right, up) else game.helmet:look(right, up, dt) end
end

-- Input becomes commands, only when something changes. Walking goes towards where the Commander looks.
-- The menu and the outside view hold the suit: they are for looking only.
function game.input()
  actions.update()
  if navmap.open then -- the maps take the controls; the suit holds still
    local target = navmap.update(game.frame_dt)
    if target then sim.send("jump", target) end
    if actions.pressed("map") and navmap.open then navmap.toggle() end
  elseif actions.pressed("menu") then menu.toggle()
  elseif actions.pressed("map") and not menu.open then navmap.toggle() end
  if actions.pressed("save") then game.save() end
  if actions.pressed("load") then game.load() end
  if actions.pressed("view") and not menu.open then
    game.view = game.view == "drone" and "helmet" or "drone"
    game.drone.yaw = game.helmet.yaw -- the drone starts behind the Commander, looking the same way
  end
  -- The mouse is captured once it is used, and stays captured for keyboard play; touch and the menu release it.
  local device = fk.input.device()
  local capture = not menu.open and device ~= "touch" and (device == "mouse" or game.captured == true)
  if capture ~= game.captured then
    fk.input.capture(capture)
    game.captured = capture
  end
  local busy = menu.open or navmap.open
  if not busy then look() end
  local x, y = actions.value("move_x"), actions.value("move_y")
  local len = math.sqrt(x * x + y * y)
  if len > 1 then x, y = x / len, y / len end
  local speed = actions.held("sprint") and game.RUN or game.WALK
  if busy or game.view == "drone" then x, y = 0, 0 end
  local forward, right = game.helmet:ground_axes()
  local wx, wz = (right[1] * x - forward[1] * y) * speed, (right[3] * x - forward[3] * y) * speed
  local fx, fz = math.floor(forward[1] * 1000 + 0.5) / 1000, math.floor(forward[3] * 1000 + 0.5) / 1000
  local c = game.control
  if wx ~= c.x or wz ~= c.z or fx ~= c.fx or fz ~= c.fz then
    game.control = { x = wx, z = wz, fx = fx, fz = fz }
    sim.send("move", { x = wx, z = wz, fx = fx, fz = fz })
  end
  if actions.pressed("scan") and not busy and game.view == "helmet" then sim.send("scan", {}) end
end

-- The suit accelerates towards the wanted velocity and turns to face where the Commander looks; the physics
-- character moves it (sliding along walls, climbing steps, pushing crates), so its velocity is what it really
-- made. Then the world steps, and new hard touches become impact events.
function game.tick()
  local dt = sim.dt
  local suit = sim.get(game.suit, "suit")
  terrain.follow(game.ground_tile, game.world, universe.ground(), suit.x, suit.z)
  for _, b in sim.each("suit") do
    local dx, dz = b.wx - b.vx, b.wz - b.vz
    local d = math.sqrt(dx * dx + dz * dz)
    local step = ACCEL * dt
    if d <= step then b.vx, b.vz = b.wx, b.wz
    else b.vx, b.vz = b.vx + dx / d * step, b.vz + dz / d * step end
    b.vy = b.vy + game.world:gravity()[2] * dt
    local p, grounded = game.world:move(b.body, { b.vx * dt, b.vy * dt, b.vz * dt }, dt)
    b.vx, b.vz = (p[1] - b.x) / dt, (p[3] - b.z) / dt
    if grounded then b.vy = 0 end
    b.x, b.y, b.z = p[1], p[2] - SUIT_HEIGHT / 2, p[3]
    local fx, fz = b.fx + (b.lx - b.fx) * 0.2, b.fz + (b.lz - b.fz) * 0.2
    local f = math.sqrt(fx * fx + fz * fz)
    if f > 1e-6 then b.fx, b.fz = fx / f, fz / f end
  end
  for _, hit in ipairs(game.world:step(dt, 150)) do
    sim.emit("impact", { position = hit.point, strength = math.min(1, hit.impulse / 1500) })
  end
end

-- Where the suit is drawn: between the last two ticks (alpha), facing its direction.
local function suit_matrix(body, alpha)
  return mat4.multiply(mat4.translation(body.x + body.vx * sim.dt * (alpha - 1), body.y, body.z + body.vz * sim.dt * (alpha - 1)),
    mat4.rotation_y(math.atan(body.fx, body.fz)))
end

-- The suit: animation from its speed, footstep effects at the feet, the antenna on a spring. Seen from inside,
-- its head is hidden (scaled to nothing), so the Commander sees the suit's shoulders, arms and chest.
-- Returns the model matrix and the speed.
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
  local head = game.pose:global("head")
  if game.view == "helmet" then game.pose:scale("head", 0) end
  fk.gfx.draw(game.suit_model, model, { pose = game.pose })
  return model, speed, head
end

-- The eyes: in the animated head, with the head bob scaled by the comfort setting.
local function eye_position(model, head)
  local hx, hy, hz = mat4.apply(head, EYE[1], EYE[2], EYE[3])
  local ax, ay, az = mat4.apply(model, hx, hy, hz)
  local sx, sy, sz = mat4.apply(model, EYE[1], 3.1 + EYE[2], EYE[3]) -- the same point with the head at rest
  local k = comfort.current.head_bob
  return { sx + (ax - sx) * k, sy + (ay - sy) * k, sz + (az - sz) * k }
end

-- The sky over the range: the real star of the current system, the world's air, its other bodies and the stars.
local function draw_sky()
  local t = sim.tick * sim.dt
  local light = universe.light(t)
  local b = light.background
  fk.gfx.clear(b[1], b[2], b[3])
  if light.atmosphere then fk.gfx.atmosphere(light.atmosphere) end
  if light.sun.intensity > 0 then fk.gfx.sun(light.sun) else fk.gfx.sun({ direction = { 0, 1, 0 }, intensity = 0 }) end
  fk.gfx.ambient({ sky = light.ambient.sky, ground = light.ambient.ground, intensity = 1 })
  fk.gfx.sky(universe.view().map, { strength = light.stars, rotation = light.galaxy_rotation })
  if light.sun2 then fk.gfx.sun2(light.sun2) end
  local _, h = fk.gfx.size()
  universe.draw_sky(t, game.sky_sphere, light, h / (2 * math.tan(math.rad(comfort.current.fov) / 2)))
end

local function draw_stage(dt)
  draw_sky()
  fk.gfx.grade({ exposure = -0.6, contrast = 1.1, saturation = 1.1 })
  fk.gfx.light({ position = { 6, 5.8, 4 }, color = { 1, 0.62, 0.3 }, intensity = 22, radius = 14 })
  fk.gfx.draw(game.ground, mat4.identity(), { texture = game.deck, roughness = 0.9 })
  for _, id in ipairs(game.crates) do
    local c = game.world:get(id)
    fk.gfx.draw(game.crate, frames.matrix(c.rotation, c.position, 1), { roughness = 0.8 })
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
  game.frame_dt = dt > 0 and dt or game.frame_dt
  local pdt = feel.update(dt) -- presentation time: 0 during hit-pause
  fk.gfx.particles(pdt)
  local body = sim.get(game.suit, "suit")
  draw_stage(pdt)
  local model, speed, head = draw_suit(body, alpha, pdt)
  local w, h = fk.gfx.size()
  local view, projection
  if game.view == "drone" then
    view, projection = game.drone:matrices({ model[13], model[14], model[15] }, w / h)
  else
    game.helmet.fov = comfort.current.fov
    view, projection = game.helmet:matrices(eye_position(model, head), w / h, { feel.shake() })
  end
  fk.gfx.camera(view, projection)
  local inv_x, inv_y, inv_z = -(view[1] * view[13] + view[2] * view[14] + view[3] * view[15]),
    -(view[5] * view[13] + view[6] * view[14] + view[7] * view[15]), -(view[9] * view[13] + view[10] * view[14] + view[11] * view[15])
  local half_fov = math.rad(game.view == "drone" and game.drone.fov or comfort.current.fov) / 2
  terrain.draw(game.ground_view, universe.ground(), { inv_x, inv_y, inv_z }, { -view[3], -view[7], -view[11] },
    math.atan(math.tan(half_fov) * math.sqrt(1 + (w / h) ^ 2)), h / (2 * math.tan(half_fov)))
  fk.audio.listener({ position = { inv_x, inv_y, inv_z }, right = { view[1], view[5], view[9] } })
  reverb.update(game.suit_position())
  if music.current == "discovery" and feel.time > game.discovery_until then music.play("surface", 6) end
  feel.draw()
  if game.view == "drone" then hud.drone(feel.time)
  else
    hud.visor({ yaw = game.helmet.yaw, speed = speed, turn_rate = game.helmet.turn_rate, vignette = comfort.current.vignette,
      scan = math.max(0, math.min(1, 1 - (body.scan_at - sim.tick) / SCAN_COOLDOWN)) })
  end
  if game.jump_fx then -- streaks racing out of the centre, then a flash that hides the arrival
    game.jump_fx = game.jump_fx + dt
    local k = game.jump_fx
    if k < 0.8 then
      for i = 1, 40 do
        local a, r = i * 2.399963, (i * 37 % 100) / 100
        local len = (k / 0.8) * (20 + r * 60)
        local x0, y0 = w / 2 + fk.math.cos(a) * (10 + r * w * k), h / 2 + fk.math.sin(a) * (10 + r * h * k)
        fk.gfx.rect(math.floor(x0), math.floor(y0), math.max(1, math.floor(math.abs(fk.math.cos(a)) * len)), 1, { 0.8, 0.9, 1, 0.8 })
      end
    end
    local flash = k < 0.5 and k / 0.5 or math.max(0, 1 - (k - 0.5) / 1.0)
    fk.gfx.rect(0, 0, w, h, { 0.9, 0.95, 1, flash })
    if k > 1.5 then game.jump_fx = nil end
  end
  navmap.draw(feel.time)
  touch_view.draw(actions.touch_controls())
  if game.toast then
    local a = game.toast.fade:update(dt)
    fk.gfx.text(math.floor(w / 2 - #game.toast.text * 4), 34, game.toast.text, { 1, 0.85, 0.5, a })
    if game.toast.fade:done() then game.toast = nil end
  end
  menu.draw(game.graphics, dt)
end

-- Fukuruma game entry point. The engine calls init() once; then every frame input(), the due tick()s
-- (fixed 60 Hz) and draw(alpha, dt).

return game
