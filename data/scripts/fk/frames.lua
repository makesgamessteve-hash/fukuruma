-- Reference frames (the reference-frames spec): a tree of frames (star system, body, vessel, ...), each placed in its
-- parent by a position, a velocity, a rotation (unit quaternion {x, y, z, w}) and a spin (angular velocity, rad/s,
-- in the parent's axes). Frames are simulation state: the "frame" component of an entity. Positions are Lua
-- numbers (doubles); a point is turned into another frame through the two frames' nearest common ancestor, so
-- two things in the same far-away frame keep their full precision relative to each other. Only arithmetic and
-- sqrt are used, so the results are the same on every platform.
local sim = require("fk.sim")

local frames = {}

-- Quaternions -----------------------------------------------------------------------------------------------

local function rotate(q, p) -- q * p * conj(q)
  local x, y, z, w = q[1], q[2], q[3], q[4]
  local tx, ty, tz = 2 * (y * p[3] - z * p[2]), 2 * (z * p[1] - x * p[3]), 2 * (x * p[2] - y * p[1])
  return { p[1] + w * tx + y * tz - z * ty, p[2] + w * ty + z * tx - x * tz, p[3] + w * tz + x * ty - y * tx }
end

local function conj(q) return { -q[1], -q[2], -q[3], q[4] } end

local function mul(a, b)
  return { a[4] * b[1] + a[1] * b[4] + a[2] * b[3] - a[3] * b[2], a[4] * b[2] - a[1] * b[3] + a[2] * b[4] + a[3] * b[1],
    a[4] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[4], a[4] * b[4] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3] }
end

