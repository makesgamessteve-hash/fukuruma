-- Camera rigs (effects spec). The game is seen through the Commander's eyes: the helmet rig (and, from M6,
-- seat rigs in the cockpits). The orbit rig is the survey drone's orientation view. Both apply the trauma
-- shake. Presentation only.
local mat4 = require("mat4")

local camera = {}

-- A view matrix from eye to target (y up), turned and moved in camera space by a shake {yaw, pitch, roll, x, y}.
function camera.look_at(eye, target, shake)
  local view = mat4.look_at(eye, target)
  if not shake then return view end
  local turn = mat4.multiply(mat4.rotation_z(shake[3]), mat4.multiply(mat4.rotation_x(shake[2]), mat4.rotation_y(shake[1])))
  return mat4.multiply(mat4.translation(-shake[4], -shake[5], 0), mat4.multiply(turn, view))
end

local function direction(yaw, pitch) -- yaw 0 looks along +z; a larger yaw turns left
  return { math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch) }
end

-- The helmet rig: where the Commander looks. opts: fov (degrees), max_pitch (radians up and down).
local Helmet = {}
Helmet.__index = Helmet

function camera.helmet(opts)
  opts = opts or {}
  return setmetatable({ yaw = 0, pitch = 0, fov = opts.fov or 70, max_pitch = opts.max_pitch or 1.3, turn_rate = 0 }, Helmet)
end

-- Turns the view: right and up are positive (radians); dt (seconds) measures the turn rate for the vignette.
function Helmet:look(right, up, dt)
  self.yaw = self.yaw - right
  self.pitch = math.max(-self.max_pitch, math.min(self.max_pitch, self.pitch + up))
  self.turn_rate = dt > 0 and math.abs(right) / dt or 0
end

function Helmet:forward() return direction(self.yaw, self.pitch) end

-- The flat directions forward and right of the view (for walking).
function Helmet:ground_axes()
  local s, c = math.sin(self.yaw), math.cos(self.yaw)
  return { s, 0, c }, { -c, 0, s }
end

function Helmet:matrices(eye, aspect, shake)
  local f = self:forward()
  return camera.look_at(eye, { eye[1] + f[1], eye[2] + f[2], eye[3] + f[3] }, shake),
    mat4.perspective(math.rad(self.fov), aspect, 0.05, 400)
end

-- The orbit rig (the survey drone): circles a target at a distance, looking at it.
local Orbit = {}
Orbit.__index = Orbit

function camera.orbit(opts)
  opts = opts or {}
  return setmetatable({ yaw = opts.yaw or 0, pitch = opts.pitch or 0.45, distance = opts.distance or 12,
    height = opts.height or 2, fov = opts.fov or 60 }, Orbit)
end

function Orbit:look(right, up)
  self.yaw = self.yaw - right
  self.pitch = math.max(0.05, math.min(1.3, self.pitch + up))
end

function Orbit:eye(target)
  local d = direction(self.yaw, self.pitch)
  return { target[1] - d[1] * self.distance, target[2] + self.height + math.sin(self.pitch) * self.distance,
    target[3] - d[3] * self.distance }
end

function Orbit:matrices(target, aspect)
  local aim = { target[1], target[2] + self.height, target[3] }
  return camera.look_at(self:eye(target), aim), mat4.perspective(math.rad(self.fov), aspect, 0.1, 400)
end

return camera
