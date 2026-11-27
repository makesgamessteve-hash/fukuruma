-- biomes-and-scatter spec: flora and rocks over the ground from standing height: a meadow with grass, shrubs and
-- trees swaying in the wind, a dry hillside with scattered rocks, and frozen ground; the same place twice looks
-- the same; within the frame budget.
local planets = require("gen.planets")
local terrain = require("terrain")
local scatter = require("scatter")
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

local function find(desc, lat, test)
  for k = 0, 255 do
    local a = k * 2 * fk.math.pi / 256
    local c = math.sqrt(1 - lat * lat)
    local d = { fk.math.cos(a) * c, lat, fk.math.sin(a) * c }
    local r, g, b = desc.surface:color(d[1], d[2], d[3])
    if test(desc.surface:height(d[1], d[2], d[3]), r, g, b) then return d end
  end
end

local SHOTS = {
  { name = "meadow", class = "terran", lat = 0.25, test = function(h, r, g, b) return h > 200 and g - (r + b) / 2 > 0.08 end },
  { name = "dry", class = "desert", lat = 0.1, test = function(h) return h > 300 end },
  { name = "frozen", class = "terran", lat = 0.55, test = function(h, r, g, b) return h > 1500 end },
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
    require("planet_view").REACH, require("planet_view").MAX_LEVEL = nil, 20 -- to the horizon, whatever this machine's level
    require("planet_view").PIXELS = 4
    scatter.density = 1
    local g, state, plants, time = nil, {}, {}, 0
    game.draw = function()
      local eye, look = { 0, 1.8, 200 }, { 0, 0.6, 188 }
      fk.gfx.camera(mat4.look_at(eye, look), mat4.perspective(math.rad(60), 480 / 270, 0.05, 400))
      fk.gfx.clear(0.3, 0.4, 0.55)
      fk.gfx.sun({ direction = { 0.6, 0.55, -0.4 }, color = { 1, 0.95, 0.85 }, intensity = 4 })
      fk.gfx.ambient({ sky = { 0.25, 0.3, 0.4 }, ground = { 0.1, 0.09, 0.08 }, intensity = 1 })
      fk.gfx.wind({ direction = { 1, 0.3 }, strength = 1.2, time = time })
      local f = { 0, -1.2 / math.sqrt(145.44), -12 / math.sqrt(145.44) }
      terrain.draw(state, g, eye, f, math.atan(math.tan(math.rad(30)) * math.sqrt(1 + (480 / 270) * (480 / 270))),
        270 / (2 * math.tan(math.rad(30))), true)
      t.count = scatter.draw(plants, g, { 0, 0, 200 }) -- the grid away from the deck (at the origin)
    end
    local worlds = {}
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
      g, state, plants = ground_at(w.desc, w.body.radius, up), {}, {}
      t.frames(3)
      local draws, triangles = fk.gfx.stats()
      t.expect(draws <= 700 and triangles <= 2e6, s.name .. " within the budget: " .. draws .. " draws, " .. triangles .. " triangles")
      if s.name == "meadow" then t.expect(t.count > 500, "a meadow is full of plants: " .. t.count) end
      t.screenshot("scatter_" .. s.name)
      if s.name == "meadow" then
        local a = scatter.build(g, 0, 200, 1)
        local b = scatter.build(g, 0, 200, 1)
        t.expect(#a.grass == #b.grass and a.tree[1] == b.tree[1], "the same place looks the same")
        time = 1.3
        t.frames(1)
        t.screenshot("scatter_meadow_wind")
        time = 0
      end
    end
  end,
}
