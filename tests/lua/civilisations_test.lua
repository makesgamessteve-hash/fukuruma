-- factions.lua, settlements.lua, dialogue.lua, artifacts.lua and thieves.lua (M11 specs).
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local chain = require("chain")
local sensors = require("sensors")
local factions = require("factions")
local settlements = require("settlements")
local dialogue = require("dialogue")
local artifacts = require("artifacts")
local thieves = require("thieves")
local survival = require("survival")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  sim.step(game)
end

local function step(n)
  for _ = 1, n or 1 do sim.step(game) end
end

local function find(kind)
  for _, d in ipairs(chain.state().dolls) do
    if d.kind == kind then return d end
  end
end

local function natives()
  local out = {}
  for _, h in ipairs(sensors.hazards()) do
    if h.kind == "native" then out[#out + 1] = h end
  end
  return out
end

return {
  ["factions from the seed; reputation moves the attitude"] = function()
    start()
    local key = sensors.state().world
    local a, b = factions.of(key), factions.of(key)
    assert(a.natives.name == b.natives.name and a.spacefarers.id:find("#spacefarers", 1, true))
    local f = a.thieves
    assert(factions.attitude(f) == factions.ATTITUDES[f.base] and factions.reputation(f) == 0)
    factions.change(f, 200)
    assert(factions.reputation(f) == 100 and factions.attitude(f) == "trading")
    factions.change(f, -400)
    assert(factions.reputation(f) == -100 and factions.attitude(f) == "hostile")
  end,
  ["settlements and their natives; hostile natives throw spears"] = function()
    start()
    assert(settlements.habitable() and #natives() == settlements.PER_WORLD * settlements.NATIVES)
    local places = settlements.of(sensors.state().world)
    assert(#places == settlements.PER_WORLD and #places[1].buildings >= 5)
    local n = natives()[1]
    local x = n.x
    step(settlements.THINK * 20)
    assert(n.x ~= x or n.stride > 0, "they walk about")
    assert(settlements.draw({}, { places[1].x, 0, places[1].z }) >= 1)
    factions.change(settlements.faction(), -200)
    chain.move_suit(n.x + 2, chain.ground(n.x + 2, n.z), n.z)
    local before = survival.state().integrity
    step(settlements.THINK * 3)
    assert(survival.state().integrity < before, "a spear")
  end,
  ["a talk: options by attitude, effects, the end"] = function()
    start()
    local n = natives()[1]
    chain.move_suit(n.x + 2, chain.ground(n.x + 2, n.z), n.z)
    step(2)
    assert(chain.use_hint():find("TALK TO", 1, true))
    sim.send("use", {})
    step()
    assert(dialogue.open() and dialogue.text():find(settlements.faction().name, 1, true))
    assert(#dialogue.options() == 4, "ruins, thieves, trade, goodbye")
    sim.send("choose", { option = 9 })
    step()
    assert(dialogue.open(), "no such option: nothing happens")
    sim.send("choose", { option = 2 }) -- the thieves
    step()
    assert(sensors.state().contacts["told-hideout"], "the hideout is told")
    sim.send("choose", { option = 1 })
    step()
    assert(not dialogue.open())
    dialogue.state().open = { tree = "natives", node = "peace" }
    factions.change(settlements.faction(), -200)
    assert(#dialogue.options() == 1, "the ruin is not told to the hostile")
    for _, name in ipairs({ "respect", "gift", "insult" }) do dialogue.EFFECTS[name](settlements.faction()) end
    assert(dialogue.draw(480, 270))
    dialogue.state().open = nil
    assert(not dialogue.draw(480, 270) and dialogue.text() == nil and #dialogue.options() == 0)
  end,
  ["the ruin: glyphs, a wrong pylon, the guardian, the right order"] = function()
    start()
    local key = sensors.state().world
    local site = artifacts.of(key)
    table.sort({ table.unpack(site.order) })
    for i = 1, 3 do assert(site.order[artifacts.glyphs(site, i)] == i) end
    artifacts.wake(site.order[3], site, key)
    local pr = artifacts.progress(key)
    assert(pr.guard > sim.tick and pr.step == 0)
    chain.move_suit(site.x, chain.ground(site.x, site.z), site.z)
    local before = survival.state().integrity
    step(math.floor(artifacts.GUARD.every / sim.dt) + 1)
    assert(survival.state().integrity < before, "the guardian's pulse")
    for _, i in ipairs(site.order) do artifacts.wake(i, site, key) end
    assert(pr.solved)
    artifacts.wake(1, site, key)
    assert(pr.solved, "solved stays solved")
    step(survival.CHECK)
    assert(survival.state().found.artifacts[key], "into the codex's finds")
    assert(artifacts.draw({}, { site.x, 0, site.z }, 0) == 1 and artifacts.draw({}, { 1e6, 0, 1e6 }, 0) == 0)
  end,
  ["thefts, recovery, boarding, sealing"] = function()
    start()
    local le = find("land_explorer")
    assert(not thieves.steal(find("jump_ship")), "only dolls on the ground")
    assert(thieves.steal(le) and not thieves.steal(le))
    sim.send("board", { id = le.id })
    step()
    assert(chain.current() ~= le, "a stolen doll cannot be boarded")
    step(120)
    local list = thieves.stolen_list(0, 0)
    assert(#list == 1 and list[1].doll == le)
    chain.move_suit(le.x + 5, chain.ground(le.x + 5, le.z), le.z)
    step()
    sim.send("use", {})
    step()
    assert(le.stolen == nil)
    local ship = find("jump_ship")
    chain.state().at = ship.id
    local p = thieves.board(ship)
    sim.send("seal", {})
    step()
    assert(not chain.door_open("jump_ship")("cargo deck"))
    step(math.floor((thieves.PATIENCE + 120) / sim.dt)) -- (the walk to the cargo deck, then the wait)
    assert(#thieves.state().parties == 0 and not ship.looted and p.waited >= thieves.PATIENCE)
    chain.state().at = find("walker").id
    thieves.state().raid_at = sim.tick
    step(thieves.CHECK)
    assert(thieves.state().raids >= 1, "a raid came")
    chain.state().walk = { doll = ship.id, x = 0, z = 2 }
    thieves.board(ship)
    assert(thieves.draw({}, chain.interior_frame) == 3)
  end,
}
