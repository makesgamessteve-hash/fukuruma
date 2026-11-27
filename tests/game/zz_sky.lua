return scenario { seed = 1, timeout_s = 30, run = function(t)
  local game, mat4 = require("game"), require("mat4")
  local galaxy = require("fk.galaxy")
  local home = galaxy.home_star()
  local map = fk.gfx.starfield(fk.seed(), home.position, 100, 256)
  print("stars drawn", map:stars())
  local yaw = 0
  game.draw = function()
    fk.gfx.camera(mat4.multiply(mat4.rotation_x(-0.1), mat4.rotation_y(yaw)), mat4.perspective(math.rad(70), 480 / 270, 0.1, 100))
    fk.gfx.clear(0, 0, 0)
    fk.gfx.sky(map, { strength = 1 })
  end
  for i, y in ipairs({ 0, 1.6, 3.2 }) do yaw = y; t.frames(30); t.screenshot("zz_sky" .. i) end
end }
