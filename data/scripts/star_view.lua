-- Stars (star-rendering spec): an HDR emissive sphere whose surface boils with convection cells and dark spots (vertex
-- colours that tint the emission), turning slowly; bloom and eye adaptation give the glow. Pulsars sweep a beam.
local frames = require("fk.frames")

local star_view = {}

local function sphere_mesh(seed)
  local cells = fk.noise.graph({ nodes = {
    grain = { "cells", frequency = 14, edges = true, seed = 1 },
    spots = { "smooth", { "fbm", frequency = 3, octaves = 3, seed = 2 }, edge0 = 0.45, edge1 = 0.65 },
  }, output = "grain" }, seed)
  local spots = fk.noise.graph({ nodes = { s = { "smooth", { "fbm", frequency = 3, octaves = 3, seed = 2 }, edge0 = 0.45, edge1 = 0.65 } },
    output = "s" }, seed)
  local mesh = { positions = {}, colors = {}, normals = {}, indices = {} }
  local SEG, RINGS = 48, 24
  for r = 0, RINGS do
    local phi = r / RINGS * fk.math.pi
    for s = 0, SEG do
      local theta = s / SEG * 2 * fk.math.pi
      local x, y, z = fk.math.sin(phi) * fk.math.cos(theta), fk.math.cos(phi), fk.math.sin(phi) * fk.math.sin(theta)
      local edge = math.min(1, cells:eval(x, y, z) * 4) -- dark lanes between the convection cells
      local k = (0.7 + 0.3 * edge) * (1 - 0.6 * spots:eval(x, y, z))
      local n = #mesh.positions
      mesh.positions[n + 1], mesh.positions[n + 2], mesh.positions[n + 3] = x, y, z
      mesh.normals[n + 1], mesh.normals[n + 2], mesh.normals[n + 3] = x, y, z
      mesh.colors[n + 1], mesh.colors[n + 2], mesh.colors[n + 3] = k, k, k
    end
  end
  local row = SEG + 1
  for r = 0, RINGS - 1 do
    for s = 0, SEG - 1 do
      local a, b = r * row + s + 1, (r + 1) * row + s + 1
      for _, i in ipairs({ a, b, a + 1, a + 1, b, b + 1 }) do mesh.indices[#mesh.indices + 1] = i end
    end
  end
  return fk.gfx.mesh(mesh)
end

local function beam_mesh()
  local mesh = { positions = {}, colors = {}, indices = {} }
  local SEG = 12
  for k = 0, SEG do -- two cones from the poles: radius grows with length
    local a = k / SEG * 2 * fk.math.pi
    for _, sign in ipairs({ 1, -1 }) do
      local n = #mesh.positions
      mesh.positions[n + 1], mesh.positions[n + 2], mesh.positions[n + 3] = fk.math.cos(a) * 0.08, sign, fk.math.sin(a) * 0.08
      mesh.colors[n + 1], mesh.colors[n + 2], mesh.colors[n + 3] = 1, 1, 1
    end
  end
  local tip = #mesh.positions // 3 + 1
  for _ = 1, 2 do mesh.positions[#mesh.positions + 1], mesh.positions[#mesh.positions + 2], mesh.positions[#mesh.positions + 3] = 0, 0, 0 end
  for _ = 1, 6 do mesh.colors[#mesh.colors + 1] = 1 end
  for k = 0, SEG - 1 do
    local up, down = k * 2 + 1, k * 2 + 2
    for _, i in ipairs({ tip, up, up + 2, tip + 1, down + 2, down }) do mesh.indices[#mesh.indices + 1] = i end
  end
  return fk.gfx.mesh(mesh)
end

function star_view.new(star, seed)
  return { star = star, mesh = sphere_mesh(seed or 0), beam = star.pulsar and beam_mesh() or nil }
end

-- Draws the star at rel (camera-relative, camera-frame axes) at presentation time t.
function star_view.draw(v, rel, t, brightness)
  local s = v.star
  local slice, at, k = frames.place_in_slices(rel, math.max(s.radius, 1e4))
  local spin = { 0, fk.math.sin(t * 0.01), 0, fk.math.cos(t * 0.01) }
  local c, b = s.color, (brightness or 60)
  fk.gfx.draw(v.mesh, frames.matrix(spin, at, math.max(s.radius, 1e4) * k),
    { slice = slice, emission = { c[1] * b, c[2] * b, c[3] * b }, emissive_colors = true, one_sided = true })
  if v.beam then -- the pulsar's beam sweeps round with its period
    local a = t * 2 * fk.math.pi / math.max(s.pulsar.period, 0.05) * 0.02
    local tilt = frames.multiply({ 0, fk.math.sin(a / 2), 0, fk.math.cos(a / 2) },
      { fk.math.sin(s.pulsar.tilt / 2), 0, 0, fk.math.cos(s.pulsar.tilt / 2) })
    fk.gfx.draw(v.beam, frames.matrix(tilt, at, 4e10 * k), { slice = slice, emission = { 3, 5, 12 }, roughness = 1 })
  end
end

return star_view
