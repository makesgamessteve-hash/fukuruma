-- Draws a planet's surface (planet-rendering spec): a quadtree of chunks on the six faces of a cube sphere, split
-- where a chunk's grid would look coarser than PIXELS internal pixels, culled behind the horizon. Chunks are built in
-- the background (fk.planet); until a chunk's four children are ready, the chunk itself is drawn, so there are no
-- holes. Unused chunks are dropped after a while.
local frames = require("fk.frames")

local planet_view = {}
local View = {}
View.__index = View

planet_view.PIXELS = 3     -- the most a chunk's quad may span on screen before it splits
planet_view.MAX_LEVEL = 14 -- deepest level from space (M5 goes further)
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

-- Collects the chunks to draw for a camera at cam (metres, planet axes, from the planet's centre).
function View:select(cam, focal, wait)
  local R = self.d.radius
  local dist_c = math.sqrt(cam[1] * cam[1] + cam[2] * cam[2] + cam[3] * cam[3])
  local out = {}
  local function visit(f, l, x, y)
    local c = self:request(f, l, x, y)
    local size = 2 / (1 << l)
    local dx, dy, dz = fk.planet.direction(f, -1 + (x + 0.5) * size, -1 + (y + 0.5) * size)
    local extent = R * size * 0.8 + (self.d.relief or 0)
    -- behind the horizon: the chunk's nearest point faces away by more than the horizon angle allows
    local cosa = (dx * cam[1] + dy * cam[2] + dz * cam[3]) / dist_c
    local horizon = R / math.max(dist_c, R)
    if cosa < horizon - size * 1.2 - 0.02 then return end
    local px, py, pz = dx * R - cam[1], dy * R - cam[2], dz * R - cam[3]
    local d = math.max(math.sqrt(px * px + py * py + pz * pz) - extent, 1)
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

-- Draws the planet. rel: its centre relative to the camera (metres, camera-frame axes); q: its rotation (planet axes
-- into those axes); focal: pixels per radian of the view (height / (2 tan(fov / 2))). wait: build what is needed now
-- (tests and screenshots). Returns the number of chunks drawn.
function View:draw(rel, q, focal, wait, opts)
  self.frame = self.frame + 1
  local inv = frames.conjugate(q)
  local cam = frames.rotate(inv, { -rel[1], -rel[2], -rel[3] })
  local chosen = self:select(cam, focal, wait)
  local slice, at, s = frames.place_in_slices(rel, self.d.radius + (self.d.relief or 0))
  local scale = s
  local material = { roughness = self.d.bands and 0.6 or 0.85, slice = slice, one_sided = true }
  if opts then for k, v in pairs(opts) do if k ~= "sun" then material[k] = v end end end
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
  for k, c in pairs(self.chunks) do -- forget what has not been used for a while
    if self.frame - c.used > planet_view.KEEP then self.chunks[k] = nil end
  end
  return #chosen
end

return planet_view
