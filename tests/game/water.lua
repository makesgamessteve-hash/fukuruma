-- water spec: a terran world's sea: the shore from the land, the open sea with the star's glint, clear shallows from
-- above, and the view from under the surface with caustics on the floor.
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

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 0, max_lights = 8, hdr = true, bloom = true, dither = true })
    fk.gfx.palette(nil)
    local pv = require("planet_view")
    pv.REACH, pv.MAX_LEVEL, pv.PIXELS, pv.MATERIAL = nil, 20, 4, 3
    local body = { class = "terran", radius = 6.371e6, temperature = 288, seed = 4, atmosphere = { gas = "n2o2", pressure = 1 } }
    local desc = planets.describe(body)
    local g, toward -- the waterline, and the direction (local axes) in which the sea lies 3 km off
    for _, lat in ipairs({ 0.2, 0.1, 0.3, 0.0, 0.4 }) do
      for k = 0, 4095 do
        local a = k * 2 * fk.math.pi / 4096
        local d = unit({ fk.math.cos(a), lat, fk.math.sin(a) })
        local h = desc.surface:height(d[1], d[2], d[3])
        if h > -1 and h < -0.2 then -- standing at the waterline
          local c = ground_at(desc, body.radius, d)
          for j = 0, 7 do
            local b = j * fk.math.pi / 4
            local x, z = fk.math.cos(b) * 3000, fk.math.sin(b) * 3000
            local ahead = unit({ d[1] * body.radius + c.east[1] * x + c.north[1] * z, d[2] * body.radius + c.east[2] * x
              + c.north[2] * z, d[3] * body.radius + c.east[3] * x + c.north[3] * z })
            if desc.surface:height(ahead[1], ahead[2], ahead[3]) < -2 then g, toward = c, { x / 3000, z / 3000 } break end
          end
        end
        if g then break end
      end
      if g then break end
    end
    t.expect(g ~= nil, "a shore facing the sea")
    local shot, state = nil, {}
    local SHOTS = {
      { name = "shore", eye = { 0, 3, 0 }, look = { 0, -0.15, -1 }, sun = { 0.4, 0.6, -0.5 } },
      { name = "glint", eye = { 0, 25, 0 }, look = { 0, -0.05, -1 }, sun = { 0.05, 0.25, -1 } },
      { name = "shallows", eye = { 0, 12, 0 }, look = { 0, -1, -0.6 }, sun = { 0.3, 0.9, -0.2 } },
      { name = "under", eye = { 0, -4, 0 }, look = { 0, -0.35, -1 }, sun = { 0.3, 0.9, -0.2 } },
    }
    game.draw = function()
      local f = shot.look -- (x across, y up, -z ahead) turned so that ahead is towards the sea
      local look = unit({ toward[1] * -f[3] + toward[2] * f[1], f[2], toward[2] * -f[3] - toward[1] * f[1] })
      local eye = shot.eye
      if shot.name == "under" then eye = { 0, g.centre[2] + body.radius + 0.05 - 4, 0 } end -- 4 m under the sea
      fk.gfx.camera(mat4.look_at(eye, { eye[1] + look[1], eye[2] + look[2], eye[3] + look[3] }),
        mat4.perspective(math.rad(65), 480 / 270, 0.05, 400))
      fk.gfx.clear(0, 0, 0)
      local sn = shot.sun
      fk.gfx.sun({ direction = unit({ toward[1] * -sn[3] + toward[2] * sn[1], sn[2], toward[2] * -sn[3] - toward[1] * sn[1] }), color = { 1, 0.95, 0.88 }, intensity = 5 })
      fk.gfx.ambient({ sky = { 0.2, 0.25, 0.35 }, ground = { 0.08, 0.08, 0.07 }, intensity = 1 })
      local air = desc.atmosphere
      fk.gfx.atmosphere({ centre = g.centre, radius = body.radius, top = air.top, height = air.height, rayleigh = air.rayleigh,
        mie = air.mie, absorb = air.absorb, ground = { 0.3, 0.4, 0.3 } })
      fk.gfx.water({ centre = g.centre, radius = body.radius, time = 2, waves = 0.5 })
      terrain.draw(state, g, eye, look, math.atan(math.tan(math.rad(32.5)) * math.sqrt(1 + (480 / 270) * (480 / 270))),
        270 / (2 * math.tan(math.rad(32.5))), true)
    end
    for _, s in ipairs(SHOTS) do
      shot = s
      t.frames(4)
      t.screenshot("water_" .. s.name)
    end
    fk.gfx.water(nil)
    t.expect(not pcall(fk.gfx.water, { radius = 0 }), "a sea has a size")
  end,
}
