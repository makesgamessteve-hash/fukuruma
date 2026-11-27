-- Hull grammar (doll-chain spec): a doll's hull is a list of parts in units of its size (1 = the doll's height or
-- length, the origin where it stands, +z its front), built into one flat-shaded mesh. Parts:
--   { "box", at = {x, y, z}, size = {w, h, d}, color, mirror }
--   { "lathe", at = {x, y, z}, axis = "z" | "y", stations = {{t, r}, ...}, sides, color, mirror }
--   { "legs", count, at = {x, y, z} (the hips' centre), spread = {x, z}, length, thick, color }
--   { "greebles", at = {x, y, z} (the patch's centre on a top face), size = {w, d}, count, height, seed, color }
-- mirror: the part again at -x. Deterministic: greebles come from their seed, not from a global random stream.
local hull = {}

local function triangle(mesh, a, b, c, color)
  for _, p in ipairs({ a, b, c }) do
    local n = #mesh.positions
    mesh.positions[n + 1], mesh.positions[n + 2], mesh.positions[n + 3] = p[1], p[2], p[3]
    mesh.colors[n + 1], mesh.colors[n + 2], mesh.colors[n + 3] = color[1], color[2], color[3]
    mesh.indices[#mesh.indices + 1] = n // 3 + 1
  end
end

local function quad(mesh, a, b, c, d, color)
  triangle(mesh, a, b, c, color)
  triangle(mesh, a, c, d, color)
end

local function box(mesh, at, size, color, s)
  local x, y, z = at[1] * s, at[2] * s, at[3] * s
  local w, h, d = size[1] * s / 2, size[2] * s / 2, size[3] * s / 2
  local function p(i, j, k) return { x + i * w, y + j * h, z + k * d } end
  quad(mesh, p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1), color)
  quad(mesh, p(1, -1, -1), p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1), color)
  quad(mesh, p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1), p(-1, 1, -1), color)
  quad(mesh, p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1), color)
  quad(mesh, p(1, -1, 1), p(1, -1, -1), p(1, 1, -1), p(1, 1, 1), color)
  quad(mesh, p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1), color)
end

local function lathe(mesh, at, axis, stations, sides, color, s)
  local function point(t, r, a)
    local c, sn = fk.math.cos(a) * r, fk.math.sin(a) * r
    if axis == "y" then return { (at[1] + c) * s, (at[2] + t) * s, (at[3] + sn) * s } end
    return { (at[1] + c) * s, (at[2] + sn) * s, (at[3] + t) * s }
  end
  for k = 1, #stations - 1 do
    local t1, r1, t2, r2 = stations[k][1], stations[k][2], stations[k + 1][1], stations[k + 1][2]
    for i = 0, sides - 1 do
      local a1, a2 = i / sides * 2 * math.pi, (i + 1) / sides * 2 * math.pi
      if axis == "y" then a1, a2 = a2, a1 end -- outwards for both axes
      quad(mesh, point(t1, r1, a1), point(t1, r1, a2), point(t2, r2, a2), point(t2, r2, a1), color)
    end
  end
end

local function mirrored(at) return { -at[1], at[2], at[3] } end

local function seeded(seed) -- a small deterministic stream for greebles (xorshift)
  local x = (seed * 2654435761) % 4294967296
  if x == 0 then x = 1 end
  return function()
    x = x ~ ((x << 13) & 0xffffffff)
    x = x ~ (x >> 17)
    x = x ~ ((x << 5) & 0xffffffff)
    return x / 4294967296
  end
end

local BUILD = {
  box = function(mesh, p, s)
    box(mesh, p.at, p.size, p.color, s)
    if p.mirror then box(mesh, mirrored(p.at), p.size, p.color, s) end
  end,
  lathe = function(mesh, p, s)
    lathe(mesh, p.at, p.axis or "z", p.stations, p.sides or 12, p.color, s)
    if p.mirror then lathe(mesh, mirrored(p.at), p.axis or "z", p.stations, p.sides or 12, p.color, s) end
  end,
  legs = function(mesh, p, s) -- upper and lower leg, splayed out from the hips, with a foot
    for i = 0, p.count - 1 do
      local side = i % 2 == 0 and -1 or 1
      local row = p.count > 2 and (i // 2) / (p.count / 2 - 1) * 2 - 1 or 0
      local hx, hz = p.at[1] + side * p.spread[1] * 0.6, p.at[3] + row * p.spread[2]
      local fx, fz = p.at[1] + side * p.spread[1], hz + row * p.spread[2] * 0.15
      local knee = { (hx + fx) / 2 + side * p.thick, p.at[2] - p.length * 0.45, (hz + fz) / 2 }
      box(mesh, { (hx + knee[1]) / 2, (p.at[2] + knee[2]) / 2, (hz + knee[3]) / 2 },
        { p.thick, p.at[2] - knee[2], p.thick }, p.color, s)
      box(mesh, { (knee[1] + fx) / 2, knee[2] / 2, (knee[3] + fz) / 2 }, { p.thick * 0.8, knee[2], p.thick * 0.8 }, p.color, s)
      box(mesh, { fx, p.thick * 0.2, fz }, { p.thick * 1.8, p.thick * 0.4, p.thick * 2.2 }, p.color, s)
    end
  end,
  greebles = function(mesh, p, s)
    local r = seeded(p.seed or 1)
    for _ = 1, p.count do
      local w, d, h = p.size[1] * (0.03 + 0.08 * r()), p.size[2] * (0.03 + 0.08 * r()), p.height * (0.3 + r())
      local x, z = p.at[1] + (r() - 0.5) * (p.size[1] - w), p.at[3] + (r() - 0.5) * (p.size[2] - d)
      box(mesh, { x, p.at[2] + h / 2, z }, { w, h, d }, p.color, s)
    end
  end,
}

-- The mesh table ({positions, colors, indices}) of a doll's hull, size metres high (or long).
function hull.build(parts, size)
  local mesh = { positions = {}, colors = {}, indices = {} }
  for i, p in ipairs(parts) do
    local build = BUILD[p[1]]
    if not build then error("hull: part " .. i .. " has an unknown kind '" .. tostring(p[1]) .. "'", 2) end
    build(mesh, p, size)
  end
  return mesh
end

return hull
