-- fk.planet waters and water_mesh (rivers-and-lakes spec): rivers, lakes and falls around a place on a world.
local planets = require("gen.planets")

local function world()
  return planets.describe({ class = "terran", radius = 6.371e6, temperature = 288, seed = 77,
    atmosphere = { gas = "n2o2", pressure = 1 } })
end

local function norm(v)
  local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  return { v[1] / l, v[2] / l, v[3] / l }
end

-- A frame on the surface at the first direction whose height lies in [lo, hi] metres.
local function frame(d, lo, hi)
  for k = 0, 2000 do
    local a, b = k * 0.0731, k * 0.0137
    local up = norm({ fk.math.cos(a) * fk.math.cos(b), fk.math.sin(b), fk.math.sin(a) * fk.math.cos(b) })
    local h = d.surface:height(up[1], up[2], up[3])
    if h >= lo and h <= hi then
      local east = norm({ up[3], 0, -up[1] })
      local north = { up[2] * east[3] - up[3] * east[2], up[3] * east[1] - up[1] * east[3], up[1] * east[2] - up[2] * east[1] }
      return { up = up, east = east, north = north }
    end
  end
end

local function fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(text, 1, true), "expected '" .. text .. "', got " .. tostring(err))
end

return {
  ["rivers, lakes and falls around the range, the same every time"] = function()
    local d = world()
    local f = frame(d, 20, 400)
    assert(d.surface:water_mesh() == nil, "no water courses yet")
    local before = d.surface:height(f.up[1], f.up[2], f.up[3])
    local w = d.surface:waters({ up = f.up, east = f.east, north = f.north, n = 128, cell = 24, keep = 200 })
    assert(w.rivers > 0 and w.lakes > 0, "rivers and lakes: " .. w.rivers .. ", " .. w.lakes)
    assert(w.river and w.river[3] and w.lake, "where they are, and which way the river runs")
    assert(d.surface:height(f.up[1], f.up[2], f.up[3]) == before, "the kept site is not carved")
    assert(d.surface:water_mesh(), "water surfaces")
    local again = world()
    local w2 = again.surface:waters({ up = f.up, east = f.east, north = f.north, n = 128, cell = 24, keep = 200 })
    assert(w2.rivers == w.rivers and w2.lakes == w.lakes and w2.river[1] == w.river[1] and w2.river[2] == w.river[2],
      "deterministic")
    -- the river's channel is carved into the ground
    local r = norm({ f.up[1] * 6.371e6 + f.east[1] * w.river[1] + f.north[1] * w.river[2],
      f.up[2] * 6.371e6 + f.east[2] * w.river[1] + f.north[2] * w.river[2],
      f.up[3] * 6.371e6 + f.east[3] * w.river[1] + f.north[3] * w.river[2] })
    local plain = world()
    assert(d.surface:height(r[1], r[2], r[3]) < plain.surface:height(r[1], r[2], r[3]) - 0.5, "a channel")
  end,
  ["near the shore, rivers pour into the sea"] = function()
    local d = world()
    local f = frame(d, 1, 15)
    local w = d.surface:waters({ up = f.up, east = f.east, north = f.north, n = 64, cell = 150 })
    assert(w.rivers > 0 and w.fall, "a river falls into the sea")
    assert(d.surface:water_mesh())
  end,
  ["mistakes are errors"] = function()
    local d = world()
    local f = frame(d, 20, 400)
    fails(function() d.surface:waters({ up = f.up, east = f.east, north = f.north, n = 1 }) end, "'n' from 2 to 1024")
    fails(function() d.surface:waters({ up = f.up, east = f.east, north = f.north, cell = 0 }) end, "'cell' above 0")
  end,
}
