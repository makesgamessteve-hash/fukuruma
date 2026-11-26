-- Camera rigs (effects spec): a chase camera with spring-damped follow, mass-dependent lag and look-ahead,
-- and a first-person camera; both apply the trauma shake. Presentation only.
local mat4 = require("mat4")
local spring = require("fk.spring")

local camera = {}

local Chase = {}
Chase.__index = Chase

-- opts: distance, height (above the target), look_height, look_ahead (seconds of velocity), mass (heavier:
-- slower follow), fov (degrees), yaw (around the target, radians).
function camera.chase(opts)
  opts = opts or {}
  local frequency = 1.6 / math.sqrt(math.max(0.1, opts.mass or 1))
  local rig = setmetatable({ distance = opts.distance or 8, height = opts.height or 3, look_height = opts.look_height or 1.5,
    look_ahead = opts.look_ahead or 0.35, fov = opts.fov or 55, yaw = opts.yaw or 0, springs = {}, started = false }, Chase)
  for i = 1, 6 do rig.springs[i] = spring.new(frequency, 1) end
  return rig
end

-- Follows a target position with a heading (radians, 0 looks along +z) and velocity {x, y, z}.
function Chase:update(dt, position, heading, velocity)
  local yaw = heading + self.yaw
  local ahead = { position[1] + velocity[1] * self.look_ahead, position[2], position[3] + velocity[3] * self.look_ahead }
  local eye = { ahead[1] - math.sin(yaw) * self.distance, position[2] + self.height, ahead[3] - math.cos(yaw) * self.distance }
  local look = { ahead[1], position[2] + self.look_height, ahead[3] }
  local goal = { eye[1], eye[2], eye[3], look[1], look[2], look[3] }
  for i = 1, 6 do
    if not self.started then self.springs[i].value = goal[i] end
    self.springs[i]:update(goal[i], dt)
  end
  self.started = true
end

function Chase:eye()
  local s = self.springs
  return { s[1].value, s[2].value, s[3].value }, { s[4].value, s[5].value, s[6].value }
end

-- View and projection for an aspect ratio, with the shake (yaw, pitch, roll, x, y) applied.
function Chase:matrices(aspect, shake)
  local eye, look = self:eye()
  return camera.look_at(eye, look, shake), mat4.perspective(math.rad(self.fov), aspect, 0.1, 400)
end

-- A view matrix from eye to target (y up), turned and moved in camera space by a shake {yaw, pitch, roll, x, y}.
function camera.look_at(eye, target, shake)
  local view = mat4.look_at(eye, target)
  if not shake then return view end
  local turn = mat4.multiply(mat4.rotation_z(shake[3]), mat4.multiply(mat4.rotation_x(shake[2]), mat4.rotation_y(shake[1])))
  return mat4.multiply(mat4.translation(-shake[4], -shake[5], 0), mat4.multiply(turn, view))
end

-- A first-person camera at a node matrix (16 numbers, model space) of a doll drawn with `model`; it looks
-- along the node's +z.
function camera.first_person(model, node_matrix, shake)
  local m = mat4.multiply(model, node_matrix)
  local eye = { m[13], m[14], m[15] }
  local forward = { m[9], m[10], m[11] }
  return camera.look_at(eye, { eye[1] + forward[1], eye[2] + forward[2], eye[3] + forward[3] }, shake)
end

return camera
