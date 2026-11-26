-- fk/feel.lua, fk/camera.lua, fk/tween.lua and settings/comfort.lua (effects spec).
local feel = require("fk.feel")
local camera = require("fk.camera")
local tween = require("fk.tween")
local comfort = require("settings.comfort")
local sim = require("fk.sim")
local mat4 = require("mat4")

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

return {
  ["trauma falls off with distance and mass and decays"] = function()
    feel.reset()
    feel.add_trauma(0.5, { 0, 0, 0 }, { 5, 0, 0 }, 1)
    assert(near(feel.trauma, 0.5), "within 10 m: full")
    feel.reset()
    feel.add_trauma(0.5, { 0, 0, 0 }, { 35, 0, 0 }, 1)
    assert(near(feel.trauma, 0.25), "halfway between 10 and 60 m: half")
    feel.reset()
    feel.add_trauma(0.5, { 0, 0, 0 }, { 0, 0, 0 }, 5)
    assert(near(feel.trauma, 0.1), "a heavier doll shakes less")
    feel.add_trauma(5)
    assert(feel.trauma == 1, "at most 1")
    feel.update(0.5)
    assert(near(feel.trauma, 0.4), "decays by 1.2 per second")
  end,
  ["shake follows trauma squared and the comfort setting"] = function()
    feel.reset()
    assert(select(1, feel.shake()) == 0, "no trauma: no shake")
    feel.trauma = 1
    feel.update(0.3)
    local yaw, pitch, roll, x, y = feel.shake()
    assert(yaw ~= 0 and pitch ~= 0 and roll ~= 0 and x ~= 0 and y ~= 0)
    comfort.current.shake = 0.5
    assert(near(select(1, feel.shake()), yaw * 0.5), "half shake")
    comfort.current.shake = 1
  end,
  ["bundles emit particles, flash, pause, rumble and shake"] = function()
    feel.reset()
    for _ = 1, 61 do fk.gfx.particles(1) end -- let old particles die
    local bundle = { particles = { { count = 10, offset = { 0, 1, 0 } }, { count = 4 } }, trauma = 0.5, hitpause = 0.1,
      rumble = { 0.5, 0.5, 0.1 }, light = { color = { 1, 1, 1 }, intensity = 10, radius = 5, duration = 0.5 }, sound = "scan" }
    feel.play(bundle, { 1, 0, 1 }, 0.5, { position = { 1, 0, 1 }, mass = 1 })
    assert(fk.gfx.particles(0) == 7, "counts scale with strength: 5 + 2")
    assert(#feel.flashes == 1 and near(feel.trauma, 0.25))
    feel.draw()
    assert(feel.update(0.05) == 0 and feel.update(0.06) == 0 and feel.update(0.01) == 0.01, "hit-pause holds time, then releases")
    feel.update(1)
    assert(#feel.flashes == 0, "the flash is over")
    comfort.current.flashes, comfort.current.rumble = 0, false
    feel.play({ particles = { count = 1 }, rumble = { 1, 1, 1 } })
    feel.play(bundle)
    feel.draw()
    comfort.current.flashes, comfort.current.rumble = 1, true
  end,
  ["simulation events play their bundles"] = function()
    sim.reset()
    feel.reset()
    feel.listen(sim, { boom = { trauma = 0.4 } }, function() return { position = { 0, 0, 0 }, mass = 1 } end)
    sim.emit("boom", { position = { 0, 0, 0 } })
    sim.step({})
    assert(near(feel.trauma, 0.4))
    feel.listen(sim, { quiet = { trauma = 0.1 } })
    sim.emit("quiet")
    sim.step({})
    assert(near(feel.trauma, 0.5))
  end,
  ["the helmet looks around, clamps its pitch and measures its turn rate"] = function()
    local helmet = camera.helmet({ fov = 80, max_pitch = 1 })
    local f = helmet:forward()
    assert(near(f[3], 1) and near(f[1], 0), "starts looking along +z")
    helmet:look(math.pi / 2, 0, 0.5)
    f = helmet:forward()
    assert(near(f[1], -1, 1e-6), "looking right turns towards -x")
    assert(near(helmet.turn_rate, math.pi), "turn rate in radians per second")
    helmet:look(0, 5, 0)
    assert(helmet.pitch == 1 and helmet.turn_rate == 0, "the pitch stops at max_pitch")
    local forward, right = helmet:ground_axes()
    assert(near(forward[1], -1, 1e-6) and forward[2] == 0 and near(right[3], -1, 1e-6), "flat axes for walking")
    local view, projection = helmet:matrices({ 0, 3, 0 }, 16 / 9, { 0, 0, 0, 0, 0 })
    assert(#view == 16 and #projection == 16)
  end,
  ["the drone orbits its target above the ground"] = function()
    local drone = camera.orbit({ distance = 10, height = 2, pitch = 0 })
    drone:look(0, -1)
    assert(drone.pitch == 0.05, "never below the ground")
    drone:look(0, 5)
    assert(drone.pitch == 1.3, "nor straight down")
    drone = camera.orbit({ distance = 10, height = 2, pitch = 0.05 })
    local eye = drone:eye({ 0, 0, 0 })
    assert(eye[3] < -9.9 and eye[2] > 2, "behind and above the target")
    local view = drone:matrices({ 0, 0, 0 }, 1)
    local _, _, z = mat4.apply(view, 0, 2, 0)
    assert(z < -9.9, "the target is in front")
  end,
  ["look_at puts the target in front"] = function()
    local view = camera.look_at({ 0, 2, -5 }, { 0, 2, 0 })
    local _, _, z = mat4.apply(view, 0, 2, 0)
    assert(near(z, -5, 1e-6), "the target is 5 m in front (negative z in view space)")
    local x = mat4.apply(view, -1, 2, 0)
    assert(x > 0, "-x is on the right when looking along +z")
  end,
  ["tweens ease from one value to another"] = function()
    local t = tween.new(0, 10, 1)
    assert(near(t:update(0.5), 7.5), "quad out: 3/4 at half time")
    assert(t:update(1) == 10 and t:done())
    local pop = tween.new(0, 1, 1, "back_out")
    pop:update(0.6)
    assert(pop:value() > 1, "back out overshoots")
    for _, name in ipairs({ "linear", "cubic_in_out", "elastic_out" }) do
      local e = tween.new(0, 1, 1, name)
      assert(e:value() == 0 and e:update(0.3) and e:update(0.3) and near(e:update(1), 1), name)
    end
    assert(tween.new(0, 1, 0):value() == 1, "zero duration: at the end")
    local ok = pcall(tween.new, 0, 1, 1, "wobble")
    assert(not ok)
  end,
  ["comfort settings are stored"] = function()
    comfort.load()
    comfort.current.shake = 0.5
    comfort.save()
    comfort.current = comfort.defaults()
    assert(comfort.load().shake == 0.5)
    comfort.current = comfort.defaults()
    comfort.save()
  end,
}
