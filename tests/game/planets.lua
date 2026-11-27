-- planet-rendering spec: one planet of each kind seen from orbit, against reference images, within the draw-call and
-- triangle budgets. The chunks are built before each screenshot (wait), so the pictures do not depend on timing.
local planets = require("gen.planets")
local planet_view = require("planet_view")
local frames = require("fk.frames")
local mat4 = require("mat4")

local KINDS = {
  { class = "terran", temperature = 288, atmosphere = { gas = "n2o2", pressure = 1 } },
  { class = "ocean", temperature = 300, atmosphere = { gas = "n2co2", pressure = 2 } },
  { class = "desert", temperature = 330, atmosphere = { gas = "co2", pressure = 0.3 } },
  { class = "lava", temperature = 1400 },
  { class = "ice", temperature = 90 },
  { class = "barren", temperature = 250 },
  { class = "gas_giant", temperature = 120, radius = 7e7, rings = { inner = 9e7, outer = 1.4e8, opacity = 0.6 }, view = 5 },
  { class = "ice_giant", temperature = 70, radius = 2.5e7 },
}
local DRAWS, TRIANGLES = 400, 700000
local SUN = { 0.8, 0.35, 0.5 }

return scenario {
  seed = 1,
  timeout_s = 120,
  run = function(t)
    local game = require("game")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 8, max_lights = 8, hdr = true, bloom = true, dither = true })
    fk.gfx.palette(nil)
    require("planet_view").PIXELS = 3 -- the finest detail, whatever level the game chose for this machine
    local view, body
    game.draw = function()
      local R = body.radius
      local eye_dist = R * (body.view or 2.6)
      fk.gfx.camera(mat4.look_at({ 0, 0, 0 }, { 0, 0, -1 }), mat4.perspective(math.rad(50), 480 / 270, 0.05, 400))
      fk.gfx.clear(0, 0, 0.004)
      fk.gfx.sun({ direction = SUN, color = { 1, 0.96, 0.9 }, intensity = 4 })
      fk.gfx.ambient({ sky = { 0.02, 0.02, 0.03 }, ground = { 0.01, 0.01, 0.01 }, intensity = 1 })
      fk.gfx.grade({ exposure = -1 })
      local q = frames.multiply({ fk.math.sin(0.25), 0, 0, fk.math.cos(0.25) }, { 0, fk.math.sin(0.3), 0, fk.math.cos(0.3) }) -- tilted
      t.drawn = view:draw({ 0, -R * 0.15, -eye_dist }, q, 270 / (2 * math.tan(math.rad(25))), true, { sun = SUN })
      t.stats = { fk.gfx.stats() }
    end
    for i, k in ipairs(KINDS) do
      body = { class = k.class, radius = k.radius or 6.371e6, temperature = k.temperature, seed = 1000 + i,
        atmosphere = k.atmosphere, rings = k.rings, view = k.view }
      view = planet_view.new(planets.describe(body), body.seed)
      t.frames(3)
      t.expect(t.stats[1] <= DRAWS and t.stats[2] <= TRIANGLES,
        string.format("%s within budget: %d draws, %d triangles", k.class, t.stats[1], t.stats[2]))
      t.screenshot("planet_" .. k.class)
    end
  end,
}
