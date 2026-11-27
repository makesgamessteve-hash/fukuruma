local star_view = require("star_view")

return {
  ["a star and a pulsar draw in their slices"] = function()
    local v = star_view.new({ radius = 7e8, color = { 1, 0.9, 0.8 } }, 3)
    assert(v.mesh and v.beam == nil)
    star_view.draw(v, { 0, 0, -2e9 }, 1)
    local p = star_view.new({ radius = 1e4, color = { 0.7, 0.8, 1 }, pulsar = { period = 0.01, tilt = 0.5 } })
    assert(p.beam)
    star_view.draw(p, { 0, 0, -1e5 }, 2, 10)
  end,
}
