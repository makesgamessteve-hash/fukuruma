-- Checks a system descriptor for the rules the generator promises (star-systems spec); used by tests and mods.
-- Returns nil, or a message naming the first broken rule.
local units = require("gen.units")

local checks = {}

local function hill(b, host_mass_kg)
  return b.orbit.a * (1 - b.orbit.e) * units.cbrt(b.mass * units.EARTH_MASS / (3 * host_mass_kg))
end

function checks.system(sys)
  local groups = {}
  for i, b in ipairs(sys.bodies) do
    if b.orbit then
      local ok, err = pcall(fk.orbit.period, b.orbit)
      if not ok then return b.name .. ": " .. err end
    end
    if b.kind == "planet" and b.orbit then
      local key = b.around .. b.parent
      groups[key] = groups[key] or {}
      table.insert(groups[key], b)
    elseif b.kind == "moon" and sys.bodies[b.parent].orbit then
      local p = sys.bodies[b.parent]
      local host = p.orbit.mu / units.G - p.mass * units.EARTH_MASS
      if b.orbit.a * (1 + b.orbit.e) > 0.5 * hill(p, host) then return b.name .. " is outside half its planet's Hill sphere" end
      if b.orbit.a * (1 - b.orbit.e) < p.radius * 2 then return b.name .. " grazes its planet" end
    end
    if b.rings then
      if b.rings.inner <= b.radius or b.rings.outer > 2.5 * b.radius then return b.name .. "'s rings are outside the Roche zone" end
      for _, m in ipairs(sys.bodies) do
        if m.kind == "moon" and m.parent == i and m.orbit.a * (1 - m.orbit.e) < b.rings.outer then
          return m.name .. " crosses the rings of " .. b.name
        end
      end
    end
  end
  for _, list in pairs(groups) do
    table.sort(list, function(a, b) return a.orbit.a < b.orbit.a end)
    for k = 2, #list do
      local p, q = list[k - 1], list[k]
      local host = p.orbit.mu / units.G
      local rh = units.cbrt((p.mass + q.mass) * units.EARTH_MASS / (3 * host)) * (p.orbit.a + q.orbit.a) / 2
      if q.orbit.a * (1 - q.orbit.e) - p.orbit.a * (1 + p.orbit.e) < 2 * math.sqrt(3) * rh * 0.999 then
        return p.name .. " and " .. q.name .. " are too close to be stable"
      end
    end
  end
  return nil
end

return checks
