-- Weather (weather spec). A world's weather comes in spells: each spell's kind follows from a hash of the world and the
-- spell's number, so the same world at the same time always has the same weather, and each spell rises and falls
-- again. Worlds with seas get rain and thunderstorms, cold worlds snow, dry worlds sandstorms; worlds without air
-- have none. Presentation only: it turns into the ground's layers (wet, snow, dust), the clouds, fog, falling
-- particles around the eye, lightning and sound.
local weather = {}

weather.SPELL = 480  -- seconds a spell lasts
weather.RANGE = 14   -- metres around the eye where rain and snow fall

local function hash(a, b)
  local h = (a * 73856093) ~ (b * 19349663)
  h = (h ~ (h >> 13)) * 1274126177
  h = h ~ (h >> 16)
  return h & 0x7fffffff
end

-- The kinds of weather a world can have. air: its atmosphere (or nil); cold: its ground freezes.
function weather.kinds(desc, air, cold)
  if not air then return { "clear" } end
  if cold then return { "clear", "snow", "snow" } end
  if desc.ocean then return { "clear", "clear", "rain", "storm" } end
  return { "clear", "sandstorm" }
end

-- The weather at presentation time t (seconds) for a world (seed, kinds): kind and strength (0..1).
function weather.at(seed, kinds, t)
  local spell = math.floor(t / weather.SPELL)
  local kind = kinds[hash(seed % 0x7fffffff, spell) % #kinds + 1]
  local phase = (t - spell * weather.SPELL) / weather.SPELL
  local rise, fall = math.min(1, phase / 0.15), math.min(1, (1 - phase) / 0.15)
  local s = math.min(rise, fall)
  return kind, kind == "clear" and 0 or s * s * (3 - 2 * s)
end

-- What a kind of weather does at a strength: ground layers, extra cloud cover, fog.
function weather.look(kind, strength)
  local k = strength
  if kind == "rain" or kind == "storm" then
    return { wet = k, cover = (kind == "storm" and 0.35 or 0.25) * k, fog = { density = 0.0006 * k, height = 300 } }
  elseif kind == "snow" then
    return { snow = k, cover = 0.25 * k, fog = { density = 0.0008 * k, height = 250 } }
  elseif kind == "sandstorm" then
    return { dust = k, cover = 0, fog = { density = 0.004 * k, height = 400 } }
  end
  return { cover = 0 }
end

local FALL = {
  rain = { per_second = 5000, speed = 19, size = 0.025, gravity = 2, color = { 0.8, 0.85, 0.92 }, alpha = 0.5, life = 1.1, stretch = 0.035 },
  storm = { per_second = 7000, speed = 24, size = 0.025, gravity = 2, color = { 0.75, 0.8, 0.88 }, alpha = 0.55, life = 1, stretch = 0.035 },
  snow = { per_second = 1800, speed = 1.2, size = 0.12, gravity = 0.25, color = { 1, 1, 1 }, alpha = 1, life = 7 },
  sandstorm = { per_second = 3000, speed = 9, size = 0.25, gravity = 0, color = { 0.66, 0.54, 0.38 }, alpha = 0.4,
    life = 2.5, sideways = true },
}
weather.FALL = FALL

-- The falling rain, snow or sand around eye for dt seconds, thinned to the particle budget (share 0..1).
function weather.fall(kind, strength, eye, wind, dt, share)
  local f = FALL[kind]
  if not f or strength <= 0 then return 0 end
  local count = math.min(4096, math.floor(f.per_second * strength * dt * (share or 1) + 0.5)) -- emit's limit, after a long frame
  if count <= 0 then return 0 end
  local down = f.sideways and { wind[1], -0.1, wind[2] } or { wind[1] * 0.15, -1, wind[2] * 0.15 }
  local l = math.sqrt(down[1] * down[1] + down[2] * down[2] + down[3] * down[3])
  fk.gfx.emit({ count = count, position = { eye[1] - down[1] / l * 8, eye[2] + (f.sideways and 1 or 5), eye[3] - down[3] / l * 8 },
    radius = weather.RANGE, direction = { down[1] / l, down[2] / l, down[3] / l }, spread = 0.08, speed_min = f.speed * 0.85,
    speed_max = f.speed * 1.15, life_min = f.life * 0.8, life_max = f.life, size = f.size, size_end = f.size,
    gravity = f.gravity, color = f.color, alpha = f.alpha, alpha_end = f.alpha * 0.6, stretch = f.stretch })
  return count
end

-- Lightning in a storm: a strike now and then (from a hash of the world and the half-second), returning where it hit
-- (local axes, kilometres away) or nil.
function weather.strike(seed, kind, strength, t)
  if kind ~= "storm" or strength < 0.5 then return nil end
  local slot = math.floor(t * 2)
  local h = hash(seed % 0x7fffffff + 7, slot)
  if h % 23 ~= 0 then return nil end
  local a, d = (h >> 8) % 628 / 100, 800 + (h >> 4) % 4000
  return { fk.math.cos(a) * d, 0, fk.math.sin(a) * d }, slot
end

local LOOPS = { rain = "rain_loop", storm = "rain_loop", sandstorm = "sandstorm_loop" }

-- Each frame: the weather now for the world (ctx: seed, desc, air, cold, t, dt, eye, wind {x, z}, share of the particle
-- budget), its falling particles, sound and lightning. Returns {kind, strength, look, flash (0..1)}.
function weather.present(state, ctx)
  local kinds = weather.kinds(ctx.desc, ctx.air, ctx.cold)
  local kind, strength = weather.at(ctx.seed, kinds, ctx.t)
  weather.fall(kind, strength, ctx.eye, ctx.wind, ctx.dt, ctx.share)
  local loop = LOOPS[kind]
  if state.loop_name ~= loop then -- a new kind of weather: its sound (the old one stops)
    if state.voice then fk.audio.stop(state.voice) end
    state.voice = loop and fk.audio.play(loop, { loop = true, bus = "ambient", volume = 0 }) or nil
    state.loop_name = loop
  end
  if state.voice then fk.audio.set(state.voice, { volume = 0.7 * strength }) end
  local at, slot = weather.strike(ctx.seed, kind, strength, ctx.t)
  if at and state.slot ~= slot then -- lightning: a flash now, its thunder when the sound arrives
    state.slot, state.flash, state.flash_at = slot, 1, at
    state.thunder_in = math.sqrt(at[1] * at[1] + at[3] * at[3]) / 343
  end
  if state.thunder_in then
    state.thunder_in = state.thunder_in - ctx.dt
    if state.thunder_in <= 0 then
      fk.audio.play("thunder", { bus = "ambient", volume = 0.9 })
      state.thunder_in = nil
    end
  end
  local flash = state.flash or 0
  state.flash = math.max(0, flash - ctx.dt * 6)
  return { kind = kind, strength = strength, look = weather.look(kind, strength), flash = flash, at = state.flash_at }
end

return weather
