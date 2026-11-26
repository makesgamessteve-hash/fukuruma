-- fk.gfx validates what scripts (and mods) pass to it, also when nothing is rendered.
local function fails(fn, pattern)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(pattern, 1, true), tostring(err))
end

local I = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
local triangle = { positions = { 0, 0, 0, 1, 0, 0, 0, 1, 0 }, colors = { 1, 1, 1, 1, 1, 1, 1, 1, 1 }, indices = { 1, 2, 3 } }

return {
  ["mesh needs tables"] = function()
    fails(function() fk.gfx.mesh({ colors = {}, indices = {} }) end, "'positions' must be a table")
  end,
  ["mesh needs whole vertices"] = function()
    fails(function() fk.gfx.mesh({ positions = { 1, 2 }, colors = { 1, 2 }, indices = { 1, 1, 1 } }) end, "x, y, z")
  end,
  ["mesh needs a colour per vertex"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = {}, indices = { 1, 1, 1 } }) end, "r, g, b")
  end,
  ["mesh normals must match the vertices"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = { 1, 1, 1 }, normals = { 0, 1 }, indices = { 1, 1, 1 } }) end, "normals must hold")
    fails(function() fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = { 1, 1, 1 }, normals = 5, indices = { 1, 1, 1 } }) end, "normals must hold")
    assert(fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = { 1, 1, 1 }, normals = { 0, 1, 0 }, indices = { 1, 1, 1 } }))
  end,
  ["mesh needs whole triangles"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = { 1, 1, 1 }, indices = { 1 } }) end, "whole triangles")
  end,
  ["mesh rejects non-numbers"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, "x", 0 }, colors = { 1, 1, 1 }, indices = { 1, 1, 1 } }) end, "positions[2]")
    fails(function() fk.gfx.mesh({ positions = { 0, 0 / 0, 0 }, colors = { 1, 1, 1 }, indices = { 1, 1, 1 } }) end, "finite")
  end,
  ["mesh rejects indices out of range"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = { 1, 1, 1 }, indices = { 1, 1, 2 } }) end, "indices[3]")
  end,
  ["draw takes a model matrix and a material"] = function()
    local mesh = fk.gfx.mesh(triangle)
    fk.gfx.draw(mesh, I)
    fk.gfx.draw(mesh, I, { roughness = 0.2, metalness = 1, emission = { 4, 2, 1 } })
    fails(function() fk.gfx.draw(mesh, { 1, 2, 3 }) end, "16 numbers")
    fails(function() fk.gfx.draw(mesh, I, { roughness = 2 }) end, "'roughness' must be a number from 0.0 to 1.0")
    fails(function() fk.gfx.draw(mesh, I, { metalness = "x" }) end, "'metalness'")
    fails(function() fk.gfx.draw(mesh, I, { emission = { 1, 2 } }) end, "'emission' must be a table of 3 numbers")
    fails(function() fk.gfx.draw(mesh, I, { emission = { -1, 0, 0 } }) end, "'emission' values")
    fails(function() fk.gfx.draw({}, I) end, "fk.mesh")
  end,
  ["planes can be tiled"] = function()
    local plane = require("shapes").plane(8, { 1, 1, 1 }, 2)
    assert(#plane.uvs == 8 and plane.uvs[2] == 4, "the texture repeats every 2 m")
    fk.gfx.mesh(plane)
  end,
  ["mesh uvs must match the vertices"] = function()
    local t = { positions = triangle.positions, colors = triangle.colors, indices = triangle.indices, uvs = { 0, 0, 1, 0, 0, 1 } }
    fk.gfx.mesh(t)
    t.uvs = { 0, 0 }
    fails(function() fk.gfx.mesh(t) end, "uvs must hold u, v for every vertex")
  end,
  ["textures are cached and checked"] = function()
    local font = fk.gfx.texture("fonts/font8x8.png")
    assert(font == fk.gfx.texture("fonts/font8x8.png"), "the same path gives the same texture")
    local w, h = font:size()
    assert(w == 128 and h == 64, w .. "x" .. h)
    assert(select(1, fk.gfx.texture("textures/test_ground.jpg"):size()) == 256, "JPEG")
    fails(function() fk.gfx.texture("fonts/none.png") end, "texture: fonts/none.png: cannot find the file")
    fails(function() fk.gfx.texture("scripts/main.lua") end, "not a PNG or JPEG image")
    fails(function() fk.gfx.texture("../secret.png") end, "is not a path inside data/")
    fails(function() fk.gfx.texture("/etc/passwd") end, "is not a path inside data/")
    fails(function() fk.gfx.texture("a b.png") end, "is not a path inside data/")
    fk.gfx.draw(fk.gfx.mesh(triangle), I, { texture = font })
    fails(function() fk.gfx.draw(fk.gfx.mesh(triangle), I, { texture = "font" }) end, "'texture' must be a texture")
  end,
  ["models load, list their clips and nodes, and draw"] = function()
    local suit = fk.gfx.model("models/exosuit.glb")
    assert(suit == fk.gfx.model("models/exosuit.glb"), "cached")
    local names = {}
    for _, clip in ipairs(suit:clips()) do names[#names + 1] = clip.name .. "=" .. clip.duration end
    assert(table.concat(names, " ") == "idle=4.0 walk=1.2000000476837 run=0.75", table.concat(names, " "))
    assert(suit:nodes()[1] == "Exosuit" and #suit:nodes() == 17, "nodes")
    fk.gfx.draw(suit, I)
    fails(function() fk.gfx.model("models/none.glb") end, "model: cannot find models/none.glb")
    fails(function() fk.gfx.model("scripts/main.lua") end, "not a valid glTF file")
    fails(function() fk.gfx.draw(suit, { 1 }) end, "the matrix must have 16 numbers")
  end,
  ["overlay and camera"] = function()
    local mesh = fk.gfx.mesh(triangle)
    fk.gfx.overlay(mesh, I)
    fk.gfx.camera(I, I)
    fails(function() fk.gfx.camera(I, { 1 }) end, "camera: the matrix must have 16 numbers")
  end,
  ["lights"] = function()
    fk.gfx.sun({ direction = { 0, 1, 0 }, color = { 1, 0.9, 0.8 }, intensity = 3 })
    fk.gfx.sun({})
    fails(function() fk.gfx.sun({ direction = { 0, 0, 0 } }) end, "must not be zero")
    fk.gfx.ambient({ sky = { 0.5, 0.6, 0.8 }, ground = { 0.2, 0.2, 0.2 }, intensity = 0.5 })
    fk.gfx.ambient({})
    fk.gfx.light({ position = { 1, 2, 3 }, color = { 1, 0.5, 0 }, intensity = 20, radius = 5 })
    fails(function() fk.gfx.light({ radius = 0 }) end, "'radius'")
    fk.gfx.clear(0.1, 0.2, 0.3)
  end,
  ["grading"] = function()
    fk.gfx.grade({ exposure = -1, contrast = 1.2, saturation = 0.8, tint = { 1, 0.9, 0.8 } })
    fk.gfx.grade({})
    fails(function() fk.gfx.grade({ contrast = 9 }) end, "'contrast'")
  end,
  ["text, rectangles and palette"] = function()
    fk.gfx.text(8, 8, "FUKURUMA", { 1, 0.8, 0.4 })
    fk.gfx.text(8, 20, "white by default")
    fk.gfx.rect(4, 4, 100, 30, { 0, 0, 0, 0.5 })
    fails(function() fk.gfx.rect(0, 0, 1, 1, { 1, 1 }) end, "3 or 4 numbers")
    fails(function() fk.gfx.text(0, 0, "x", { 2, 0, 0 }) end, "colour values must be from 0 to 1")
    fk.gfx.palette({ { 0, 0, 0 }, { 1, 1, 1 } })
    fk.gfx.palette(nil)
    fails(function() fk.gfx.palette({}) end, "give 1 to 64 colours")
  end,
  ["device"] = function()
    local d = fk.gfx.device()
    assert(d.renderer == "none" and d.web == false and d.phone == false)
  end,
  ["configure and settings"] = function()
    local before = fk.gfx.settings()
    fk.gfx.configure({ width = 640, height = 360, supersample = 2, shadow_cascades = 3, shadow_size = 512,
      ao_samples = 4, max_lights = 4, bloom = false, hdr = true, dither = false, taa = true, fill = false })
    assert(fk.gfx.settings().taa and not fk.gfx.settings().fill)
    local s = fk.gfx.settings()
    assert(s.width == 640 and s.supersample == 2 and s.shadow_cascades == 3 and s.bloom == false and s.dither == false)
    local w, h = fk.gfx.size()
    assert(w == 640 and h == 360)
    fails(function() fk.gfx.configure({ supersample = 3 }) end, "'supersample' is out of range")
    fails(function() fk.gfx.configure({ width = "wide" }) end, "'width' must be an integer")
    fails(function() fk.gfx.configure({ bloom = 1 }) end, "'bloom' must be true or false")
    fk.gfx.configure(before)
    assert(fk.gfx.settings().width == before.width)
  end,
}
