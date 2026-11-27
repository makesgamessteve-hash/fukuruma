-- Draws a planet's surface (planet-rendering spec): a quadtree of chunks on the six faces of a cube sphere, split
-- where a chunk's grid would look coarser than PIXELS internal pixels, culled behind the horizon. Chunks are built in
-- the background (fk.planet); until a chunk's four children are ready, the chunk itself is drawn, so there are no
-- holes. Unused chunks are dropped after a while.
local frames = require("fk.frames")

local planet_view = {}
local View = {}
View.__index = View

planet_view.PIXELS = 3     -- the most a chunk's quad may span on screen before it splits
planet_view.MAX_LEVEL = 20 -- deepest level: quads of about 0.3 m on an Earth-sized world
planet_view.NEAR = 2e6     -- metres above the surface below which chunks are placed one by one (see draw)
planet_view.MATERIAL = 3   -- the terrain material's quality: 1 layers, 2 with detail, 3 with bumps (graphics levels)
planet_view.REACH = nil    -- metres: chunks further away are left to the air's ground colour (lower graphics levels)
planet_view.KEEP = 300     -- frames an unused chunk stays

local GRID = fk.planet.GRID

-- A ring system as concentric bands between inner and outer (metres), with gaps where a noise profile is thin.
local function ring_mesh(rings, seed)
  local profile = fk.noise.graph({ nodes = { p = { "fbm", frequency = 9, octaves = 5, seed = 7 } }, output = "p" }, seed)
  local mesh = { positions = {}, colors = {}, normals = {}, indices = {} }
  local BANDS, SEGMENTS = 64, 96
  for b = 0, BANDS - 1 do
    local r0 = rings.inner + (rings.outer - rings.inner) * b / BANDS
    local r1 = rings.inner + (rings.outer - rings.inner) * (b + 1) / BANDS
    local density = (0.5 + 0.6 * profile:eval((b + 0.5) / BANDS, 0.3, 0.7)) * (rings.opacity or 0.6) * 1.6
    if rings.gaps and (b * 7 + 3) % (BANDS // rings.gaps) == 0 then density = 0 end -- shepherd gaps
    if density > 0.25 then
      local base = #mesh.positions // 3
      local shade = math.min(1, 0.6 + density * 0.5)
      for k = 0, SEGMENTS do
        local a = k / SEGMENTS * 2 * fk.math.pi
        local c, s = fk.math.cos(a), fk.math.sin(a)
        for _, r in ipairs({ r0, r1 }) do
          local n = #mesh.positions
          mesh.positions[n + 1], mesh.positions[n + 2], mesh.positions[n + 3] = c * r, 0, s * r
          mesh.colors[n + 1], mesh.colors[n + 2], mesh.colors[n + 3] = 0.92 * shade, 0.86 * shade, 0.76 * shade
          mesh.normals[n + 1], mesh.normals[n + 2], mesh.normals[n + 3] = 0, 1, 0
        end
      end
      for k = 0, SEGMENTS - 1 do
        local i = base + k * 2 + 1
        for _, v in ipairs({ i, i + 2, i + 1, i + 1, i + 2, i + 3 }) do mesh.indices[#mesh.indices + 1] = v end -- front up
      end
    end
  end
  return #mesh.indices > 0 and fk.gfx.mesh(mesh) or nil
end

function planet_view.new(descriptor, seed)
  local v = setmetatable({ d = descriptor, chunks = {}, frame = 0, built = 0 }, View)
  if descriptor.rings then v.rings = ring_mesh(descriptor.rings, seed or 0) end
  return v
end

local function key(f, l, x, y) return f .. "/" .. l .. "/" .. x .. "/" .. y end

-- The chunk's request, started if needed.
function View:request(f, l, x, y)
  local k = key(f, l, x, y)
  local c = self.chunks[k]
  if not c then
    c = { req = self.d.surface:chunk(f, l, x, y), used = self.frame }
    self.chunks[k] = c
    self.built = self.built + 1
  end
  c.used = self.frame
  return c
end

-- Whether the chunk is ready to draw (its mesh is taken once ready; wait: until it is built).
local function ready(c, wait)
  if not c.mesh and (wait or c.req:ready()) then c.mesh, c.centre, c.bound = c.req:mesh() end
  return c.mesh ~= nil
end

-- Collects the chunks to draw for a camera at cam (metres, planet axes, from the planet's centre). look (optional):
-- {direction (unit, planet axes), half-angle (radians)}, the view cone; chunks wholly outside it are left out.
function View:select(cam, focal, wait, look)
  local R = self.d.radius
  local dist_c = math.sqrt(cam[1] * cam[1] + cam[2] * cam[2] + cam[3] * cam[3])
  local peak = R + (self.d.relief or 0) + 1000
  local reach = math.acos(math.min(1, R / dist_c)) + math.acos(R / peak) -- presentation: math.acos is fine here
  local out = {}
  local function visit(f, l, x, y)
    local c = self:request(f, l, x, y)
    local size = 2 / (1 << l)
    local dx, dy, dz = fk.planet.direction(f, -1 + (x + 0.5) * size, -1 + (y + 0.5) * size)
    local extent = R * size * 0.8 + math.min(self.d.relief or 0, R * size) -- a chunk's heights span at most its size
    -- beyond the horizon: the chunk's nearest edge lies further round the world than the camera can see, even to the
    -- highest peak (the angle to the horizon plus the angle a peak of the world's relief rises above it)
    local phi = math.acos(math.max(-1, math.min(1, (dx * cam[1] + dy * cam[2] + dz * cam[3]) / dist_c)))
    if phi - size * 0.7 > reach then return end
    local px, py, pz, bound
    if c.mesh then -- built: its real centre and bound
      px, py, pz, bound = c.centre[1] - cam[1], c.centre[2] - cam[2], c.centre[3] - cam[3], c.bound
    else
      px, py, pz, bound = dx * R - cam[1], dy * R - cam[2], dz * R - cam[3], extent
    end
    local dist = math.sqrt(px * px + py * py + pz * pz)
    if look and dist > bound then -- outside the view cone (presentation only: math.acos is fine here)
      local v = look[1]
      local angle = math.acos(math.max(-1, math.min(1, (px * v[1] + py * v[2] + pz * v[3]) / dist)))
      if angle - math.asin(bound / dist) > look[2] then return end
    end
    local d = math.max(dist - bound, 1)
    if planet_view.REACH and d > planet_view.REACH and dist_c - R < planet_view.REACH then return end
    local quad = R * size * 0.8 / GRID
    if l < planet_view.MAX_LEVEL and quad / d * focal > planet_view.PIXELS then
      local kids, all = {}, true
      for j = 0, 1 do
        for i = 0, 1 do
          local k = self:request(f, l + 1, x * 2 + i, y * 2 + j)
          kids[#kids + 1] = { l + 1, x * 2 + i, y * 2 + j }
          all = ready(k, wait) and all
        end
      end
      if all then
        for _, k in ipairs(kids) do visit(f, k[1], k[2], k[3]) end
        return
      end
    end
    if ready(c, wait) then out[#out + 1] = c end
  end
  for f = 0, 5 do visit(f, 0, 0, 0) end
  return out
end

-- Near the ground each chunk gets the depth slice its distance from the eye calls for; a chunk reaching across the
-- local slice's far end is drawn in both slices (the planetary slice starts where the local one ends), so the ground
-- runs on without a seam. Returns how many draws that took.
local function draw_near(self, chosen, rel, q, eye, material, weather)
  local draws = 0
  local function place(c, k)
    local p = frames.rotate(q, c.centre)
    -- the terrain material on the ground near the eye: detail wraps every PERIOD metres, so the chunk's centre goes
    -- in wrapped (the same point of two chunks then gets the same detail)
    if k == 1 then -- (its detail fades with the size of a pixel, so it can cover every chunk drawn full size)
      local cl = math.sqrt(c.centre[1] * c.centre[1] + c.centre[2] * c.centre[2] + c.centre[3] * c.centre[3])
      material.terrain = { quality = planet_view.MATERIAL, origin = { c.centre[1] % 256, c.centre[2] % 256, c.centre[3] % 256 },
        up = frames.rotate(q, { c.centre[1] / cl, c.centre[2] / cl, c.centre[3] / cl }),
        wet = weather and weather.wet, snow = weather and weather.snow, dust = weather and weather.dust }
    else
      material.terrain = nil
    end
    local at = { rel[1] + p[1] * k, rel[2] + p[2] * k, rel[3] + p[3] * k }
    local r = { at[1] - eye[1], at[2] - eye[2], at[3] - eye[3] }
    local bound = c.bound * k
    local slice, _, s = frames.place_in_slices(r, bound)
    local m = frames.matrix(q, slice == "celestial" and { at[1] * s, at[2] * s, at[3] * s } or at, s * k)
    material.slice = slice
    fk.gfx.draw(c.mesh, m, material)
    draws = draws + 1
    -- (twice the reach: the slices clip by depth along the view, which off its axis is less than the distance)
    if slice == "planetary" and math.sqrt(r[1] * r[1] + r[2] * r[2] + r[3] * r[3]) - bound < 2 * frames.LOCAL_FAR then
      material.slice = "local"
      fk.gfx.draw(c.mesh, m, material)
      draws = draws + 1
    end
  end
  for _, c in ipairs(chosen) do place(c, 1) end
  local k = 1 - 0.003 - (self.d.relief or 0) / self.d.radius
  for f = 0, 5 do
    local c = self.chunks[key(f, 0, 0, 0)]
    if c and c.mesh then place(c, k) end
  end
  return draws
end

-- Draws the planet. rel: its centre relative to the camera (metres, camera-frame axes); q: its rotation (planet axes
-- into those axes); focal: pixels per radian of the view (height / (2 tan(fov / 2))). wait: build what is needed now
-- (tests and screenshots). opts.eye: the camera's position in the frame rel is given in (default: its origin), and
-- with it the near-ground placement. Returns the number of chunks drawn.
function View:draw(rel, q, focal, wait, opts)
  self.frame = self.frame + 1
  local inv = frames.conjugate(q)
  local eye = opts and opts.eye or { 0, 0, 0 }
  local cam = frames.rotate(inv, { eye[1] - rel[1], eye[2] - rel[2], eye[3] - rel[3] })
  local look = opts and opts.look and { frames.rotate(inv, opts.look[1]), opts.look[2] }
  local chosen = self:select(cam, focal, wait, look)
  local slice, at, s = frames.place_in_slices(rel, self.d.radius + (self.d.relief or 0))
  local scale = s
  local material = { roughness = self.d.bands and 0.6 or 0.85, slice = slice, one_sided = true, clouds = 1 }
  if opts then for k, v in pairs(opts) do if k ~= "sun" and k ~= "air" and k ~= "eye" and k ~= "look" and k ~= "weather" then material[k] = v end end end
  local altitude = math.sqrt(cam[1] * cam[1] + cam[2] * cam[2] + cam[3] * cam[3]) - self.d.radius
  -- the cloud layer seen from afar thins out on the way down (one fade for every chunk: no seams between levels)
  material.clouds = math.max(0, math.min(1, (altitude - 1e4) / 4e4)) * material.clouds
  if opts and opts.eye and altitude < planet_view.NEAR then
    for f = 0, 5 do ready(self:request(f, 0, 0, 0), wait) end
    self.draws = draw_near(self, chosen, rel, q, eye, material, opts.weather)
    self:forget()
    return #chosen
  end
  for _, c in ipairs(chosen) do
    local p = frames.rotate(q, c.centre)
    local m = frames.matrix(q, { at[1] + p[1] * scale, at[2] + p[2] * scale, at[3] + p[3] * scale }, scale)
    fk.gfx.draw(c.mesh, m, material)
  end
  -- A backstop: the six root chunks, a little lower, so the slivers where chunks of different levels meet show the
  -- planet rather than space.
  local k = 1 - 0.003 - (self.d.relief or 0) / self.d.radius
  for f = 0, 5 do
    local c = self:request(f, 0, 0, 0)
    if ready(c, wait) then
      local p = frames.rotate(q, c.centre)
      fk.gfx.draw(c.mesh, frames.matrix(q, { at[1] + p[1] * scale * k, at[2] + p[2] * scale * k, at[3] + p[3] * scale * k }, scale * k), material)
    end
  end
  if self.rings then
    local tilt = self.d.rings.polar and frames.multiply(q, { fk.math.sin(0.785398), 0, 0, fk.math.cos(0.785398) }) or q
    local sun = opts and opts.sun
    local n = frames.rotate(tilt, { 0, 1, 0 })
    if sun and n[1] * sun[1] + n[2] * sun[2] + n[3] * sun[3] < 0 then
      tilt = frames.multiply(tilt, { 1, 0, 0, 0 }) -- rings let light through: face the lit side to the sun
    end
    fk.gfx.draw(self.rings, frames.matrix(tilt, at, scale), { roughness = 0.9, slice = slice })
  end
  local air = self.d.atmosphere
  if air and (opts == nil or opts.air ~= false) then -- in scaled space the air shrinks and thickens with the planet
    fk.gfx.atmosphere({ centre = at, radius = self.d.radius * scale, top = air.top * scale, height = air.height * scale,
      rayleigh = { air.rayleigh[1] / scale, air.rayleigh[2] / scale, air.rayleigh[3] / scale }, mie = air.mie / scale,
      absorb = { air.absorb[1] / scale, air.absorb[2] / scale, air.absorb[3] / scale } })
  end
  self:forget()
  return #chosen
end

function View:forget() -- drops what has not been used for a while
  for k, c in pairs(self.chunks) do
    if self.frame - c.used > planet_view.KEEP then self.chunks[k] = nil end
  end
end

return planet_view
