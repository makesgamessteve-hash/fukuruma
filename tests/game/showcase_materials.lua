-- asset-loading spec: a glTF model with PBR materials (base colour, metal/rough and normal textures,
-- emission) on a textured ground (JPEG), against a reference image.
return scenario {
  seed = 1,
  timeout_s = 30,
  run = function(t)
    local game, mat4, shapes = require("game"), require("mat4"), require("shapes")
    fk.gfx.configure({ width = 480, height = 270, fill = false, supersample = 1, taa = false, shadow_cascades = 2,
      shadow_size = 1024, ao_samples = 8, max_lights = 8, hdr = true, bloom = true, dither = true })
    fk.gfx.palette(nil)
    local spheres = fk.gfx.model("models/showcase_materials.glb")
    local ground = fk.gfx.mesh(shapes.plane(40, { 1, 1, 1 }, 4))
    local deck = fk.gfx.texture("textures/test_ground.jpg")
    t.expect(select(1, deck:size()) == 256, "the ground texture is 256 pixels wide")
    t.expect(#spheres:clips() == 0 and #spheres:nodes() == 6, "the model has six nodes and no clips")
    game.draw = function()
      local view = mat4.multiply(mat4.translation(0, -0.6, -4.2), mat4.rotation_x(0.32))
      fk.gfx.camera(view, mat4.perspective(math.rad(45), 480 / 270, 0.1, 100))
      fk.gfx.clear(0.13, 0.17, 0.3)
      fk.gfx.sun({ direction = { -0.6, 0.55, 0.45 }, color = { 1, 0.85, 0.7 }, intensity = 5 })
      fk.gfx.ambient({ sky = { 0.35, 0.45, 0.7 }, ground = { 0.3, 0.26, 0.2 }, intensity = 0.6 })
      fk.gfx.grade({ exposure = -0.4 })
      fk.gfx.light({ position = { 0, 1.6, 1.2 }, color = { 0.6, 0.8, 1 }, intensity = 6, radius = 5 })
      fk.gfx.draw(ground, mat4.identity(), { texture = deck, roughness = 0.9 })
      fk.gfx.draw(spheres, mat4.identity())
    end
    t.frames(60)
    t.screenshot("showcase_materials")
  end,
}
