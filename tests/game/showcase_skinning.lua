-- animation spec: GPU skinning of the Exosuit at fixed clip times (idle, walk, run) and a node turned by a
-- script (the antenna), with shadows, against a reference image.
return scenario {
  seed = 1,
  timeout_s = 30,
  run = function(t)
    local game, mat4, shapes = require("game"), require("mat4"), require("shapes")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 8, max_lights = 8, hdr = true, bloom = true, dither = true })
    fk.gfx.palette(nil)
    local suit = fk.gfx.model("models/exosuit.glb")
    local ground = fk.gfx.mesh(shapes.plane(60, { 1, 1, 1 }, 4))
    local deck = fk.gfx.texture("textures/test_ground.jpg")
    local poses = {
      fk.anim.pose(suit):sample("idle", 1.3):rotate("antenna", { 1, 0, 0 }, -0.5),
      fk.anim.pose(suit):sample("walk", 0.3),
      fk.anim.pose(suit):sample("run", 0.55),
    }
    game.draw = function()
      local view = mat4.multiply(mat4.translation(0, -2.2, -9.5), mat4.rotation_x(0.22))
      fk.gfx.camera(view, mat4.perspective(math.rad(45), 480 / 270, 0.1, 200))
      fk.gfx.clear(0.13, 0.17, 0.3)
      fk.gfx.sun({ direction = { -0.5, 0.6, 0.6 }, color = { 1, 0.85, 0.7 }, intensity = 5 })
      fk.gfx.ambient({ sky = { 0.35, 0.45, 0.7 }, ground = { 0.3, 0.26, 0.2 }, intensity = 0.6 })
      fk.gfx.grade({ exposure = -0.4 })
      fk.gfx.draw(ground, mat4.identity(), { texture = deck, roughness = 0.9 })
      for i, pose in ipairs(poses) do
        local place = mat4.multiply(mat4.translation((i - 2) * 3.2, 0, 0), mat4.rotation_y(0.9))
        fk.gfx.draw(suit, place, { pose = pose })
      end
    end
    t.frames(60)
    t.screenshot("showcase_skinning")
  end,
}
