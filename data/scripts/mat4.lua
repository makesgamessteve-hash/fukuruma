-- 4x4 matrices as flat, column-major arrays of 16 numbers (the layout fk.gfx.draw expects).
local mat4 = {}

function mat4.identity()
  return { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
end

function mat4.multiply(a, b)
  local r = {}
  for col = 0, 3 do
    for row = 1, 4 do
      local sum = 0
      for k = 0, 3 do
        sum = sum + a[k * 4 + row] * b[col * 4 + k + 1]
      end
      r[col * 4 + row] = sum
    end
  end
  return r
end

function mat4.perspective(fovy, aspect, near, far)
  local f = 1 / math.tan(fovy / 2)
  return { f / aspect, 0, 0, 0, 0, f, 0, 0, 0, 0, (far + near) / (near - far), -1, 0, 0, 2 * far * near / (near - far), 0 }
end

function mat4.translation(x, y, z)
  return { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1 }
end

function mat4.rotation_x(a)
  local c, s = math.cos(a), math.sin(a)
  return { 1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1 }
end

function mat4.rotation_y(a)
  local c, s = math.cos(a), math.sin(a)
  return { c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1 }
end

function mat4.rotation_z(a)
  local c, s = math.cos(a), math.sin(a)
  return { c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
end

-- A view matrix: the camera at eye looking at target, with +y up (target must not be straight above or below).
function mat4.look_at(eye, target)
  local fx, fy, fz = target[1] - eye[1], target[2] - eye[2], target[3] - eye[3]
  local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
  fx, fy, fz = fx / fl, fy / fl, fz / fl
  local sx, sy, sz = -fz, 0, fx -- forward x up
  local sl = math.sqrt(sx * sx + sz * sz)
  sx, sz = sx / sl, sz / sl
  local ux, uy, uz = sy * fz - sz * fy, sz * fx - sx * fz, sx * fy - sy * fx -- side x forward
  return { sx, ux, -fx, 0, sy, uy, -fy, 0, sz, uz, -fz, 0,
    -(sx * eye[1] + sy * eye[2] + sz * eye[3]), -(ux * eye[1] + uy * eye[2] + uz * eye[3]),
    fx * eye[1] + fy * eye[2] + fz * eye[3], 1 }
end

-- Transforms the point (x, y, z, 1); returns x, y, z, w.
function mat4.apply(m, x, y, z)
  return m[1] * x + m[5] * y + m[9] * z + m[13],
    m[2] * x + m[6] * y + m[10] * z + m[14],
    m[3] * x + m[7] * y + m[11] * z + m[15],
    m[4] * x + m[8] * y + m[12] * z + m[16]
end

return mat4
