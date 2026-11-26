-- Simple mesh tables for placeholder scenes: flat-shaded boxes and planes, smooth spheres.
local shapes = {}

local function add_quad(mesh, a, b, c, d, color)
  local base = #mesh.positions // 3
  for _, p in ipairs({ a, b, c, d }) do
    for k = 1, 3 do
      mesh.positions[#mesh.positions + 1] = p[k]
      mesh.colors[#mesh.colors + 1] = color[k]
    end
  end
  for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do mesh.indices[#mesh.indices + 1] = base + i end
end

-- A box centred on the origin; every face has its own vertices, so it is flat-shaded.
function shapes.box(w, h, d, color)
  local x, y, z = w / 2, h / 2, d / 2
  local mesh = { positions = {}, colors = {}, indices = {} }
  add_quad(mesh, { -x, -y, z }, { x, -y, z }, { x, y, z }, { -x, y, z }, color)
  add_quad(mesh, { x, -y, -z }, { -x, -y, -z }, { -x, y, -z }, { x, y, -z }, color)
  add_quad(mesh, { -x, y, z }, { x, y, z }, { x, y, -z }, { -x, y, -z }, color)
  add_quad(mesh, { -x, -y, -z }, { x, -y, -z }, { x, -y, z }, { -x, -y, z }, color)
  add_quad(mesh, { x, -y, z }, { x, -y, -z }, { x, y, -z }, { x, y, z }, color)
  add_quad(mesh, { -x, -y, -z }, { -x, -y, z }, { -x, y, z }, { -x, y, -z }, color)
  return mesh
end

-- A square in the XZ plane facing up.
function shapes.plane(size, color)
  local s = size / 2
  local mesh = { positions = {}, colors = {}, indices = {} }
  add_quad(mesh, { -s, 0, s }, { s, 0, s }, { s, 0, -s }, { -s, 0, -s }, color)
  return mesh
end

-- A UV sphere with shared vertices, so it is smooth-shaded.
function shapes.sphere(radius, segments, color)
  local mesh = { positions = {}, colors = {}, indices = {} }
  local rings = segments // 2
  for r = 0, rings do
    local phi = r / rings * math.pi
    for s = 0, segments do
      local theta = s / segments * 2 * math.pi
      for k, v in ipairs({ math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta) }) do
        mesh.positions[#mesh.positions + 1] = v * radius
        mesh.colors[#mesh.colors + 1] = color[k]
      end
    end
  end
  local row = segments + 1
  for r = 0, rings - 1 do
    for s = 0, segments - 1 do
      local a, b = r * row + s + 1, (r + 1) * row + s + 1
      for _, i in ipairs({ a, a + 1, b + 1, a, b + 1, b }) do mesh.indices[#mesh.indices + 1] = i end
    end
  end
  return mesh
end

return shapes
