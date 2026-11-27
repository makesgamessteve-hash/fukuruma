-- fk.noise (noise-graphs spec).
local function fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(text, 1, true), "expected '" .. text .. "', got " .. tostring(err))
end

return {
  ["graphs of named, inline and constant nodes"] = function()
    local g = fk.noise.graph({ nodes = {
      base = { "fbm", frequency = 1.5, octaves = 6, seed = 3 },
      peaks = { "ridged", frequency = 4, octaves = 5, seed = 4 },
      mask = { "smooth", "base", edge0 = -0.1, edge1 = 0.4 },
      height = { "add", "base", { "mul", "peaks", "mask" } },
      plates = { "cells", frequency = 3, edges = true },
      out = { "blend", "height", { "terrace", "height", steps = 6, softness = 0.3 }, 0.5 },
    }, output = "out" }, 42)
    local v = g:eval(0.3, 0.5, 0.8)
    assert(v == g:eval(0.3, 0.5, 0.8) and v > -2 and v < 2 and g:count() > 5)
    local other = fk.noise.graph({ nodes = { base = { "fbm", frequency = 1.5, octaves = 6, seed = 3 } }, output = "base" }, 43)
    assert(other:eval(0.3, 0.5, 0.8) ~= fk.noise.graph({ nodes = { base = { "fbm", frequency = 1.5, octaves = 6, seed = 3 } },
      output = "base" }, 42):eval(0.3, 0.5, 0.8), "the graph's seed matters")
    local all = fk.noise.graph({ nodes = { a = { "perlin" }, b = { "billow" }, c = { "craters", density = 0.8 },
      d = { "warp", "a", "b", strength = 0.5 }, e = { "power", { "abs", { "sub", "d", "c" } }, exponent = 2 },
      f = { "clamp", { "scale", { "max", { "min", "e", 1 }, { "latitude" } }, scale = 2, bias = -0.5 }, lo = 0, hi = 1 },
      g = { "add", "f", { "const", value = 0.1 } } }, output = "g" })
    assert(math.abs(all:eval(0.1, 0.2, 0.3)) < 3)
    assert(fk.noise.graph({ nodes = { a = { "perlin" }, b = { "abs", "a" } }, output = "a" }):count() == 1, "only what the output needs")
    assert(fk.noise.graph({ nodes = {}, output = 0.5 }):eval(0, 0, 0) == 0.5)
  end,
  ["mistakes are script errors"] = function()
    fails(function() fk.noise.graph({}) end, "'nodes' must be a table")
    fails(function() fk.noise.graph({ nodes = {}, output = "x" }) end, "there is no node 'x'")
    fails(function() fk.noise.graph({ nodes = { a = { "swirl" } }, output = "a" }) end, "unknown node 'swirl'")
    fails(function() fk.noise.graph({ nodes = { a = { "add", 1 } }, output = "a" }) end, "'add' needs 2 inputs")
    fails(function() fk.noise.graph({ nodes = { a = { "add", "b", 1 }, b = { "abs", "a" } }, output = "a" }) end, "depends on itself")
    fails(function() fk.noise.graph({ nodes = { a = { "fbm", octaves = 40 } }, output = "a" }) end, "octaves must be from 1 to 16")
    local big = {}
    for i = 1, 300 do big["n" .. i] = { "add", i > 1 and "n" .. (i - 1) or 1, 1 } end
    fails(function() fk.noise.graph({ nodes = big, output = "n300" }) end, "more than 256 nodes")
  end,
}
