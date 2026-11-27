-- star-rendering spec: stars of several kinds from space, boiling with convection cells and spots (a Sun-like star,
-- a red dwarf, a blue giant, a pulsar with its beam), and a planet lit by both stars of a binary.
local star_view = require("star_view")
local planets = require("gen.planets")
local planet_view = require("planet_view")
local mat4 = require("mat4")

local STARS = {
  { name = "sun", mass = 1, kind = "star" },
  { name = "red_dwarf", mass = 0.2, kind = "star" },
  { name = "blue_giant", mass = 12, kind = "star" },
  { name = "pulsar", mass = 1.4, kind = "neutron_star", pulsar = { period = 0.4, tilt = 0.6 } },
}

return scenario {
  seed = 1,
  timeout_s = 60,
  run = function(t)
    local game = require("game")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 0, max_lights = 8, hdr = true, bloom = true, dither = true })
    fk.gfx.palette(nil)
    local scene
    game.draw = function() scene() end
    local function camera()
      fk.gfx.camera(mat4.look_at({ 0, 0, 0 }, { 0, 0, -1 }), mat4.perspective(math.rad(50), 480 / 270, 0.05, 400))
      fk.gfx.clear(0, 0, 0)
      fk.gfx.ambient({ sky = { 0.01, 0.01, 0.02 }, ground = { 0, 0, 0 }, intensity = 1 })
    end
    for i, s in ipairs(STARS) do
      local phys = fk.galaxy.physics(s.kind, s.mass, i)
      local radius = s.kind == "neutron_star" and 1e7 or 7e8 -- the pulsar is shown far larger than it is
      local v = star_view.new({ radius = radius, color = phys.color, pulsar = s.pulsar }, i)
      scene = function()
        camera()
        star_view.draw(v, { 0, 0, -radius * 3.2 }, 2, 30)
      end
      t.frames(20)
      t.screenshot("star_" .. s.name)
    end
    local body = { class = "desert", radius = 6.371e6, temperature = 320, seed = 9 }
    local view = planet_view.new(planets.describe(body), 9)
    scene = function()
      camera()
      fk.gfx.sun({ direction = { 0.9, 0.2, 0.3 }, color = { 1, 0.9, 0.7 }, intensity = 4 })
      fk.gfx.sun2({ direction = { -0.8, 0.3, 0.4 }, color = { 0.6, 0.7, 1 }, intensity = 3 })
      view:draw({ 0, 0, -6.371e6 * 2.8 }, { 0, 0, 0, 1 }, 270 / (2 * math.tan(math.rad(25))), true)
    end
    t.frames(5)
    t.screenshot("star_binary_light")
  end,
}
