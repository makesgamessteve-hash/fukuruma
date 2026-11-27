-- terrain-streaming spec: one continuous descent from high orbit to standing on the ground of a terran world, with
-- the surface streamed down to its finest chunks; no holes and within the frame budget at every height.
local planets = require("gen.planets")
local terrain = require("terrain")
local mat4 = require("mat4")
local frames = require("fk.frames")

local STOPS = { 2e6, 2e5, 2e4, 2e3, 200, 20, 2 } -- metres above the site

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 0, max_lights = 8, hdr = true, bloom = true, dither = true })
    fk.gfx.palette(nil)
    require("planet_view").PIXELS = 3 -- the finest detail, whatever level the game chose for this machine
    local body = { class = "terran", radius = 6.371e6, temperature = 288, seed = 4,
      atmosphere = { gas = "n2o2", pressure = 1 } }
    local desc = planets.describe(body)
    local up -- a site on land near the equator, as the range would choose
    for k = 0, 63 do
      local a = k * 2 * fk.math.pi / 64
      local d = { fk.math.cos(a) * 0.97, 0.24, fk.math.sin(a) * 0.97 }
      local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
      d = { d[1] / l, d[2] / l, d[3] / l }
      if desc.surface:height(d[1], d[2], d[3]) > 300 then up = d break end
    end
    t.expect(up ~= nil, "the world has land")
    -- the local frame: y along up (an arc from the world's y axis to up)
    local c = up[2]
    local x, z = up[3], -up[1] -- axis = y x up
    local w = 1 + c
    local n = math.sqrt(x * x + z * z + w * w)
    local to_body = { x / n, 0, z / n, w / n }
    desc.surface:flatten(up[1], up[2], up[3], 140)
    local g = { desc = desc, surface = desc.surface, radius = body.radius, up = up, east = frames.rotate(to_body, { 1, 0, 0 }),
      north = frames.rotate(to_body, { 0, 0, 1 }), to_local = frames.conjugate(to_body),
      centre = { 0, -(body.radius + desc.surface:height(up[1], up[2], up[3])), 0 } }
    local state, height, chunks = {}, STOPS[1], 0
    local sun = { 0.5, 0.35, -0.8 }
    game.draw = function()
      local eye = { 0, height, height * 0.2 }
      local look = { 0, height * (height > 1e4 and 0 or 0.97), -math.max(height * 2, 30) }
      fk.gfx.camera(mat4.look_at(eye, look), mat4.perspective(math.rad(60), 480 / 270, 0.05, 400))
      fk.gfx.clear(0, 0, 0)
      fk.gfx.sun({ direction = sun, color = { 1, 0.95, 0.85 }, intensity = 5 })
      fk.gfx.ambient({ sky = { 0.25, 0.3, 0.4 }, ground = { 0.1, 0.09, 0.08 }, intensity = 1 })
      local air = desc.atmosphere
      fk.gfx.atmosphere({ centre = g.centre, radius = body.radius, top = air.top, height = air.height, rayleigh = air.rayleigh,
        mie = air.mie, absorb = air.absorb, ground = { 0.3, 0.4, 0.3 } })
      local f = { look[1] - eye[1], look[2] - eye[2], look[3] - eye[3] }
      local fl = math.sqrt(f[1] * f[1] + f[2] * f[2] + f[3] * f[3])
      local half = math.atan(math.tan(math.rad(30)) * math.sqrt(1 + (480 / 270) ^ 2))
      chunks = terrain.draw(state, g, eye, { f[1] / fl, f[2] / fl, f[3] / fl }, half, 270 / (2 * math.tan(math.rad(30))), true)
    end
    for i, h in ipairs(STOPS) do
      height = h
      t.frames(4)
      local draws, triangles = fk.gfx.stats()
      t.expect(chunks > 0, "the ground is drawn")
      t.expect(draws <= 700 and triangles <= 1.6e6, "within the budget at " .. h .. " m: " .. draws .. " draws, " .. triangles .. " triangles")
      t.screenshot("descent_" .. i)
    end
  end,
}
