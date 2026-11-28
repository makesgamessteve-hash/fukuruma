-- star-systems and wonder-director specs: 10,000 generated systems keep their promises (stable orbits, moons in their
-- Hill spheres, rings inside the Roche zone), every archetype and planet class appears, every system has a marvel,
-- marvels keep their rarity (within 20%), and the systems are the same on every platform.
local systems = require("gen.systems")
local checks = require("gen.checks")
local galaxy = require("fk.galaxy")
local wonders = require("gen.wonders")

local RECORDED_HASH = "6714788dfb5f02b4"
local COUNT = 10000

local function encode(v, out) -- a canonical text of plain data (sorted keys, exact numbers)
  local t = type(v)
  if t == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      if type(a) ~= type(b) then return type(a) == "number" end
      return a < b
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      encode(k, out)
      encode(v[k], out)
    end
    out[#out + 1] = "}"
  elseif t == "number" then out[#out + 1] = string.pack("<d", v)
  else out[#out + 1] = tostring(v) end
end

return scenario {
  seed = 1,
  timeout_s = 120,
  run = function(t)
    local stars, sx = {}, 0
    while #stars < COUNT do -- sectors along the Sun's circle
      for _, s in ipairs(galaxy.sector(812 + sx, 0, 0)) do
        if #stars < COUNT then stars[#stars + 1] = s end
      end
      sx = sx + 1
    end
    local archetypes, classes, planets, h = {}, {}, 0, 0
    local eligible, placed, signatures = {}, {}, 0
    local digest = {}
    for i, star in ipairs(stars) do
      local sys = systems.generate(star)
      local broken = checks.system(sys)
      if broken then t.expect(false, sys.name .. " (" .. sys.archetype .. "): " .. broken) end
      archetypes[sys.archetype] = (archetypes[sys.archetype] or 0) + 1
      if #sys.marvels == 0 then t.expect(false, sys.name .. " has no marvel") end
      for _, def in ipairs(wonders.list) do
        if #def.candidates(sys) > 0 then eligible[def.id] = (eligible[def.id] or 0) + 1 end
      end
      for _, m in ipairs(sys.marvels) do
        if not m.guaranteed then placed[m.id] = (placed[m.id] or 0) + 1 end
      end
      if sys.signature then signatures = signatures + 1 end
      for _, b in ipairs(sys.bodies) do
        classes[b.class] = (classes[b.class] or 0) + 1
        if b.kind == "planet" then planets = planets + 1 end
      end
      if i <= 200 then encode(sys, digest) end
    end
    for _, id in ipairs(systems.order) do t.expect((archetypes[id] or 0) > 0, "archetype " .. id .. " appears") end
    for _, c in ipairs(require("gen.planet_classes").list) do t.expect((classes[c.id] or 0) > 0, "class " .. c.id .. " appears") end
    t.expect(#wonders.list >= 10, "at least ten marvels")
    for _, def in ipairs(wonders.list) do
      local n, k = eligible[def.id] or 0, placed[def.id] or 0
      -- note: a marvel's effect can make another eligible (polar rings), so eligibility is counted after curation
      if n * def.rarity >= 100 then
        t.expect(math.abs(k / n - def.rarity) <= 0.2 * def.rarity,
          string.format("%s: %d of %d eligible systems, %.4f against %.4f", def.id, k, n, k / n, def.rarity))
      end
      print(string.format("marvel %-20s %5d of %5d eligible", def.id, k, n))
    end
    t.expect(signatures > COUNT / 10, "unusual signatures show on the galaxy map")
    print(string.format("%d systems, %d planets, %d with unusual signatures", COUNT, planets, signatures))
    for _, c in ipairs(require("gen.planet_classes").list) do print(c.id, classes[c.id] or 0) end
    h = string.format("%016x", fk.hash(table.concat(digest)))
    print("systems hash " .. h)
    t.expect(h == RECORDED_HASH, "the systems hash differs from the recorded one")
  end,
}
