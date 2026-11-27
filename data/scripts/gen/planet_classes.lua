-- Planet classes (CONCEPT 4.2): Lua archetypes, checked in order; the first whose rule matches a body's physical
-- facts names its class. Each class also gives its albedo and atmosphere (gas and surface pressure range in bar);
-- M4 adds noise recipes, materials and colour grading. Mods add classes with classes.register (before "barren").
local units = require("gen.units")

local classes = { list = {}, by_id = {} }

-- def: id, rule(p) -> bool, albedo, atmosphere = {gas, lo, hi} (nil: none).
-- p: mass (Earth masses), radius (Earth radii), temperature (K), au, locked, iron, carbon, water (0..1), shattered.
function classes.register(def, before)
  assert(type(def.id) == "string" and type(def.rule) == "function", "a class needs an id and a rule")
  assert(not classes.by_id[def.id], "class '" .. def.id .. "' exists")
  local at = #classes.list + 1
  for i, c in ipairs(classes.list) do
    if c.id == before then at = i end
  end
  table.insert(classes.list, at, def)
  classes.by_id[def.id] = def
end

local function between(x, lo, hi) return x >= lo and x < hi end

local R = classes.register
R({ id = "shattered", albedo = 0.15, rule = function(p) return p.shattered end })
R({ id = "hot_jupiter", albedo = 0.1, atmosphere = { "h2he", 1000, 1000 }, rule = function(p) return p.mass >= 50 and p.temperature > 900 end })
R({ id = "gas_giant", albedo = 0.45, atmosphere = { "h2he", 1000, 1000 }, rule = function(p) return p.mass >= 50 end })
R({ id = "mini_neptune", albedo = 0.35, atmosphere = { "h2he", 100, 500 }, rule = function(p) return between(p.mass, 4, 20) and p.temperature > 250 end })
R({ id = "ice_giant", albedo = 0.3, atmosphere = { "h2he", 300, 1000 }, rule = function(p) return p.mass >= 10 end })
R({ id = "carbon", albedo = 0.08, atmosphere = { "co", 1, 10 }, rule = function(p) return p.carbon end })
R({ id = "lava", albedo = 0.1, atmosphere = { "sulfur", 0.01, 1 }, rule = function(p) return p.temperature > 1000 end })
R({ id = "iron", albedo = 0.12, rule = function(p) return p.temperature > 550 and p.iron end })
R({ id = "eyeball", albedo = 0.3, atmosphere = { "n2co2", 0.3, 3 }, rule = function(p) return p.locked and between(p.temperature, 200, 400) and p.mass < 10 end })
R({ id = "terran", albedo = 0.3, atmosphere = { "n2o2", 0.6, 2 }, rule = function(p) return between(p.temperature, 245, 335) and between(p.water, 0.1, 0.8) and between(p.mass, 0.2, 4) end })
R({ id = "ocean", albedo = 0.25, atmosphere = { "n2co2", 0.8, 4 }, rule = function(p) return between(p.temperature, 255, 380) and p.water >= 0.8 end })
R({ id = "super_earth", albedo = 0.3, atmosphere = { "n2co2", 1, 10 }, rule = function(p) return p.mass >= 2 and between(p.temperature, 200, 600) end })
R({ id = "desert", albedo = 0.35, atmosphere = { "co2", 0.05, 1 }, rule = function(p) return between(p.temperature, 280, 600) end })
R({ id = "glacier", albedo = 0.6, atmosphere = { "n2", 0.1, 1 }, rule = function(p) return between(p.temperature, 140, 255) and p.water > 0.3 end })
R({ id = "ice", albedo = 0.65, atmosphere = { "n2ch4", 0, 0.5 }, rule = function(p) return p.temperature < 200 end })
R({ id = "barren", albedo = 0.12, rule = function() return true end })

function classes.classify(p)
  for _, c in ipairs(classes.list) do
    if c.rule(p) then return c end
  end
end

-- The atmosphere of a body of a class: {gas, pressure} or nil.
function classes.atmosphere(class, rng)
  local a = class.atmosphere
  if not a or a[3] <= 0 then return nil end
  return { gas = a[1], pressure = units.log_uniform(rng, a[2] > 0 and a[2] or 0.001, a[3]) }
end

return classes
