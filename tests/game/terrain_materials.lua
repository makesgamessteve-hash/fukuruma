-- terrain-materials spec: the ground up close on several worlds: detail and bumps on a terran hillside, rock and
-- snow in high mountains, a wet shore, a desert under blowing dust, and the hillside after rain and under snow.
local planets = require("gen.planets")
local terrain = require("terrain")
local mat4 = require("mat4")
local frames = require("fk.frames")

-- The local frame at unit direction up: y along up (an arc from the world's y axis).
local function ground_at(desc, radius, up)
  local c, x, z = up[2], up[3], -up[1]
  local w = 1 + c
  local n = math.sqrt(x * x + z * z + w * w)
  local to_body = { x / n, 0, z / n, w / n }
  return { desc = desc, surface = desc.surface, radius = radius, up = up, east = frames.rotate(to_body, { 1, 0, 0 }),
    north = frames.rotate(to_body, { 0, 0, 1 }), to_local = frames.conjugate(to_body),
    centre = { 0, -(radius + desc.surface:height(up[1], up[2], up[3])), 0 } }
end

-- The first direction (scanning a band of latitudes) whose height passes the test.
local function find(desc, lat, test)
  for k = 0, 255 do
    local a = k * 2 * fk.math.pi / 256
    local c = math.sqrt(1 - lat * lat)
    local d = { fk.math.cos(a) * c, lat, fk.math.sin(a) * c }
    if test(desc.surface:height(d[1], d[2], d[3])) then return d end
  end
end

local SHOTS = {
  { name = "hillside", class = "terran", lat = 0.25, test = function(h) return h > 400 and h < 900 end },
  { name = "mountains", class = "terran", lat = 0.45, test = function(h) return h > 2000 and h < 2600 end },
  { name = "shore", class = "terran", lat = 0.2, test = function(h) return h > 1 and h < 30 end },
  { name = "dust", class = "desert", lat = 0.1, test = function(h) return h > 100 end, weather = { dust = 1 } },
  { name = "rain", class = "terran", lat = 0.25, test = function(h) return h > 400 and h < 900 end, weather = { wet = 1 } },
  { name = "snowfall", class = "terran", lat = 0.25, test = function(h) return h > 400 and h < 900 end, weather = { snow = 1 } },
}

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 0, max_lights = 8, hdr = true, bloom = true, dither = true })
    fk.gfx.palette(nil)
    require("planet_view").MATERIAL = 3
    require("planet_view").PIXELS = 4
    local worlds = {}
    local g, weather, state
    game.draw = function()
      local eye, look = { 0, 3, 0 }, { 0, -2, -12 }
      fk.gfx.camera(mat4.look_at(eye, look), mat4.perspective(math.rad(60), 480 / 270, 0.05, 400))
      fk.gfx.clear(0.3, 0.4, 0.55)
      fk.gfx.sun({ direction = { 0.6, 0.55, -0.4 }, color = { 1, 0.95, 0.85 }, intensity = 4 })
      fk.gfx.ambient({ sky = { 0.25, 0.3, 0.4 }, ground = { 0.1, 0.09, 0.08 }, intensity = 1 })
      local f = { 0, -2 / math.sqrt(148), -12 / math.sqrt(148) }
      terrain.draw(state, g, eye, f, math.atan(math.tan(math.rad(30)) * math.sqrt(1 + (480 / 270) * (480 / 270))),
        270 / (2 * math.tan(math.rad(30))), true, weather)
    end
    for _, s in ipairs(SHOTS) do
      local w = worlds[s.class]
      if not w then
        local body = { class = s.class, radius = 6.371e6, temperature = s.class == "desert" and 320 or 288, seed = 4,
          atmosphere = { gas = "n2o2", pressure = 1 } }
        w = { body = body, desc = planets.describe(body) }
        worlds[s.class] = w
      end
      local up = find(w.desc, s.lat, s.test)
      t.expect(up ~= nil, "a site for " .. s.name)
      g, weather, state = ground_at(w.desc, w.body.radius, up), s.weather, {}
      t.frames(3)
      t.screenshot("terrain_" .. s.name)
    end
  end,
}
