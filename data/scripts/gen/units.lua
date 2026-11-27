-- Physical constants and deterministic helpers for generation. Generation code uses only these, arithmetic,
-- math.sqrt, math.floor and fk.math (never Lua's ^, math.exp, math.log or math.sin, which call the C library).
local units = {}

units.AU = 1.495978707e11          -- metres
units.G = 6.6743e-11               -- m^3 kg^-1 s^-2
units.SUN_MASS = 1.98892e30        -- kg
units.EARTH_MASS = 5.9722e24       -- kg
units.SUN_RADIUS = 6.957e8         -- metres
units.EARTH_RADIUS = 6.371e6       -- metres
units.MU_SUN = units.G * units.SUN_MASS
units.MU_EARTH = units.G * units.EARTH_MASS
units.EARTH_PER_SUN = units.SUN_MASS / units.EARTH_MASS

local pow, exp, log = fk.math.pow, fk.math.exp, fk.math.log
units.pow, units.exp, units.log = pow, exp, log

function units.cbrt(x) return x > 0 and pow(x, 1 / 3) or 0 end

-- A number between lo and hi, evenly on a log scale.
function units.log_uniform(rng, lo, hi) return exp(log(lo) + rng:float() * (log(hi) - log(lo))) end

function units.uniform(rng, lo, hi) return lo + rng:float() * (hi - lo) end

-- Picks a key of weights ({name = weight}) by weight, in sorted key order so the pick never depends on table order.
function units.pick(rng, weights)
  local names, total = {}, 0
  for name, w in pairs(weights) do
    if w > 0 then
      names[#names + 1] = name
      total = total + w
    end
  end
  table.sort(names)
  local r = rng:float() * total
  for _, name in ipairs(names) do
    r = r - weights[name]
    if r < 0 then return name end
  end
  return names[#names]
end

-- Equilibrium temperature (K) at a distance in AU from a star of luminosity L (solar), for a Bond albedo.
function units.temperature(L, au, albedo)
  return 278.6 * pow(L > 0 and L or 1e-12, 0.25) / math.sqrt(au) * pow(1 - (albedo or 0.3), 0.25)
end

local SYLLABLES = { "ka", "ru", "vel", "an", "tor", "mi", "sa", "dun", "or", "ei", "lo", "zar", "ne", "ix", "ta", "quo",
  "ber", "il", "on", "ush", "fa", "ri", "gal", "em", "yo", "thi", "ma", "ces", "ul", "pra", "ko", "dre" }

-- A pronounceable name from a random stream.
function units.name(rng)
  local parts = {}
  for i = 1, rng:range(2, 3) do parts[i] = SYLLABLES[rng:range(1, #SYLLABLES)] end
  local s = table.concat(parts)
  return s:sub(1, 1):upper() .. s:sub(2)
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }
units.ROMAN = ROMAN

return units
