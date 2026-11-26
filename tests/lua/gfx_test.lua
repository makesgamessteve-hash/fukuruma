-- fk.gfx validates what scripts (and mods) pass to it, also when nothing is rendered.
local function fails(fn, pattern)
  local ok, err = pcall(fn)
  assert(not ok and err:find(pattern, 1, true), tostring(err))
end

local triangle = { positions = { 0, 0, 0, 1, 0, 0, 0, 1, 0 }, colors = { 1, 1, 1, 1, 1, 1, 1, 1, 1 }, indices = { 1, 2, 3 } }

return {
  ["mesh needs tables"] = function()
    fails(function() fk.gfx.mesh({ colors = {}, indices = {} }) end, "'positions' must be a table")
  end,
  ["mesh needs whole vertices"] = function()
    fails(function() fk.gfx.mesh({ positions = { 1, 2 }, colors = { 1, 2 }, indices = { 1, 1, 1 } }) end, "x, y, z")
  end,
  ["mesh needs a colour per vertex"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = {}, indices = { 1, 1, 1 } }) end, "r, g, b")
  end,
  ["mesh needs whole triangles"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = { 1, 1, 1 }, indices = { 1 } }) end, "whole triangles")
  end,
  ["mesh rejects non-numbers"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, "x", 0 }, colors = { 1, 1, 1 }, indices = { 1, 1, 1 } }) end, "positions[2]")
  end,
  ["mesh rejects indices out of range"] = function()
    fails(function() fk.gfx.mesh({ positions = { 0, 0, 0 }, colors = { 1, 1, 1 }, indices = { 1, 1, 2 } }) end, "indices[3]")
  end,
  ["draw needs 16 numbers"] = function()
    local mesh = fk.gfx.mesh(triangle)
    fails(function() fk.gfx.draw(mesh, { 1, 2, 3 }) end, "16 numbers")
    local m = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, "x" }
    fails(function() fk.gfx.draw(mesh, m) end, "matrix[16]")
  end,
  ["draw needs a mesh"] = function()
    fails(function() fk.gfx.draw({}, {}) end, "fk.mesh")
  end,
  ["clear and size work without a window"] = function()
    fk.gfx.clear(0, 0, 0)
    local w, h = fk.gfx.size()
    assert(w == 480 and h == 270)
  end,
  ["print accepts anything"] = function()
    print("test", 1, nil, true)
  end,
}
