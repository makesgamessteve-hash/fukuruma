-- weather spec: rain on a meadow (wet ground, mist, falling drops), a snowfall, a sandstorm on a desert world, and a
-- thunderstorm lit by lightning; a world's weather is the same at the same time, and comes and goes in spells.
local planets = require("gen.planets")
local terrain = require("terrain")
local scatter = require("scatter")
local weather = require("weather")
local mat4 = require("mat4")
local frames = require("fk.frames")

local function ground_at(desc, radius, up)
  local c, x, z = up[2], up[3], -up[1]
  local w = 1 + c
  local n = math.sqrt(x * x + z * z + w * w)
  local to_body = { x / n, 0, z / n, w / n }
  return { desc = desc, surface = desc.surface, radius = radius, up = up, east = frames.rotate(to_body, { 1, 0, 0 }),
    north = frames.rotate(to_body, { 0, 0, 1 }), to_local = frames.conjugate(to_body),
    centre = { 0, -(radius + desc.surface:height(up[1], up[2], up[3])), 0 } }
end

local function unit(v)
  local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  return { v[1] / l, v[2] / l, v[3] / l }
end

local function land(desc, lat, low, high)
  for k = 0, 1023 do
    local a = k * 2 * fk.math.pi / 1024
    local d = unit({ fk.math.cos(a), lat, fk.math.sin(a) })
    local h = desc.surface:height(d[1], d[2], d[3])
    if h > low and h < high then return d end
  end
end

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 0, max_lights = 8, hdr = true, bloom = true, dither = true, max_particles = 6000, clouds = true })
    fk.gfx.palette(nil)
    local pv = require("planet_view")
    pv.REACH, pv.MAX_LEVEL, pv.PIXELS, pv.MATERIAL = nil, 20, 6, 3
    scatter.density = 1
    local terran = planets.describe({ class = "terran", radius = 6.371e6, temperature = 288, seed = 4,
      atmosphere = { gas = "n2o2", pressure = 1 } })
    local desert = planets.describe({ class = "desert", radius = 6.371e6, temperature = 320, seed = 4,
      atmosphere = { gas = "n2o2", pressure = 1 } })
    local meadow = ground_at(terran, 6.371e6, land(terran, 0.25, 200, 900))
    local dunes = ground_at(desert, 6.371e6, land(desert, 0.1, 100, 2000))
    local shot, ground_state, plants, flash = nil, {}, {}, 0
    game.draw = function()
      fk.gfx.particles(1 / 60)
      local g = shot.ground
      local eye, look = { 0, 2, 300 }, unit({ 0, -0.05, -1 })
      fk.gfx.camera(mat4.look_at(eye, { eye[1] + look[1], eye[2] + look[2], eye[3] + look[3] }),
        mat4.perspective(math.rad(65), 480 / 270, 0.05, 400))
      fk.gfx.clear(0, 0, 0)
      fk.gfx.sun({ direction = unit({ 0.3, 0.6, -0.6 }), color = { 1, 0.95, 0.88 }, intensity = 4 })
      local f = flash
      fk.gfx.ambient({ sky = { 0.2, 0.25, 0.35 }, ground = { 0.08, 0.08, 0.07 }, intensity = 1 + 6 * f })
      fk.gfx.wind({ direction = { 0.8, 0.35 }, strength = 1.5, time = 3 })
      local look_w = weather.look(shot.kind, 1)
      local air = g.desc.atmosphere
      fk.gfx.atmosphere({ centre = g.centre, radius = 6.371e6, top = air.top, height = air.height, rayleigh = air.rayleigh,
        mie = air.mie, absorb = air.absorb, ground = { 0.3, 0.4, 0.3 }, fog = look_w.fog,
        clouds = { bottom = 1800, top = 4200, cover = 0.45 + look_w.cover, density = 0.006, steps = 24 } })
      terrain.draw(ground_state, g, eye, look, math.atan(math.tan(math.rad(32.5)) * math.sqrt(1 + (480 / 270) * (480 / 270))),
        270 / (2 * math.tan(math.rad(32.5))), true, look_w)
      scatter.draw(plants, g, eye)
    end
    local SHOTS = {
      { name = "rain", kind = "rain", ground = meadow },
      { name = "snow", kind = "snow", ground = meadow },
      { name = "sandstorm", kind = "sandstorm", ground = dunes },
      { name = "storm", kind = "storm", ground = meadow, flash = 1 },
    }
    for _, s in ipairs(SHOTS) do
      shot, ground_state, plants, flash = s, {}, {}, s.flash or 0
      for _ = 1, 10 do fk.gfx.particles(1) end -- (the previous shot's particles are gone)
      for _ = 1, 40 do -- let the rain, snow or sand fill the air
        weather.fall(s.kind, 1, { 0, 3, 300 }, { 0.8, 0.35 }, 1 / 60, 0.5)
        t.frames(1)
      end
      t.screenshot("weather_" .. s.name)
    end
    -- the same world at the same time has the same weather; it comes and goes
    local kinds = weather.kinds(terran, { pressure = 1 }, false)
    local a, sa = weather.at(77, kinds, 1000)
    local b, sb = weather.at(77, kinds, 1000)
    t.expect(a == b and sa == sb, "deterministic")
    local seen = {}
    for spell = 0, 40 do seen[(weather.at(77, kinds, spell * weather.SPELL + 200))] = true end
    t.expect(seen.clear and seen.rain and seen.storm, "spells of different weather")
    local _, start = weather.at(77, kinds, 0)
    t.expect(start == 0, "a spell rises from nothing")
    t.expect(weather.kinds(terran, nil, false)[1] == "clear" and #weather.kinds(terran, nil, false) == 1, "no air, no weather")
    t.expect(weather.kinds(terran, { pressure = 1 }, true)[2] == "snow", "cold worlds snow")
    t.expect(weather.kinds(desert, { pressure = 1 }, false)[2] == "sandstorm", "dry worlds blow sand")
  end,
}
