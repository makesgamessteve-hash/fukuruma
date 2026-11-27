-- Planet descriptors (planet-descriptors spec): from a generated body to what its surface, air and clouds look like.
-- Each planet class has a recipe (a noise graph), a palette and its rules (ocean, life, relief); recipes are a registry
-- that mods can extend (planets.recipe). The surface itself is built in C (fk.planet) from this.
local units = require("gen.units")

local planets = { recipes = {} }

-- def: class id -> function(rng, body) returning {nodes = noise nodes, output, relief (m), sea_level, ocean, life,
-- bands, palette, ice_latitude}
function planets.recipe(class, build) planets.recipes[class] = build end

local function grey(v) return { v, v, v } end

local EARTHLIKE = { deep = { 0.02, 0.07, 0.2 }, shallow = { 0.06, 0.25, 0.36 }, beach = { 0.76, 0.7, 0.5 },
  low = { 0.35, 0.33, 0.25 }, mid = { 0.45, 0.4, 0.33 }, high = { 0.52, 0.48, 0.44 }, peak = { 0.9, 0.92, 0.95 },
  ice = { 0.92, 0.95, 1 }, grass = { 0.25, 0.42, 0.15 }, forest = { 0.1, 0.27, 0.09 }, desert = { 0.76, 0.62, 0.4 },
  tundra = { 0.45, 0.45, 0.35 } }

local function continents(seed)
  return {
    base = { "warp", { "fbm", frequency = 1.1, octaves = 7, seed = seed }, { "fbm", frequency = 0.8, octaves = 3, seed = seed + 1 },
      strength = 0.35 },
    mountains = { "mul", { "ridged", frequency = 2.5, octaves = 6, seed = seed + 2 }, { "smooth", "base", edge0 = 0, edge1 = 0.35 } },
    height = { "add", { "scale", "base", scale = 0.7 }, { "scale", "mountains", scale = 0.5 } },
  }
end

local function cratered(seed, big)
  return {
    base = { "fbm", frequency = 1.5, octaves = 6, seed = seed },
    height = { "add", { "scale", "base", scale = 0.3 },
      { "add", { "scale", { "craters", frequency = big and 3 or 5, density = 0.7, seed = seed + 1 }, scale = 0.5 },
        { "scale", { "craters", frequency = 16, density = 0.5, seed = seed + 2 }, scale = 0.15 } } },
  }
end

