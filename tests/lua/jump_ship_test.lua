local jump_ship = require("jump_ship")

return {
  ["builds a consistent mesh"] = function()
    local mesh = jump_ship.build()
    local vertices = #mesh.positions // 3
    assert(#mesh.positions % 3 == 0 and #mesh.colors == #mesh.positions)
    assert(#mesh.indices % 3 == 0 and #mesh.indices == vertices)
    for _, i in ipairs(mesh.indices) do assert(i >= 1 and i <= vertices) end
  end,
  ["colours stay in range"] = function()
    for _, c in ipairs(jump_ship.build().colors) do assert(c >= 0 and c <= 1) end
  end,
  ["the engine accepts the mesh"] = function()
    assert(fk.gfx.mesh(jump_ship.build()))
  end,
}
