-- Game feel (effects spec): feedback bundles for events, trauma-based camera shake, light flashes,
-- hit-pause and rumble. Presentation only: it reacts to simulation events and never changes them.
local comfort = require("settings.comfort")

local feel = { trauma = 0, time = 0, pause = 0, flashes = {} }

feel.MAX_SHAKE_ANGLE = 0.05 -- radians at full trauma
feel.MAX_SHAKE_OFFSET = 0.25 -- metres at full trauma

function feel.reset()
  feel.trauma, feel.time, feel.pause, feel.flashes = 0, 0, 0, {}
end

-- Adds trauma (0..1) from a source: it falls off with distance (full within `near` metres, none beyond
-- `far`) and with the mass of the doll the camera rides (a Walker's step barely moves a Land Explorer).
function feel.add_trauma(amount, source, listener, mass, near, far)
  local d = 0
  if source and listener then
    local dx, dy, dz = source[1] - listener[1], source[2] - listener[2], source[3] - listener[3]
    d = math.sqrt(dx * dx + dy * dy + dz * dz)
  end
  near, far = near or 10, far or 60
  local falloff = d <= near and 1 or math.max(0, 1 - (d - near) / (far - near))
  feel.trauma = math.min(1, feel.trauma + amount * falloff / math.max(1, mass or 1))
end

-- Advances the effects by dt (real seconds) and returns the presentation time step: 0 during hit-pause.
function feel.update(dt)
  feel.time = feel.time + dt
  feel.trauma = math.max(0, feel.trauma - dt * 1.2)
  local kept = {}
  for _, f in ipairs(feel.flashes) do
    f.age = f.age + dt
    if f.age < f.duration then kept[#kept + 1] = f end
  end
  feel.flashes = kept
  if feel.pause > 0 then
    feel.pause = math.max(0, feel.pause - dt)
    return 0
  end
  return dt
end

-- Smooth, deterministic noise in -1..1 for each shake axis.
local function noise(t, seed)
  return 0.6 * math.sin(t * 13.1 + seed) + 0.3 * math.sin(t * 27.7 + seed * 2.3) + 0.1 * math.sin(t * 51.3 + seed * 4.1)
end

-- The current shake: yaw, pitch, roll (radians) and x, y offsets (metres); trauma squared, scaled by comfort.
function feel.shake()
  local k = feel.trauma * feel.trauma * comfort.current.shake
  local t = feel.time
  return feel.MAX_SHAKE_ANGLE * k * noise(t, 1), feel.MAX_SHAKE_ANGLE * k * noise(t, 2), feel.MAX_SHAKE_ANGLE * k * noise(t, 3) * 0.5,
    feel.MAX_SHAKE_OFFSET * k * noise(t, 4), feel.MAX_SHAKE_OFFSET * k * noise(t, 5)
end

-- Draws the light flashes (fading point lights), dimmed by the comfort setting.
function feel.draw()
  local scale = comfort.current.flashes
  if scale <= 0 then return end
  for _, f in ipairs(feel.flashes) do
    local fade = 1 - f.age / f.duration
    fk.gfx.light({ position = f.position, color = f.color, intensity = f.intensity * fade * fade * scale, radius = f.radius })
  end
end

-- Plays a feedback bundle at a position with a strength (0..1, default 1). bundle fields (all optional):
-- particles = { emitter fields, or a list of them }, light = { color, intensity, radius, duration, offset },
-- trauma = amount, hitpause = seconds, rumble = { low, high, seconds }, sound = name.
-- listener = { position, mass }: the camera's doll, for the shake falloff.
function feel.play(bundle, position, strength, listener)
  strength = strength or 1
  position = position or { 0, 0, 0 }
  local particles = bundle.particles
  if particles then
    for _, e in ipairs(particles[1] and particles or { particles }) do
      local burst = {}
      for k, v in pairs(e) do burst[k] = v end
      burst.position = { position[1] + (e.offset and e.offset[1] or 0), position[2] + (e.offset and e.offset[2] or 0),
        position[3] + (e.offset and e.offset[3] or 0) }
      burst.offset = nil
      burst.count = math.max(1, math.floor((e.count or 1) * strength + 0.5))
      fk.gfx.emit(burst)
    end
  end
  local light = bundle.light
  if light then
    local o = light.offset or { 0, 0, 0 }
    feel.flashes[#feel.flashes + 1] = { position = { position[1] + o[1], position[2] + o[2], position[3] + o[3] },
      color = light.color, intensity = light.intensity * strength, radius = light.radius, duration = light.duration, age = 0 }
  end
  if bundle.trauma then
    feel.add_trauma(bundle.trauma * strength, position, listener and listener.position, listener and listener.mass)
  end
  if bundle.hitpause then feel.pause = math.max(feel.pause, bundle.hitpause) end
  if bundle.rumble and comfort.current.rumble then
    local r = bundle.rumble
    fk.input.rumble(math.min(1, r[1] * strength), math.min(1, r[2] * strength), r[3])
  end
  if bundle.sound and fk.audio then fk.audio.play(bundle.sound, { position = position, volume = strength }) end
end

-- Plays the table's bundle for every simulation event that has one; data.position and data.strength are used.
function feel.listen(sim, table_, listener)
  for name, bundle in pairs(table_) do
    sim.listen(name, function(data)
      feel.play(bundle, data and data.position, data and data.strength, listener and listener())
    end)
  end
end

return feel