planets.recipe("terran", function(rng)
  return { nodes = continents(rng:range(1, 1e6)), relief = 9000, sea_level = units.uniform(rng, -0.05, 0.1), ocean = true,
    life = true, palette = EARTHLIKE, ice_latitude = 0.82 }
end)
planets.recipe("ocean", function(rng)
  return { nodes = continents(rng:range(1, 1e6)), relief = 7000, sea_level = units.uniform(rng, 0.25, 0.4), ocean = true,
    life = true, palette = EARTHLIKE, ice_latitude = 0.85 }
end)
planets.recipe("eyeball", function(rng)
  return { nodes = continents(rng:range(1, 1e6)), relief = 7000, sea_level = 0.05, ocean = true, life = true,
    palette = EARTHLIKE, ice_latitude = 0.45 }
end)
planets.recipe("super_earth", function(rng, body)
  local living = body.temperature > 250 and body.temperature < 330
  return { nodes = continents(rng:range(1, 1e6)), relief = 6000, sea_level = 0, ocean = living, life = living,
    palette = living and EARTHLIKE or { low = { 0.55, 0.45, 0.35 }, mid = { 0.45, 0.38, 0.32 }, high = { 0.6, 0.55, 0.5 },
      peak = { 0.8, 0.78, 0.75 }, ice = { 0.9, 0.92, 0.95 } }, ice_latitude = 0.85 }
end)
planets.recipe("desert", function(rng)
  local seed = rng:range(1, 1e6)
  return { nodes = { base = { "fbm", frequency = 1.3, octaves = 6, seed = seed },
    mesas = { "terrace", "base", steps = 5, softness = 0.2 },
    dunes = { "scale", { "ridged", frequency = 14, octaves = 2, seed = seed + 1 }, scale = 0.06 },
    height = { "add", { "blend", "base", "mesas", 0.6 }, "dunes" } }, relief = 5000,
    palette = { low = { 0.82, 0.62, 0.38 }, mid = { 0.72, 0.5, 0.31 }, high = { 0.58, 0.4, 0.28 }, peak = { 0.76, 0.66, 0.55 },
      ice = { 0.95, 0.92, 0.9 } }, ice_latitude = 0.95 }
end)
planets.recipe("lava", function(rng)
  local seed = rng:range(1, 1e6)
  return { nodes = { base = { "fbm", frequency = 1.6, octaves = 6, seed = seed },
    rifts = { "scale", { "cells", frequency = 4, edges = true, seed = seed + 1 }, scale = 1.2 },
    height = { "sub", { "scale", "base", scale = 0.5 }, { "smooth", "rifts", edge0 = 0.15, edge1 = 0 } } },
    relief = 4000, sea_level = -0.45, ocean = true,
    palette = { deep = { 1, 0.45, 0.05 }, shallow = { 1, 0.7, 0.2 }, beach = { 0.25, 0.12, 0.08 }, low = { 0.18, 0.13, 0.11 },
      mid = { 0.13, 0.1, 0.09 }, high = { 0.2, 0.16, 0.14 }, peak = { 0.32, 0.27, 0.23 }, ice = { 0.3, 0.3, 0.3 } }, ice_latitude = 2 }
end)
planets.recipe("ice", function(rng)
  local seed = rng:range(1, 1e6)
  return { nodes = { height = { "sub", { "scale", { "billow", frequency = 2, octaves = 5, seed = seed }, scale = 0.3 },
    { "scale", { "smooth", { "cells", frequency = 5, edges = true, seed = seed + 1 }, edge0 = 0.08, edge1 = 0 }, scale = 0.25 } } },
    relief = 3000, palette = { low = { 0.72, 0.8, 0.88 }, mid = { 0.85, 0.9, 0.95 }, high = { 0.93, 0.95, 0.98 },
      peak = grey(0.98), ice = grey(0.97) }, ice_latitude = 2 }
end)
planets.recipe("glacier", function(rng)
  local r = planets.recipes.ice(rng)
  r.palette.low = { 0.55, 0.7, 0.85 } -- blue cracks over the hidden ocean
  return r
end)
for class, look in pairs({ barren = { 0.42, 0.4, 0.38 }, iron = { 0.4, 0.33, 0.3 }, carbon = { 0.14, 0.13, 0.13 },
  shattered = { 0.35, 0.3, 0.28 } }) do
  planets.recipe(class, function(rng)
    local c = look
    return { nodes = cratered(rng:range(1, 1e6), class == "shattered"), relief = class == "shattered" and 15000 or 6000,
      palette = { low = { c[1] * 0.8, c[2] * 0.8, c[3] * 0.8 }, mid = c, high = { c[1] * 1.2, c[2] * 1.2, c[3] * 1.2 },
        peak = { c[1] * 1.4, c[2] * 1.4, c[3] * 1.4 }, ice = grey(0.9) }, ice_latitude = 0.95 }
  end)
end
local GIANTS = { gas_giant = { { 0.85, 0.72, 0.55 }, { 0.65, 0.48, 0.35 }, { 0.75, 0.7, 0.65 } },
  hot_jupiter = { { 0.45, 0.25, 0.18 }, { 0.3, 0.15, 0.12 }, { 0.5, 0.35, 0.3 } },
  ice_giant = { { 0.5, 0.7, 0.88 }, { 0.42, 0.6, 0.82 }, { 0.6, 0.78, 0.92 } },
  mini_neptune = { { 0.6, 0.8, 0.88 }, { 0.5, 0.7, 0.8 }, { 0.7, 0.85, 0.92 } } }
for class, c in pairs(GIANTS) do
  planets.recipe(class, function(rng)
    local seed = rng:range(1, 1e6)
    return { nodes = { turbulence = { "warp", { "fbm", frequency = 3, octaves = 4, seed = seed },
      { "fbm", frequency = 2, octaves = 2, seed = seed + 1 }, strength = 0.5 } }, relief = 0, bands = true,
      palette = { low = c[1], mid = c[2], high = c[3] } }
  end)
