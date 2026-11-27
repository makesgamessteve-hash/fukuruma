-- volumetric-clouds-and-fog spec: a terran world's sky with clouds seen from the ground at midday and at sunset,
-- from above the cloud tops, morning fog low over the ground, and shafts of light through broken cloud.
local planets = require("gen.planets")
local terrain = require("terrain")
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

local SHOTS = {
  { name = "midday", eye = { 0, 2, 0 }, look = { 0, 0.45, -1 }, sun = { 0.3, 0.9, -0.3 }, cover = 0.45 },
  { name = "sunset", eye = { 0, 2, 0 }, look = { 0, 0.15, -1 }, sun = { 0.1, 0.06, -1 }, cover = 0.5 },
  { name = "above", eye = { 0, 5200, 0 }, look = { 0, -0.35, -1 }, sun = { 0.4, 0.6, -0.5 }, cover = 0.55 },
  { name = "fog", eye = { 0, 30, 0 }, look = { 0, -0.12, -1 }, sun = { 0.5, 0.25, -0.7 }, cover = 0.2, fog = 0.004 },
  { name = "shafts", eye = { 0, 40, 0 }, look = { 0.1, 0.3, -1 }, sun = { 0.2, 0.45, -0.85 }, cover = 0.5, fog = 0.0012,
    fog_height = 600 },
}

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 0, max_lights = 8, hdr = true, bloom = true, dither = true, clouds = true })
    fk.gfx.palette(nil)
    local pv = require("planet_view")
    pv.REACH, pv.MAX_LEVEL, pv.PIXELS, pv.MATERIAL = nil, 20, 6, 2
    local body = { class = "terran", radius = 6.371e6, temperature = 288, seed = 4, atmosphere = { gas = "n2o2", pressure = 1 } }
    local desc = planets.describe(body)
    local up -- on land near the equator
    for k = 0, 255 do
      local a = k * 2 * fk.math.pi / 256
      local d = unit({ fk.math.cos(a), 0.24, fk.math.sin(a) })
      if desc.surface:height(d[1], d[2], d[3]) > 150 then up = d break end
    end
    t.expect(up ~= nil, "land")
    local g = ground_at(desc, body.radius, up)
    local shot, state = SHOTS[1], {}
    game.draw = function()
      local look = unit(shot.look)
      fk.gfx.camera(mat4.look_at(shot.eye, { shot.eye[1] + look[1], shot.eye[2] + look[2], shot.eye[3] + look[3] }),
        mat4.perspective(math.rad(65), 480 / 270, 0.05, 400))
      fk.gfx.clear(0, 0, 0)
      local sun = unit(shot.sun)
      fk.gfx.sun({ direction = sun, color = { 1, 0.95, 0.88 }, intensity = 5 })
      fk.gfx.ambient({ sky = { 0.2, 0.25, 0.35 }, ground = { 0.08, 0.08, 0.07 }, intensity = 1 })
      local air = desc.atmosphere
      fk.gfx.atmosphere({ centre = g.centre, radius = body.radius, top = air.top, height = air.height, rayleigh = air.rayleigh,
        mie = air.mie, absorb = air.absorb, ground = { 0.3, 0.4, 0.3 },
        clouds = { bottom = 1800, top = 4200, cover = shot.cover, density = 0.006, offset = { 300, 0, 900 }, steps = 32 },
        fog = shot.fog and { density = shot.fog, height = shot.fog_height or 120 } or nil })
      terrain.draw(state, g, shot.eye, look, math.atan(math.tan(math.rad(32.5)) * math.sqrt(1 + (480 / 270) * (480 / 270))),
        270 / (2 * math.tan(math.rad(32.5))), true)
    end
    for _, s in ipairs(SHOTS) do
      shot = s
      t.frames(4)
      t.screenshot("clouds_" .. s.name)
    end
  end,
}
