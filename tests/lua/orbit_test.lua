-- fk.math, fk.orbit and motion on rails in fk/frames.lua (orbital-mechanics spec).
local frames = require("fk.frames")
local sim = require("fk.sim")

local function fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(text, 1, true), "expected '" .. text .. "', got " .. tostring(err))
end

return {
  ["deterministic sine and cosine"] = function()
    assert(math.abs(fk.math.sin(1) - math.sin(1)) < 1e-15 and math.abs(fk.math.cos(2) - math.cos(2)) < 1e-15)
    assert(fk.math.wrap(3 * fk.math.pi) < -3.14, "wrapped into [-pi, pi)")
  end,
  ["orbits from elements"] = function()
    local el = { a = 7e6, mu = 3.986004418e14 }
    local p, v = fk.orbit.state(el, 0)
    assert(math.abs(p[1] - 7e6) < 1e-6 and v[3] < 0, "starts on +x, moving towards -z (counter-clockwise from +y)")
    assert(math.abs(fk.orbit.period(el) - 2 * math.pi * math.sqrt(7e6 ^ 3 / 3.986004418e14)) < 1e-6)
    fails(function() fk.orbit.state({ mu = 1 }, 0) end, "'a' must be a number")
    fails(function() fk.orbit.state({ a = 1, mu = 1, e = 1.5 }, 0) end, "the eccentricity must be from 0 to below 1")
    fails(function() fk.orbit.period(5) end, "table expected")
  end,
  ["frames follow their orbits and spin"] = function()
    sim.reset()
    local sun = frames.create()
    local planet = frames.create(sun)
    frames.orbit(planet, { a = 1e11, mu = 1.3e20, anomaly = 0.5 })
    local surface = frames.create(planet)
    frames.spin(surface, { 0, 2, 0 }, 1, 0.25)
    frames.update(100)
    local f = sim.get(planet, "frame")
    local r = math.sqrt(f.p[1] ^ 2 + f.p[2] ^ 2 + f.p[3] ^ 2)
    assert(math.abs(r - 1e11) < 1, "on the circle")
    local s = sim.get(surface, "frame")
    assert(math.abs(s.q[2] - math.sin(50.125)) < 1e-12 and s.w[2] == 1, "turned by rate * t + phase about +y")
    fails(function() frames.orbit(planet, { a = -1, mu = 1 }) end, "semi-major axis")
    fails(function() frames.spin(surface, { 0, 0, 0 }, 1) end, "the spin axis must not be zero")
  end,
}
