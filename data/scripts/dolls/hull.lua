-- Hull grammar (doll-chain spec): a doll's hull is a list of parts in units of its size (1 = the doll's height or
-- length, the origin where it stands, +z its front), built into one flat-shaded mesh. Every part is closed (no open
-- ends), and parts that meet overlap, so a hull has no gaps. Parts:
--   { "box", at = {x, y, z}, size = {w, h, d} }
--   { "taper", at = {x, y, z} (the centre), size = {w, h, d} (the bottom), top = {w, d} (the top face's size),
--     shift = {x, z} (the top face's offset: slopes and wedges) }
--   { "strut", from = {x, y, z}, to = {x, y, z}, size = {w, h} (across), ends = true (overlap the ends by half the
--     width: beams meeting at a joint leave no gap) }
--   { "ball", at = {x, y, z}, r, sides }
--   { "lathe", at = {x, y, z}, axis = "z" | "y" | "x", stations = {{t, r}, ...}, sides } (ends with r > 0 are capped)
--   { "torus", at = {x, y, z}, axis = "y" | "z", r (to the tube's centre), tube (the tube's radius), sides, segments }
--   { "legs", count, at = {x, y, z} (the hips' centre), spread = {x, z}, length, thick } (struts with ball joints)
--   { "greebles", at = {x, y, z} (the patch's centre on a face), size = {w, d}, count, height, seed,
--     face = "top" | "bottom" | "left" | "right" | "front" | "back" }
-- Any part may also have: color; mirror = true (the part again at -x); array = {count, {dx, dy, dz}} (copies along a
-- step); glow = true (the part is a light: drawn by hull.build(parts, size, "glow") with emission, not in the hull).
-- Deterministic: greebles come from their seed, not from a global random stream.
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

-- A closed hexahedron from its 8 corners p(i, j, k), i, j, k = -1 or 1 (x, y, z sides).
local function hexa(mesh, p, color)
  quad(mesh, p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1), color)
  quad(mesh, p(1, -1, -1), p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1), color)
  quad(mesh, p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1), p(-1, 1, -1), color)
  quad(mesh, p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1), color)
  quad(mesh, p(1, -1, 1), p(1, -1, -1), p(1, 1, -1), p(1, 1, 1), color)
  quad(mesh, p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1), color)
end

local function box(mesh, at, size, color, s)
  local x, y, z = at[1] * s, at[2] * s, at[3] * s
  local w, h, d = size[1] * s / 2, size[2] * s / 2, size[3] * s / 2
  hexa(mesh, function(i, j, k) return { x + i * w, y + j * h, z + k * d } end, color)
end

local function taper(mesh, p, s)
  local x, y, z = p.at[1] * s, p.at[2] * s, p.at[3] * s
  local w, h, d = p.size[1] * s / 2, p.size[2] * s / 2, p.size[3] * s / 2
  local top, shift = p.top or { p.size[1], p.size[3] }, p.shift or { 0, 0 }
  local tw, td, sx, sz = top[1] * s / 2, top[2] * s / 2, shift[1] * s, shift[2] * s
  hexa(mesh, function(i, j, k)
    if j > 0 then return { x + sx + i * tw, y + h, z + sz + k * td } end
    return { x + i * w, y - h, z + k * d }
  end, p.color)
end

local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function unit(a)
  local l = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
  return l > 1e-12 and { a[1] / l, a[2] / l, a[3] / l } or { 0, 1, 0 }
end

-- A beam from a to b (units), size {w, h} across; with ends, half the width longer at both ends.
local function strut(mesh, a, b, size, color, s, ends)
  local u = unit(sub(b, a))
  local up = math.abs(u[2]) > 0.95 and { 1, 0, 0 } or { 0, 1, 0 }
  local v = unit(cross(up, u))
  local t = cross(u, v)
  local extra = ends ~= false and size[1] / 2 or 0
  local w, h = size[1] / 2, size[2] / 2
  hexa(mesh, function(i, j, k)
    local base = k > 0 and b or a
    local e = k * extra
    return { (base[1] + u[1] * e + v[1] * i * w + t[1] * j * h) * s, (base[2] + u[2] * e + v[2] * i * w + t[2] * j * h) * s,
      (base[3] + u[3] * e + v[3] * i * w + t[3] * j * h) * s }
  end, color)
end

local function point_on(at, axis, t, c, sn)
  if axis == "y" then return { at[1] + c, at[2] + t, at[3] + sn } end
  if axis == "x" then return { at[1] + t, at[2] + sn, at[3] + c } end
  return { at[1] + c, at[2] + sn, at[3] + t }
end

local function lathe(mesh, at, axis, stations, sides, color, s, cap)
  local function point(t, r, a)
    local q = point_on(at, axis, t, fk.math.cos(a) * r, fk.math.sin(a) * r)
    return { q[1] * s, q[2] * s, q[3] * s }
  end
  local flip = axis == "y"
  for k = 1, #stations - 1 do
    local t1, r1, t2, r2 = stations[k][1], stations[k][2], stations[k + 1][1], stations[k + 1][2]
    for i = 0, sides - 1 do
      local a1, a2 = i / sides * 2 * math.pi, (i + 1) / sides * 2 * math.pi
      if flip then a1, a2 = a2, a1 end -- outwards for every axis
      local p1, p2, p3, p4 = point(t1, r1, a1), point(t1, r1, a2), point(t2, r2, a2), point(t2, r2, a1)
      if r1 <= 0 then triangle(mesh, p1, p3, p4, color) -- (a point at the axis: one triangle, none degenerate)
      elseif r2 <= 0 then triangle(mesh, p1, p2, p3, color)
      else quad(mesh, p1, p2, p3, p4, color) end
    end
  end
  if cap == false then return end
  for _, e in ipairs({ { stations[1], -1 }, { stations[#stations], 1 } }) do -- closed ends: no holes
    local t, r = e[1][1], e[1][2]
    if r > 0 then
      local centre = point(t, 0, 0)
      for i = 0, sides - 1 do
        local a1, a2 = i / sides * 2 * math.pi, (i + 1) / sides * 2 * math.pi
        if (e[2] > 0) == flip then a1, a2 = a2, a1 end
        triangle(mesh, centre, point(t, r, a2), point(t, r, a1), color)
      end
    end
  end
end

local function ball(mesh, at, r, sides, color, s)
  local stations, rings = {}, math.max(3, sides // 2)
  for i = 0, rings do
    local a = -math.pi / 2 + i / rings * math.pi
    stations[#stations + 1] = { fk.math.sin(a) * r, fk.math.cos(a) * r }
  end
  stations[1][2], stations[#stations][2] = 0, 0
  lathe(mesh, at, "y", stations, sides, color, s, false)
end

local function torus(mesh, p, s)
  local stations, n = {}, p.sides or 8
  for i = 0, n do
    local a = i / n * 2 * math.pi
    stations[#stations + 1] = { fk.math.sin(a) * p.tube, p.r + fk.math.cos(a) * p.tube }
  end
  lathe(mesh, p.at, p.axis or "y", stations, p.segments or 32, p.color, s, false)
end

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

-- Where leg i of a legs part stands: hip, knee, ankle (units).
local function leg(p, i)
  local side = i % 2 == 0 and -1 or 1
  local row = p.count > 2 and (i // 2) / (p.count / 2 - 1) * 2 - 1 or 0
  local hx, hz = p.at[1] + side * p.spread[1] * 0.6, p.at[3] + row * p.spread[2]
  local fx, fz = p.at[1] + side * p.spread[1], hz + row * p.spread[2] * 0.15
  local knee = { hx + (fx - hx) * 0.5 + side * p.thick * 1.5, p.at[2] - p.length * 0.3, (hz + fz) / 2 }
  return { hx, p.at[2], hz }, knee, { fx, p.thick * 0.9, fz }, side
end

local BUILD = {
  box = function(mesh, p, s) box(mesh, p.at, p.size, p.color, s) end,
  taper = taper,
  strut = function(mesh, p, s) strut(mesh, p.from, p.to, p.size, p.color, s, p.ends) end,
  ball = function(mesh, p, s) ball(mesh, p.at, p.r, p.sides or 10, p.color, s) end,
  lathe = function(mesh, p, s) lathe(mesh, p.at, p.axis or "z", p.stations, p.sides or 12, p.color, s, p.cap) end,
  torus = torus,
  legs = function(mesh, p, s) -- thigh and shin struts on ball joints, an armoured knee and a broad foot
    local dark = p.joint or p.color
    for i = 0, p.count - 1 do
      local hip, knee, ankle, side = leg(p, i)
      local t = p.thick
      ball(mesh, hip, t * 0.85, 10, dark, s)
      strut(mesh, hip, knee, { t, t * 1.2 }, p.color, s)
      ball(mesh, knee, t * 0.75, 10, dark, s)
      box(mesh, { knee[1] + side * t * 0.2, knee[2] + t * 0.2, knee[3] + t * 0.45 }, { t * 0.9, t * 1.6, t * 0.6 }, p.color, s)
      strut(mesh, knee, ankle, { t * 0.8, t * 0.9 }, p.color, s)
      strut(mesh, { knee[1], knee[2] - t, knee[3] - t * 0.5 }, { ankle[1], ankle[2] + t, ankle[3] - t * 0.5 }, { t * 0.25, t * 0.25 },
        dark, s) -- the piston behind the shin
      ball(mesh, ankle, t * 0.6, 8, dark, s)
      taper(mesh, { at = { ankle[1], t * 0.25, ankle[3] + t * 0.2 }, size = { t * 2, t * 0.5, t * 2.6 }, top = { t * 1.3, t * 1.6 },
        color = p.color }, s)
    end
  end,
  greebles = function(mesh, p, s)
    local r = seeded(p.seed or 1)
    local face = p.face or "top"
    for _ = 1, p.count do
      local w, d, h = p.size[1] * (0.03 + 0.08 * r()), p.size[2] * (0.03 + 0.08 * r()), p.height * (0.3 + r())
      local u, v = (r() - 0.5) * (p.size[1] - w), (r() - 0.5) * (p.size[2] - d)
      local a = p.at
      if face == "top" then box(mesh, { a[1] + u, a[2] + h / 2, a[3] + v }, { w, h, d }, p.color, s)
      elseif face == "bottom" then box(mesh, { a[1] + u, a[2] - h / 2, a[3] + v }, { w, h, d }, p.color, s)
      elseif face == "right" then box(mesh, { a[1] + h / 2, a[2] + u, a[3] + v }, { h, w, d }, p.color, s)
      elseif face == "left" then box(mesh, { a[1] - h / 2, a[2] + u, a[3] + v }, { h, w, d }, p.color, s)
      elseif face == "front" then box(mesh, { a[1] + u, a[2] + v, a[3] + h / 2 }, { w, d, h }, p.color, s)
      else box(mesh, { a[1] + u, a[2] + v, a[3] - h / 2 }, { w, d, h }, p.color, s) end
    end
  end,
}

-- Where a hull's legs stand: {x, z, width, height} per leg (metres for a doll size metres high), the column from the
-- foot up to the knee that bodies bump into (the physics colliders of legged dolls).
function hull.feet(parts, size)
  local out = {}
  for _, p in ipairs(parts) do
    if p[1] == "legs" then
      for i = 0, p.count - 1 do
        local _, knee, ankle = leg(p, i)
        out[#out + 1] = { ankle[1] * size, ankle[3] * size, p.thick * 1.4 * size, knee[2] * size }
      end
    end
  end
  return out
end

-- Copies the triangles of part mesh m into out: as they are, mirrored at -x (with their winding turned) and along an
-- array's steps.
local function emit(out, m, p, s)
  local copies = p.array and p.array[1] or 1
  local step = p.array and p.array[2] or { 0, 0, 0 }
  for c = 0, copies - 1 do
    local dx, dy, dz = step[1] * c * s, step[2] * c * s, step[3] * c * s
    for _, sign in ipairs(p.mirror and { 1, -1 } or { 1 }) do
      for t = 0, #m.positions // 9 - 1 do
        local order = sign > 0 and { 0, 1, 2 } or { 0, 2, 1 }
        for _, v in ipairs(order) do
          local i = t * 9 + v * 3
          local n = #out.positions
          out.positions[n + 1] = (m.positions[i + 1] + dx) * sign
          out.positions[n + 2], out.positions[n + 3] = m.positions[i + 2] + dy, m.positions[i + 3] + dz
          out.colors[n + 1], out.colors[n + 2], out.colors[n + 3] = m.colors[i + 1], m.colors[i + 2], m.colors[i + 3]
          out.indices[#out.indices + 1] = n // 3 + 1
        end
      end
    end
  end
end

-- The mesh table ({positions, colors, indices}) of a doll's hull, size metres high (or long). which = "glow": only
-- its lights (the parts marked glow), to be drawn with emission; otherwise everything else.
function hull.build(parts, size, which)
  local mesh = { positions = {}, colors = {}, indices = {} }
  for i, p in ipairs(parts) do
    local build = BUILD[p[1]]
    if not build then error("hull: part " .. i .. " has an unknown kind '" .. tostring(p[1]) .. "'", 2) end
    if (p.glow == true) == (which == "glow") then
      local m = { positions = {}, colors = {}, indices = {} }
      p.color = p.color or { 0.6, 0.6, 0.6 }
      build(m, p, size)
      emit(mesh, m, p, size)
    end
  end
  return mesh
end

return hull
