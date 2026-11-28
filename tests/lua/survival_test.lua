-- environment.lua, survival.lua, ecology.lua and fire.lua (environment-model, exosuit-survival, death-modes, ecology,
-- creature-generation, fire-and-destruction and defensive-tools specs).
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local chain = require("chain")
local sensors = require("sensors")
local environment = require("environment")
local survival = require("survival")
local ecology = require("ecology")
local fire = require("fire")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  sim.step(game)
end

local function step(n)
  for _ = 1, n or 1 do sim.step(game) end
end

local function suit() return chain.suit() end

return {
  ["the environment: zones, gas, radiation, vents and fire"] = function()
    start()
    local key = sensors.state().world
    local zones = environment.zones(key)
    assert(#zones == environment.ZONES and environment.zones(key) == zones, "made once per world")
    local z = zones[1]
    assert(environment.at(z.x, z.z).toxin >= z.toxin, "inside a toxic zone")
    local e0 = environment.at(0, 0)
    sensors.place("gas_pocket", 5000, 5000, 0.2)
    sensors.place("radiation", 5100, 5000, 0.1)
    sensors.place("vent", 5200, 5000, 4)
    assert(environment.at(5000, 5000).toxin > e0.toxin)
    assert(environment.at(5100, 5000).radiation > e0.radiation)
    assert(environment.at(5200, 5000).temperature > e0.temperature)
    fire.ignite(5300, 5000)
    assert(environment.at(5300, 5000).fire == 1 and environment.at(5300, 5000).temperature > e0.temperature + 500)
  end,
  ["the suit's systems run down outside and come back inside"] = function()
    start()
    local s = survival.state()
    local real = environment.at
    environment.at = function() -- a cold, airless, poisonous, radioactive place
      return { temperature = 100, pressure = 0, breathable = false, toxin = 1, radiation = 1, fire = 1 }
    end
    step(60)
    assert(s.oxygen < 1 and s.filter < 1 and s.power < 1 and s.dose > 0 and s.integrity < 1)
    s.filter, s.power, s.oxygen = 0, 0, 0
    local before = s.integrity
    step(60)
    assert(s.integrity < before - 0.05, "breached without filter, power and air")
    environment.at = real
    local lines = survival.lines()
    assert(#lines == 3 and lines[1]:find("O2", 1, true))
    sim.send("board", { id = chain.up() })
    step(60 * survival.RESTORE)
    assert(s.oxygen == 1 and s.filter == 1 and s.power == 1 and s.integrity == 1, "restored inside the Walker")
  end,
  ["death: clone mode wakes in the clone bay; legacy ends the run and fills the codex"] = function()
    fk.storage.save("codex", "")
    start()
    local s = survival.state()
    s.mode = "clone"
    sensors.state().contacts.h1 = { id = 1, kind = "vent", tick = 0, x = 0, z = 0, size = 1 }
    survival.hurt(2)
    step()
    assert(s.deaths == 1 and chain.walking() and chain.current().kind == "jump_ship" and s.integrity == 1)
    start()
    s = survival.state()
    sim.send("mode", { mode = "legacy" })
    step(survival.CHECK)
    sensors.state().contacts.h1 = { id = 1, kind = "vent", tick = 0, x = 0, z = 0, size = 1 }
    step(survival.CHECK)
    survival.hurt(2)
    step()
    assert(s.over, "the run ended")
    local codex = survival.codex()
    assert(codex.commanders == 1 and codex.hazards.vent and survival.codex_size(codex) >= 2)
    step(10)
    assert(s.over and s.deaths == 1, "nothing goes on after the end")
    fk.storage.save("codex", "{")
    assert(survival.codex().commanders == 0, "a broken codex is an empty one")
    survival.save_setting({ death = "legacy" })
    assert(survival.setting().death == "legacy")
    survival.save_setting({ death = "clone" })
  end,
  ["a sinkhole gives way under a doll or the suit"] = function()
    start()
    local walker
    for _, d in ipairs(chain.state().dolls) do
      if d.kind == "walker" then walker = d end
    end
    local h = sensors.place("sinkhole", walker.x, walker.z, 40)
    step(survival.CHECK)
    assert(h.collapsed and walker.damage == 0.4, "the Walker fell in")
    local p = suit()
    local h2 = sensors.place("sinkhole", p.x, p.z, 20)
    local before = survival.state().integrity
    step(survival.CHECK)
    assert(h2.collapsed and survival.state().integrity < before, "the suit fell in")
  end,
  ["species, herds and packs from the seed; behaviours; stun and flares"] = function()
    start()
    local key = sensors.state().world
    local a, b = ecology.species(key), ecology.species(key)
    assert(a.grazer.name == b.grazer.name and a.predator.legs == b.predator.legs, "the same every time")
    assert(ecology.species("x/1").grazer.name ~= a.grazer.name or ecology.species("x/1").grazer.length ~= a.grazer.length)
    local grazers, predators = 0, 0
    for _, h in ipairs(sensors.hazards()) do
      if h.kind == "grazer" then grazers = grazers + 1 end
      if h.member and h.kind == "predator" then predators = predators + 1 end
    end
    assert(grazers == 15 and predators == 6)
    local p = suit()
    local g = sensors.place("grazer", p.x + 200, p.z, 1.5)
    local threat = sensors.place("predator", p.x + 210, p.z, 2)
    local x = g.x
    step(ecology.THINK * 5)
    assert(g.x < x, "the grazer flees the predator")
    local hunter = sensors.place("predator", p.x, p.z + 1, 2)
    step(ecology.THINK * 3)
    assert(hunter.hunting and survival.state().integrity < 1, "it noticed and bit")
    sim.send("stun", {})
    step()
    assert(hunter.stunned and hunter.stunned > sim.tick, "stunned")
    local hx = hunter.x
    step(ecology.THINK * 2)
    assert(hunter.x == hx, "a stunned predator does not move")
    sim.send("stun", {})
    step()
    assert(sim.tick < ecology.state().stun_at, "cooling down")
    sim.send("flare", {})
    step()
    assert(#ecology.state().decoys == 1)
    step(math.floor(ecology.DECOY.life / sim.dt) + ecology.THINK)
    assert(#ecology.state().decoys == 0, "burnt out")
    sim.send("board", { id = chain.up() })
    step()
    sim.send("flare", {})
    step()
    assert(#ecology.state().decoys == 1, "fired from the seat too")
    assert(threat.kind == "predator" and ecology.draw({}, { p.x, p.y, p.z }, 0) > 0, "drawn")
  end,
  ["fire spreads through dry plants, burns out, and sets off gas"] = function()
    start()
    local real = fire.dryness
    fire.dryness = function() return 1 end
    local p = suit()
    local gas = sensors.place("gas_pocket", p.x + fire.CELL * 2, p.z, 0.2)
    assert(fire.ignite(p.x + fire.CELL * 2, p.z) and not fire.ignite(p.x + fire.CELL * 2, p.z), "lit once")
    step(fire.SPREAD * 3)
    local n = 0
    for _ in pairs(fire.state().cells) do n = n + 1 end
    assert(n > 1, "it spread")
    assert(gas.gone, "the gas pocket exploded")
    assert(fire.draw({ p.x, p.y, p.z }, 1 / 60, 0) > 0)
    step(math.floor(fire.BURN / sim.dt) + fire.SPREAD * 2)
    assert(next(fire.state().ash) ~= nil, "ash")
    fire.dryness = real
    assert(fire.dryness() >= 0)
    fire.tick("another/world", function() end)
    assert(next(fire.state().cells) == nil, "fires are of a world")
  end,
}