local function add(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end

frames.rotate, frames.multiply, frames.conjugate = rotate, mul, conj
frames.IDENTITY = { 0, 0, 0, 1 }

-- The tree ---------------------------------------------------------------------------------------------------

-- A new frame in parent (nil: a root). opts: position, velocity, rotation, spin.
function frames.create(parent, opts)
  opts = opts or {}
  assert(parent == nil or sim.get(parent, "frame"), "the parent is not a frame")
  local id = sim.create()
  sim.set(id, "frame", { parent = parent or 0, p = opts.position or { 0, 0, 0 }, v = opts.velocity or { 0, 0, 0 },
    q = opts.rotation or { 0, 0, 0, 1 }, w = opts.spin or { 0, 0, 0 } })
  return id
end

local function frame(id)
  local f = sim.get(id, "frame")
  if not f then error("entity " .. tostring(id) .. " is not a frame", 2) end
  return f
end

-- Moves a frame in its parent (orbits and other motion on rails call this every tick).
function frames.place(id, position, velocity, rotation)
  local f = frame(id)
  f.p = position
  if velocity then f.v = velocity end
  if rotation then f.q = rotation end
end

function frames.parent(id)
  local p = frame(id).parent
  return p ~= 0 and p or nil
end

-- The frames from id up to its root, id first.
local function chain(id)
  local list = {}
  while id do
    list[#list + 1] = id
    id = frames.parent(id)
  end
  return list
end

-- The state {p, v} of a point moving with velocity v at p in frame id, expressed in its parent.
local function up(id, p, v)
  local f = frame(id)
  local rp = rotate(f.q, p)
  return add(rp, f.p), add(add(rotate(f.q, v), f.v), cross(f.w, rp))
end

-- The inverse: from the parent into frame id.
local function down(id, p, v)
  local f = frame(id)
  local rp = sub(p, f.p)
  local q = conj(f.q)
  return rotate(q, rp), rotate(q, sub(sub(v, f.v), cross(f.w, rp)))
end

-- The rotation of the axes of frame from, expressed in frame to, and the path between them: the frames to climb
-- from `from` up to the common ancestor, and the frames to descend from there to `to`.
local function path(from, to)
  local a, b = chain(from), chain(to)
  local index = {}
  for i, id in ipairs(b) do index[id] = i end
  local climb = {}
  for _, id in ipairs(a) do
    if index[id] then
      local descend = {}
      for i = index[id] - 1, 1, -1 do descend[#descend + 1] = b[i] end
      return climb, descend
    end
    climb[#climb + 1] = id
  end
  error("frames " .. from .. " and " .. to .. " are in different trees", 3)
end

-- A point (and optionally its velocity) in frame from, expressed in frame to.
function frames.convert(from, p, to, v)
  local climb, descend = path(from, to)
  v = v or { 0, 0, 0 }
  for _, id in ipairs(climb) do p, v = up(id, p, v) end
  for _, id in ipairs(descend) do p, v = down(id, p, v) end
  return p, v
end

-- A rotation relative to frame from, expressed relative to frame to.
function frames.convert_rotation(from, q, to)
  local climb, descend = path(from, to)
  for _, id in ipairs(climb) do q = mul(frame(id).q, q) end
  for _, id in ipairs(descend) do q = mul(conj(frame(id).q), q) end
  return q
end

-- Frame transitions: the "place" component {frame, p, v, q} of an entity moves into another frame, keeping its
-- position, velocity and orientation in the world.
function frames.reparent(entity, to)
  local place = sim.get(entity, "place")
  assert(place, "the entity has no place")
  local p, v = frames.convert(place.frame, place.p, to, place.v)
  place.q = frames.convert_rotation(place.frame, place.q or { 0, 0, 0, 1 }, to)
  place.frame, place.p, place.v = to, p, v
end

-- Motion on rails --------------------------------------------------------------------------------------------

-- A frame that follows a Kepler orbit around its parent's origin. elements: see fk.orbit (a, e, i, node,
-- periapsis, anomaly, epoch, mu). Orbits belong in frames that do not spin; a body's spinning surface is a child.
function frames.orbit(id, elements)
  frame(id)
  fk.orbit.period(elements) -- checks the elements
  sim.set(id, "orbit", elements)
end

-- A frame that turns about an axis (in its parent) at rate rad/s, starting at phase radians.
function frames.spin(id, axis, rate, phase)
  frame(id)
  local l = math.sqrt(axis[1] * axis[1] + axis[2] * axis[2] + axis[3] * axis[3])
  assert(l > 0, "the spin axis must not be zero")
  sim.set(id, "spin", { axis = { axis[1] / l, axis[2] / l, axis[3] / l }, rate = rate, phase = phase or 0 })
end

-- Places every frame on rails for the simulation time t (seconds). Deterministic: fk.orbit and fk.math.
function frames.update(t)
  for id, el in sim.each("orbit") do
    local f = frame(id)
    f.p, f.v = fk.orbit.state(el, t)
  end
  for id, s in sim.each("spin") do
    local f, half = frame(id), (s.rate * t + s.phase) / 2
    local sn = fk.math.sin(half)
    f.q = { s.axis[1] * sn, s.axis[2] * sn, s.axis[3] * sn, fk.math.cos(half) }
    f.w = { s.axis[1] * s.rate, s.axis[2] * s.rate, s.axis[3] * s.rate }
  end
end

-- Drawing: camera-relative matrices and scaled space --------------------------------------------------------

-- A column-major model matrix from a rotation, a position and a uniform scale.
local function matrix(q, p, s)
  local x, y, z, w = q[1], q[2], q[3], q[4]
  return { s * (1 - 2 * (y * y + z * z)), s * 2 * (x * y + z * w), s * 2 * (x * z - y * w), 0,
    s * 2 * (x * y - z * w), s * (1 - 2 * (x * x + z * z)), s * 2 * (y * z + x * w), 0,
    s * 2 * (x * z + y * w), s * 2 * (y * z - x * w), s * (1 - 2 * (x * x + y * y)), 0,
    p[1], p[2], p[3], 1 }
end
frames.matrix = matrix

-- The depth slices' reach in metres (see fk.gfx.slices); scaled space puts celestial things at SCALED_DISTANCE.
frames.LOCAL_FAR = 400
frames.PLANETARY = { 400, 2e7 } -- it starts where the local slice ends, so the ground runs on across both
frames.SCALED_DISTANCE = 1e8

-- Where and how to draw something of bounding radius r at the camera-relative position rel: the slice, the
-- position to draw at and the scale. Things that end within the local or the planetary slice's far plane are drawn
-- where they are (parts nearer than the planetary near plane are cut off: up close, the local slice is for that);
-- anything else is drawn in the celestial slice, moved closer and shrunk by the same factor (scaled space), so it
-- keeps its angular size.
function frames.place_in_slices(rel, r)
  local d = math.sqrt(rel[1] * rel[1] + rel[2] * rel[2] + rel[3] * rel[3])
  if d + r <= frames.LOCAL_FAR then return "local", rel, 1 end
  if d + r <= frames.PLANETARY[2] then return "planetary", rel, 1 end
  local s = frames.SCALED_DISTANCE / d
  return "celestial", { rel[1] * s, rel[2] * s, rel[3] * s }, s
end

-- A viewer: the camera's frame and position in it. viewer:draw_args(frame, p, q, r) gives the matrix (relative to
-- the camera, in the camera frame's axes) and the slice for a thing of radius r at p with rotation q in frame.
local Viewer = {}
Viewer.__index = Viewer

function frames.viewer(frame_id, position)
  return setmetatable({ frame = frame_id, p = position }, Viewer)
end

function Viewer:relative(frame_id, p)
  local q = frames.convert(frame_id, p, self.frame)
  return { q[1] - self.p[1], q[2] - self.p[2], q[3] - self.p[3] }
end

function Viewer:draw_args(frame_id, p, q, r, scale)
  local rel = self:relative(frame_id, p)
  local slice, at, s = frames.place_in_slices(rel, r * (scale or 1))
  local rot = frames.convert_rotation(frame_id, q or { 0, 0, 0, 1 }, self.frame)
  return matrix(rot, at, s * (scale or 1)), slice
end

return frames
