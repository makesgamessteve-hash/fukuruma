-- Placeholder Jump Ship for M0: a faceted spindle hull with a ring, flat-shaded in the vertex colours.
-- Replaced by the procedural hull grammar in M6.
local jump_ship = {}

local LIGHT = { 0.48, 0.64, 0.6 } -- normalised direction towards the star
local HULL = { 0.62, 0.66, 0.72 }
local RING = { 0.9, 0.55, 0.2 }

-- Appends one flat-shaded triangle (three corners as {x, y, z}) to the mesh tables.
local function triangle(mesh, a, b, c, color)
  local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
  local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
  local len = math.sqrt(nx * nx + ny * ny + nz * nz)
  local light = math.max(0, (nx * LIGHT[1] + ny * LIGHT[2] + nz * LIGHT[3]) / len)
  local shade = 0.3 + 0.7 * light
  for _, p in ipairs({ a, b, c }) do
    local n = #mesh.positions
    mesh.positions[n + 1], mesh.positions[n + 2], mesh.positions[n + 3] = p[1], p[2], p[3]
    mesh.colors[n + 1], mesh.colors[n + 2], mesh.colors[n + 3] = color[1] * shade, color[2] * shade, color[3] * shade
    mesh.indices[#mesh.indices + 1] = n // 3 + 1
  end
end

-- A surface of revolution around the z axis through the given (z, radius) stations.
local function lathe(mesh, stations, sides, color)
  for s = 1, #stations - 1 do
    local z1, r1 = stations[s][1], stations[s][2]
    local z2, r2 = stations[s + 1][1], stations[s + 1][2]
    for i = 0, sides - 1 do
      local a1, a2 = i / sides * 2 * math.pi, (i + 1) / sides * 2 * math.pi
      local p1 = { r1 * math.cos(a1), r1 * math.sin(a1), z1 }
      local p2 = { r1 * math.cos(a2), r1 * math.sin(a2), z1 }
      local p3 = { r2 * math.cos(a2), r2 * math.sin(a2), z2 }
      local p4 = { r2 * math.cos(a1), r2 * math.sin(a1), z2 }
      triangle(mesh, p1, p2, p3, color)
      triangle(mesh, p1, p3, p4, color)
    end
  end
end

function jump_ship.build()
  local mesh = { positions = {}, colors = {}, indices = {} }
  lathe(mesh, { { -3.2, 0 }, { -2.4, 0.55 }, { 0.2, 0.75 }, { 1.8, 0.5 }, { 3.4, 0 } }, 8, HULL)
  lathe(mesh, { { -1.3, 1.5 }, { -1.0, 1.6 }, { -0.7, 1.5 }, { -1.0, 1.4 }, { -1.3, 1.5 } }, 24, RING)
  return mesh
end

return jump_ship
