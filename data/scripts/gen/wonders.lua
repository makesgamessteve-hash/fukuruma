-- The Wonder Director (CONCEPT 4.3): after physical generation, a curation pass scores each system for interest and
-- places marvels from a registry (mods add their own with wonders.register). Each marvel has a rarity (the share of
-- eligible systems that get it), a prerequisite, an effect on the descriptor and a scanner signature. Every system
-- gets at least one marvel, and its strongest signature shows on the galaxy map as an "unusual signature".
local units = require("gen.units")

local wonders = { list = {}, by_id = {} }

-- def: id, name, rarity (0..1 of eligible systems), signature (1 faint .. 5 unmistakable),
-- candidates(sys) -> list of body indices (or {0} for the whole system), apply(sys, index, rng) (optional),
-- fallback (may be given to a system that rolled nothing).
function wonders.register(def)
  assert(type(def.id) == "string" and def.rarity and def.candidates, "a marvel needs an id, a rarity and candidates")
  assert(not wonders.by_id[def.id], "marvel '" .. def.id .. "' exists")
  wonders.list[#wonders.list + 1] = def
  wonders.by_id[def.id] = def
end

local function bodies(sys, test)
  local list = {}
  for i, b in ipairs(sys.bodies) do
    if test(b, i) then list[#list + 1] = i end
  end
  return list
end

local function class_is(...)
  local set = {}
  for _, c in ipairs({ ... }) do set[c] = true end
  return function(sys) return bodies(sys, function(b) return set[b.class] end) end
end

local function mark(sys, i, key, value)
  if i > 0 then sys.bodies[i][key] = value else sys[key] = value end
end

local W = wonders.register
W({ id = "ring_crossing_moon", name = "Moon through the rings", rarity = 0.3, signature = 3,
  candidates = function(sys)
    return bodies(sys, function(b, i)
      if not b.rings then return false end
      for _, m in ipairs(sys.bodies) do if m.kind == "moon" and m.parent == i then return true end end
      return false
    end)
  end,
  apply = function(sys, i, rng)
    local p = sys.bodies[i]
    p.rings.gaps = rng:range(1, 3) -- shepherd gaps where the moon's resonances clear the ring
    p.rings.crossing = true
  end })
W({ id = "polar_ring", name = "Polar ring", rarity = 0.04, signature = 3,
  candidates = function(sys) return bodies(sys, function(b) return b.kind == "planet" and b.mass > 0.5 and b.orbit end) end,
  apply = function(sys, i, rng)
    local p = sys.bodies[i]
    p.rings = p.rings or { inner = p.radius * 1.4, outer = p.radius * 2.2, opacity = units.uniform(rng, 0.4, 0.9) }
    p.rings.polar = true
  end })
W({ id = "twilight_life", name = "Life on the twilight band", rarity = 0.2, signature = 4, candidates = class_is("eyeball"),
  apply = function(sys, i) sys.bodies[i].life = "twilight" end })
W({ id = "glass_desert", name = "Glass desert", rarity = 0.1, signature = 2, candidates = class_is("desert"),
  apply = function(sys, i) mark(sys, i, "surface", "glass") end })
W({ id = "crystal_forest", name = "Crystal forests", rarity = 0.06, signature = 3, candidates = class_is("barren", "ice", "glacier"),
  apply = function(sys, i) mark(sys, i, "surface", "crystal") end })
W({ id = "living_fragments", name = "Shattered world with air", rarity = 0.5, signature = 5, candidates = class_is("shattered"),
  apply = function(sys, i) sys.bodies[i].atmosphere = { gas = "n2o2", pressure = 0.3 } end })
W({ id = "collision_course", name = "Moon on a collision course", rarity = 0.01, signature = 5,
  candidates = function(sys) return bodies(sys, function(b) return b.kind == "moon" and b.orbit end) end,
  apply = function(sys, i, rng) sys.bodies[i].collision = { days = rng:range(3, 400) } end })
W({ id = "pulsar_beam", name = "Pulsar beam across a world", rarity = 0.6, signature = 4,
  candidates = function(sys) return sys.pulsar and bodies(sys, function(b) return b.kind == "planet" end) or {} end,
  apply = function(sys, i) sys.pulsar.sweeps = i end })
W({ id = "black_hole_lensing", name = "Black hole lensing the sky", rarity = 1, signature = 5,
  candidates = function(sys) return sys.archetype == "black_hole" and { 0 } or {} end })
W({ id = "dead_dyson_swarm", name = "Dead Dyson swarm", rarity = 0.005, signature = 5,
  candidates = function(sys) return sys.stars[1] and sys.stars[1].kind == "star" and { 0 } or {} end,
  apply = function(sys, _, rng) sys.dyson = { radius = units.uniform(rng, 0.5, 2) * units.AU, coverage = units.uniform(rng, 0.1, 0.4) } end })
W({ id = "jump_ship_wreck", name = "Alien Jump Ship wreck", rarity = 0.01, signature = 5,
  candidates = function(sys) return bodies(sys, function(b) return b.kind == "planet" and b.orbit end) end,
  apply = function(sys, i) sys.bodies[i].wreck = true end })
W({ id = "leviathans", name = "Leviathans in the clouds", rarity = 0.05, signature = 4, candidates = class_is("gas_giant"),
  apply = function(sys, i) sys.bodies[i].life = "leviathans" end })
W({ id = "cryovolcanoes", name = "Cryovolcanoes", rarity = 0.1, signature = 2,
  candidates = function(sys) return bodies(sys, function(b) return b.kind == "moon" and (b.class == "ice" or b.class == "glacier") end) end,
  apply = function(sys, i) mark(sys, i, "surface", "cryovolcanic") end })
W({ id = "super_storm", name = "Permanent super-storm", rarity = 0.2, signature = 2, fallback = true,
  candidates = class_is("gas_giant", "ice_giant", "hot_jupiter", "mini_neptune"),
  apply = function(sys, i, rng) sys.bodies[i].storm = { latitude = units.uniform(rng, -0.6, 0.6), size = units.uniform(rng, 0.1, 0.3) } end })
W({ id = "binary_sunset", name = "Binary sunset", rarity = 0.5, signature = 2,
  candidates = function(sys)
    if sys.archetype ~= "close_binary" then return {} end
    return bodies(sys, function(b) return b.kind == "planet" and b.mass < 10 end)
  end })
W({ id = "methane_lakes", name = "Methane lakes", rarity = 0.15, signature = 2, fallback = true,
  candidates = function(sys) return bodies(sys, function(b) return b.atmosphere and b.atmosphere.gas == "n2ch4" and b.temperature < 120 end) end,
  apply = function(sys, i) mark(sys, i, "surface", "methane_lakes") end })
W({ id = "iron_rain", name = "Iron rain", rarity = 0.3, signature = 3, candidates = class_is("hot_jupiter", "lava"),
  apply = function(sys, i) sys.bodies[i].weather = "iron_rain" end })
W({ id = "frozen_tsunami", name = "Frozen tsunami", rarity = 0.05, signature = 3, candidates = class_is("glacier", "ocean"),
  apply = function(sys, i) mark(sys, i, "surface", "frozen_tsunami") end })
W({ id = "fungal_network", name = "Planet-wide fungal network", rarity = 0.1, signature = 4, candidates = class_is("terran", "ocean", "super_earth"),
  apply = function(sys, i) sys.bodies[i].life = "fungal" end })
W({ id = "great_canyon", name = "A canyon ten times Valles Marineris", rarity = 0.04, signature = 3, fallback = true,
  candidates = class_is("barren", "desert", "iron", "super_earth"),
  apply = function(sys, i) mark(sys, i, "surface", "great_canyon") end })
W({ id = "comet_swarm", name = "Comet swarm", rarity = 0.05, signature = 1, fallback = true,
  candidates = function(sys) return bodies(sys, function(b) return b.kind == "comet" end) end })
W({ id = "strange_echo", name = "A strange sensor echo", rarity = 0, signature = 1, fallback = true,
  candidates = function() return { 0 } end })

-- How interesting a system is: variety of classes, life, and how rare its marvels are.
local function score(sys)
  local classes, s = {}, 0
  for _, b in ipairs(sys.bodies) do
    if not classes[b.class] then
      classes[b.class] = true
      s = s + 1
    end
  end
  for _, m in ipairs(sys.marvels) do
    local def = wonders.by_id[m.id]
    s = s + (def.rarity > 0 and math.min(10, 0.2 / def.rarity) or 0.5)
  end
  return s
end

local function place(sys, def, rng, list, guaranteed)
  local index = list[rng:range(1, #list)]
  if def.apply then def.apply(sys, index, rng) end
  local where = index > 0 and sys.bodies[index].name or sys.name
  sys.marvels[#sys.marvels + 1] = { id = def.id, name = def.name, body = index, where = where, signature = def.signature,
    guaranteed = guaranteed or nil }
  if index > 0 then
    local b = sys.bodies[index]
    b.marvels = b.marvels or {}
    b.marvels[#b.marvels + 1] = def.id
  end
end

-- Curates a generated system: places marvels, guarantees one, scores it and picks its signature.
function wonders.curate(sys)
  sys.marvels = {}
  for _, def in ipairs(wonders.list) do
    local list = def.candidates(sys)
    if #list > 0 then
      local rng = fk.rng("wonder", sys.seed, def.id)
      if rng:chance(def.rarity) then place(sys, def, rng, list) end
    end
  end
  if #sys.marvels == 0 then -- the guarantee: the first fallback marvel this system can hold, picked by its seed
    local options = {}
    for _, def in ipairs(wonders.list) do
      if def.fallback and #def.candidates(sys) > 0 then options[#options + 1] = def end
    end
    local rng = fk.rng("wonder", sys.seed, "guarantee")
    local def = options[rng:range(1, #options)]
    place(sys, def, rng, def.candidates(sys), true)
  end
  local best
  for _, m in ipairs(sys.marvels) do
    if not best or m.signature > best.signature then best = m end
  end
  sys.signature = best.signature >= 4 and best.id or nil -- strong enough to show on the galaxy map
  sys.interest = score(sys)
  return sys
end

return wonders
