-- economy.lua, research.lua and the codex (M12 specs).
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local chain = require("chain")
local sensors = require("sensors")
local economy = require("economy")
local research = require("research")
local dialogue = require("dialogue")
local survival = require("survival")
local universe = require("universe")
local factions = require("factions")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  sim.step(game)
end

local function step(n)
  for _ = 1, n or 1 do sim.step(game) end
end

local function choose(i)
  sim.send("choose", { option = i })
  step()
end

return {
  ["samples: what can be sampled, once"] = function()
    start()
    local p = chain.suit()
    local pred = sensors.place("predator", p.x + 1, p.z, 2)
    step()
    assert(not (chain.use_hint() or ""):find("SAMPLE", 1, true) or (chain.use_hint() or ""):find("PREDATOR", 1, true) == nil,
      "an awake predator is no sample")
    pred.x = p.x + 500
    local v = sensors.place("vent", p.x + 1, p.z, 3)
    assert(chain.use_hint() == "TAKE A SAMPLE: HOT VENT")
    sim.send("use", {})
    step()
    assert(economy.has("vent") == 1 and v.sampled and chain.use_hint() ~= "TAKE A SAMPLE: HOT VENT")
    local q = sensors.place("predator", p.x + 1, p.z + 1, 2)
    q.stunned = sim.tick + 1000
    assert(chain.use_hint() == "TAKE A SAMPLE: PREDATOR", "a stunned one is")
  end,
  ["markets: prices by seed, by trade and by reputation"] = function()
    start()
    local key = sensors.state().world
    local m = key .. "#1"
    local buy, sell = economy.price(m, 1, false), economy.price(m, 1, true)
    assert(sell < buy, "the spread")
    economy.state().deltas[m] = { 5 }
    assert(economy.price(m, 1, false) > buy, "bought from: dearer")
    economy.state().deltas[m] = { -5 }
    assert(economy.price(m, 1, false) < buy, "sold to: cheaper")
    economy.state().deltas[m] = {}
    factions.change(factions.of(key).natives, 100)
    assert(economy.price(m, 1, false) < buy, "a friend's discount")
    dialogue.EFFECTS.market()
    local o = dialogue.open()
    assert(o and o.tree == "market" and dialogue.text():find("MARKET", 1, true))
    choose(1)
    assert(dialogue.open().good == 2)
    local credits = economy.state().credits
    choose(2)
    assert(economy.has("spice") == 1 and economy.state().credits < credits, "bought")
    choose(3)
    assert(economy.has("spice") == 0, "sold")
    choose(3)
    assert(economy.has("spice") == 0, "nothing left to sell")
    economy.state().credits = 0
    choose(2)
    assert(economy.has("spice") == 0, "no money, no goods")
    choose(4)
    assert(not dialogue.open())
  end,
  ["the workshop: crafting, outposts and their modules"] = function()
    start()
    sim.send("workshop", {})
    step()
    assert(not dialogue.open(), "on foot, only at an outpost")
    local s = economy.state()
    s.goods.ore, s.goods.tools, s.goods.spice, s.goods.crystal, s.samples.gas_pocket = 8, 2, 1, 1, 1
    sim.send("board", { id = chain.up() })
    step()
    sim.send("workshop", {})
    step()
    assert(dialogue.open().tree == "workshop" and dialogue.text():find("WORKSHOP", 1, true))
    choose(1)
    assert(dialogue.text():find("FILTER CARTRIDGE", 1, true))
    choose(1) choose(1) choose(2) choose(3)
    assert(s.items.filter == 1 and s.items.repair == 1 and s.items.outpost == 1, "made; the second cartridge could not be")
    choose(4) -- back
    choose(#dialogue.options())
    assert(not dialogue.open())
    sim.send("outpost", {})
    step()
    assert(next(s.outposts) == nil, "not from a seat")
    sim.send("board", { id = chain.down() })
    step()
    sim.send("outpost", {})
    step()
    local o = s.outposts[sensors.state().world]
    assert(o and s.items.outpost == 0)
    sim.send("workshop", {})
    step()
    choose(3) -- modules
    assert(dialogue.text():find("OUTPOST", 1, true))
    choose(1) choose(1) choose(1) choose(1) -- power, storage, pad, scanner (as far as the goods go)
    assert(o.modules.power and o.modules.storage and o.modules.pad and o.modules.scanner)
    choose(1)
    assert(dialogue.open().node == "workshop", "all built: only back")
    choose(#dialogue.options())
    survival.state().oxygen = 0.5
    step(60)
    assert(survival.state().oxygen > 0.5, "the outpost's power restores the suit")
    assert(economy.draw({}, { o.x, 0, o.z }) == 1)
    survival.state().integrity, survival.state().filter = 0.2, 0
    s.items.filter = 1
    step()
    assert(survival.state().integrity > 0.5 and s.items.repair == 0, "a repair kit")
  end,
  ["research: projects, upgrades, the lab"] = function()
    start()
    local s = economy.state()
    assert(not research.start("bio_sensors"), "no samples")
    s.samples.grazer, s.samples.gas_pocket, s.samples.vent, s.samples.exotic = 1, 3, 1, 1
    sim.send("board", { id = chain.up() })
    step()
    sim.send("workshop", {})
    step()
    choose(2)
    assert(dialogue.text():find("LAB", 1, true) and #dialogue.options() == 4)
    choose(1)
    assert(research.state().current.id == "bio_sensors" and dialogue.text():find("RESEARCHING", 1, true))
    assert(not research.start("chemical_mapping"), "one at a time")
    step(math.floor(20 / sim.dt) + 1)
    assert(research.done("bio_sensors"))
    local suite = research.suite("exosuit", require("dolls").by_id.exosuit.sensors)
    assert(suite.range == 300 and suite.resolution == 0.005)
    assert(not research.start("filter_chemistry"), "chemical mapping first")
    assert(research.start("chemical_mapping"))
    step(math.floor(30 / sim.dt) + 1)
    local w = research.suite("walker", require("dolls").by_id.walker.sensors)
    assert(#w.kinds == 5 and w.range == 3000)
    assert(research.start("filter_chemistry"))
    step(math.floor(40 / sim.dt) + 1)
    assert(survival.filter_factor() == 2)
    assert(research.start("drive_tuning"))
    step(math.floor(60 / sim.dt) + 1)
    assert(universe.reach() == universe.RANGE * 1.5 and survival.armour() == 1)
    choose(#dialogue.options())
  end,
  ["the codex: species found, named for good"] = function()
    fk.storage.save("codex", "")
    start()
    survival.state().found.species.ZORBA = true
    local names = survival.names_for("ZORBA")
    assert(#names == 3 and survival.names_for("ZORBA")[1] == names[1])
    sim.send("codex", {})
    step()
    assert(dialogue.text():find("CODEX", 1, true))
    choose(1)
    assert(dialogue.text():find("ZORBA", 1, true))
    choose(2)
    assert(survival.codex().names.ZORBA == names[2] and dialogue.text():find(names[2], 1, true))
    choose(1)
    assert(not dialogue.open())
    sensors.state().contacts.x = { id = 99, kind = "grazer", tick = 0, x = 0, z = 0, size = 1 }
    step(survival.CHECK)
    assert(next(survival.state().found.species) ~= nil)
  end,
}
