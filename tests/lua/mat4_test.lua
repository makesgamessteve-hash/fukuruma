local mat4 = require("mat4")

local function near(a, b) return math.abs(a - b) < 1e-9 end

return {
  ["identity times a matrix is that matrix"] = function()
    local m = mat4.translation(1, 2, 3)
    local r = mat4.multiply(mat4.identity(), m)
    for i = 1, 16 do assert(r[i] == m[i]) end
  end,
  ["translation moves a point"] = function()
    local x, y, z, w = mat4.apply(mat4.translation(1, 2, 3), 1, 1, 1)
    assert(x == 2 and y == 3 and z == 4 and w == 1)
  end,
  ["rotation_y turns x into -z"] = function()
    local x, y, z = mat4.apply(mat4.rotation_y(math.pi / 2), 1, 0, 0)
    assert(near(x, 0) and near(y, 0) and near(z, -1))
  end,
  ["rotation_x turns y into z"] = function()
    local x, y, z = mat4.apply(mat4.rotation_x(math.pi / 2), 0, 1, 0)
    assert(near(x, 0) and near(y, 0) and near(z, 1))
  end,
  ["perspective maps the near plane to -1 and the far plane to 1"] = function()
    local p = mat4.perspective(math.rad(90), 2, 1, 10)
    local _, _, zn, wn = mat4.apply(p, 0, 0, -1)
    local _, _, zf, wf = mat4.apply(p, 0, 0, -10)
    assert(near(zn / wn, -1) and near(zf / wf, 1))
  end,
}