end

-- Air: Rayleigh scattering per metre at sea level (RGB) for 1 bar, Mie, absorption (ozone-like), scale height (m).
local AIR = {
  n2o2 = { rayleigh = { 5.8e-6, 13.5e-6, 33.1e-6 }, mie = 4e-6, absorb = { 0.65e-6, 1.88e-6, 0.08e-6 }, height = 8000 },
  n2co2 = { rayleigh = { 6.5e-6, 13e-6, 28e-6 }, mie = 6e-6, absorb = { 0, 0, 0 }, height = 9000 },
  n2 = { rayleigh = { 5.5e-6, 12.5e-6, 30e-6 }, mie = 3e-6, absorb = { 0, 0, 0 }, height = 8000 },
  co2 = { rayleigh = { 19e-6, 13.5e-6, 5.8e-6 }, mie = 12e-6, absorb = { 0, 0.5e-6, 1.5e-6 }, height = 11000 },
  sulfur = { rayleigh = { 20e-6, 18e-6, 6e-6 }, mie = 20e-6, absorb = { 0, 0.4e-6, 2.5e-6 }, height = 12000 },
  n2ch4 = { rayleigh = { 16e-6, 11e-6, 4e-6 }, mie = 25e-6, absorb = { 0, 0.3e-6, 1.2e-6 }, height = 20000 },
  co = { rayleigh = { 10e-6, 9e-6, 7e-6 }, mie = 15e-6, absorb = { 0, 0.2e-6, 0.8e-6 }, height = 10000 },
  h2he = { rayleigh = { 4e-6, 9e-6, 22e-6 }, mie = 3e-6, absorb = { 0.5e-6, 0.2e-6, 0 }, height = 27000 },
}
planets.AIR = AIR

local CLOUDY = { terran = 0.5, ocean = 0.6, eyeball = 0.45, super_earth = 0.35, glacier = 0.25, desert = 0.06, lava = 0.25 }

-- The descriptor of a body: its surface (an fk.planet), air optics, clouds and colour grading. Same body, same result.
function planets.describe(body)
  local rng = fk.rng("planet", body.seed)
  local build = planets.recipes[body.class] or planets.recipes.barren
  local r = build(rng, body)
  local seed = rng:range(1, 1e6)
  local def = { radius = body.radius, relief = r.relief, sea_level = r.sea_level or 0, ocean = r.ocean, life = r.life,
    bands = r.bands, temperature = body.temperature, ice_latitude = r.ice_latitude or 0.9, palette = r.palette,
    height = fk.noise.graph({ nodes = r.nodes, output = r.bands and "turbulence" or "height" }, body.seed) }
  if r.life then
    def.moisture = fk.noise.graph({ nodes = { m = { "fbm", frequency = 1.7, octaves = 4, seed = seed } }, output = "m" }, body.seed)
  end
  local air = body.atmosphere
  local cloud = air and CLOUDY[body.class]
  if cloud then
    def.clouds = fk.noise.graph({ nodes = { c = { "warp", { "fbm", frequency = 2.5, octaves = 5, seed = seed + 1 },
      { "fbm", frequency = 1.5, octaves = 2, seed = seed + 2 }, strength = 0.4 } }, output = "c" }, body.seed)
    def.cloud_cover = cloud
  end
  local d = { class = body.class, radius = body.radius, relief = r.relief, surface = fk.planet.new(def), bands = r.bands,
    rings = body.rings, cloud_cover = def.cloud_cover, ocean = r.ocean }
  if air then
    local o = AIR[air.gas] or AIR.n2
    local p = math.min(air.pressure, 50) -- deeper air than that looks the same from outside
    d.atmosphere = { gas = air.gas, pressure = air.pressure, height = o.height,
      rayleigh = { o.rayleigh[1] * p, o.rayleigh[2] * p, o.rayleigh[3] * p }, mie = o.mie * p,
      absorb = { o.absorb[1] * p, o.absorb[2] * p, o.absorb[3] * p }, top = body.radius + o.height * 8 }
  end
  d.grading = { saturation = r.life and 1.1 or 0.95, contrast = 1.05 }
  return d
end

return planets
