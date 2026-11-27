-- gen/wonders.lua (wonder-director spec).
local wonders = require("gen.wonders")
local systems = require("gen.systems")
local galaxy = require("fk.galaxy")

local function plain_system()
  return { seed = 77, name = "Test", stars = { { kind = "star" } }, bodies = {}, belts = {}, marvels = {} }
end

return {
  ["every system gets a marvel and a score"] = function()
    local with_signature = 0
    for i, s in ipairs(galaxy.near(fk.galaxy.HOME, 25)) do
      local sys = systems.generate(s)
      assert(#sys.marvels >= 1 and sys.interest > 0)
      for _, m in ipairs(sys.marvels) do
        assert(wonders.by_id[m.id] and m.where)
        if m.body > 0 then
          local found = false
          for _, id in ipairs(sys.bodies[m.body].marvels) do found = found or id == m.id end
          assert(found, "the body knows its marvel")
        end
      end
      if sys.signature then with_signature = with_signature + 1 end
      if i > 120 then break end
    end
    assert(with_signature > 0)
  end,
  ["an empty system still gets one, from the fallbacks"] = function()
    local sys = wonders.curate(plain_system())
    assert(#sys.marvels == 1 and sys.marvels[1].guaranteed and wonders.by_id[sys.marvels[1].id].fallback)
    assert(sys.signature == nil, "faint marvels do not show on the map")
  end,
  ["every marvel's effect applies"] = function()
    local sys = systems.generate(galaxy.home_star())
    for _, def in ipairs(wonders.list) do
      local list = def.candidates(sys)
      if #list > 0 and def.apply then def.apply(sys, list[1], fk.rng("apply", def.id)) end
    end
    local giant = { name = "G", kind = "planet", class = "gas_giant", mass = 300, radius = 7e7, rings = { inner = 9e7, outer = 1.5e8 },
      orbit = { a = 7e11, e = 0, mu = 1.3e20 } }
    local fake = plain_system()
    fake.bodies = { giant, { name = "G I", kind = "moon", class = "ice", parent = 1, mass = 0.01, radius = 1e6, temperature = 90,
      atmosphere = { gas = "n2ch4" }, orbit = { a = 3e8, e = 0, mu = 1e17 } } }
    fake.pulsar, fake.archetype = { period = 1 }, "black_hole"
    for _, def in ipairs(wonders.list) do
      local list = def.candidates(fake)
      if #list > 0 and def.apply then def.apply(fake, list[1], fk.rng("apply", def.id)) end
    end
    assert(giant.rings.crossing and giant.storm and fake.pulsar.sweeps == 1 and fake.dyson)
    fake.archetype = "close_binary"
    assert(#wonders.by_id.binary_sunset.candidates(fake) == 0, "only rocky worlds see the binary sunset")
  end,
  ["marvels are a registry"] = function()
    assert(#wonders.list >= 10)
    assert(not pcall(wonders.register, { id = "polar_ring", rarity = 1, candidates = function() return {} end }))
    assert(not pcall(wonders.register, { id = "test_x" }))
  end,
}
