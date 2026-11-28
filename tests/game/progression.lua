-- research, trading, crafting, outposts and codex specs: a grazer's sample researched into bio-sensors lets the
-- Exosuit see a predator it could not; a good bought cheap at one settlement sells for more at the other; an outpost
-- built and given a power module is the same after a jump away and back; a species found gets a name in the codex.
local sim = require("fk.sim")

local function press(t, key, frames)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(frames or 1)
end

local function steps(game, n)
  for _ = 1, n do sim.step(game) end
end

return scenario {
  seed = 1,
  timeout_s = 300,
  run = function(t)
    local game = require("game")
    local chain = require("chain")
    local sensors = require("sensors")
    local economy = require("economy")
    local research = require("research")
    local dialogue = require("dialogue")
    local universe = require("universe")
    local survival = require("survival")
    fk.storage.save("codex", "")
    t.frames(3)
    local function find(kind)
      for _, d in ipairs(chain.state().dolls) do
        if d.kind == kind then return d end
      end
    end
    local function known(h) return sensors.state().contacts["h" .. h.id] ~= nil end

    -- sample -> research -> sensor upgrade
    local suit = chain.current()
    local far = sensors.place("predator", suit.x + 160, suit.z, 2.5)
    steps(game, sensors.PASSIVE * 2)
    t.expect(not known(far), "160 m off, the suit cannot see the predator")
    sensors.state().contacts = {} -- (and nothing else told it)
    local g = sensors.place("grazer", suit.x + 2, suit.z, 1.2)
    t.frames(2)
    t.expect(chain.use_hint() == "TAKE A SAMPLE: GRAZERS", "a grazer in reach: " .. tostring(chain.use_hint()))
    press(t, "F", 2)
    t.expect(economy.has("grazer") == 1 and g.sampled, "a sample")
    local walker = find("walker")
    sim.send("board", { id = walker.id })
    t.frames(2)
    press(t, "K", 2)
    t.expect(dialogue.open() and dialogue.open().tree == "workshop", "the workshop")
    press(t, "2", 2) -- research
    t.screenshot("progress_lab")
    press(t, "1", 2) -- bio-sensors
    t.expect(research.state().current and research.state().current.id == "bio_sensors", "researching")
    press(t, "4", 1) -- (back, done)
    while dialogue.open() do press(t, tostring(#dialogue.options()), 1) end
    steps(game, 60 * 21)
    t.expect(research.done("bio_sensors"), "researched")
    sim.send("board", { id = chain.down() })
    t.frames(2)
    suit = chain.current()
    far.x, far.z, far.hx, far.hz = suit.x + 160, suit.z, suit.x + 160, suit.z
    steps(game, sensors.PASSIVE * 2)
    t.expect(known(far), "with bio-sensors the suit sees it")

    -- buy low, sell high
    local key = sensors.state().world
    local best, gain = nil, 0
    for i = 1, #economy.GOODS do
      for a = 1, 2 do
        local b = 3 - a
        local d = economy.price(key .. "#" .. b, i, true) - economy.price(key .. "#" .. a, i, false)
        if d > gain then best, gain = { good = i, from = a, to = b }, d end
      end
    end
    t.expect(best ~= nil, "a good worth carrying between the settlements")
    local function trade_at(settlement, choice)
      for _, h in ipairs(sensors.hazards()) do
        if h.kind == "native" and h.settlement == settlement then
          chain.move_suit(h.x + 2, chain.ground(h.x + 2, h.z), h.z)
          break
        end
      end
      t.frames(2)
      press(t, "F", 2)
      press(t, "3", 2) -- trade
      t.expect(dialogue.open() and dialogue.open().tree == "market", "the market")
      while dialogue.open().good ~= best.good do press(t, "1", 1) end
      press(t, choice, 2)
      if choice == "2" then t.screenshot("progress_market") end
      press(t, "4", 2)
    end
    local credits = economy.state().credits
    trade_at(best.from, "2")
    t.expect(economy.has(economy.GOODS[best.good][1]) == 1, "bought")
    trade_at(best.to, "3")
    t.expect(economy.state().credits == credits + gain, "sold for more: " .. economy.state().credits - credits)

    -- an outpost, the same after a jump away and back
    local goods = economy.state().goods
    goods.ore, goods.tools = goods.ore + 4, goods.tools + 1 -- shortcut: the goods for the kit and a module, as bought
    chain.move_suit(walker.x + 30, chain.ground(walker.x + 30, walker.z), walker.z) -- shortcut: back at the Walker
    t.frames(2)
    sim.send("board", { id = walker.id })
    t.frames(2)
    press(t, "K", 2)
    press(t, "1", 2) -- craft
    press(t, "3", 2) -- an outpost kit
    t.expect(economy.state().items.outpost == 1, "an outpost kit")
    while dialogue.open() do press(t, tostring(#dialogue.options()), 1) end
    sim.send("board", { id = chain.down() })
    t.frames(2)
    press(t, "H", 3)
    local outpost = economy.state().outposts[key]
    t.expect(outpost ~= nil, "an outpost")
    press(t, "K", 2)
    press(t, "3", 2) -- outpost modules
    press(t, "1", 2) -- power
    t.expect(outpost.modules.power, "a power module")
    while dialogue.open() do press(t, tostring(#dialogue.options()), 1) end
    local p = sim.get(game.suit, "suit")
    chain.move_suit(outpost.x - 25, chain.ground(outpost.x - 25, outpost.z), outpost.z) -- stepping back to look
    game.helmet.yaw, game.helmet.pitch = math.pi / 2, 0.15
    t.frames(4)
    t.screenshot("progress_outpost")
    local before = sim.hash()
    local saved = { x = outpost.x, z = outpost.z }
    local ship = find("jump_ship")
    chain.state().at, chain.state().walk = ship.id, nil
    local home, sector, target = universe.state().seed, universe.state().sector, nil
    for _, s in ipairs(require("fk.galaxy").near(universe.view().star.position, universe.RANGE)) do
      if s.seed ~= home then target = s break end
    end
    sim.send("jump", { sector = target.sector, seed = target.seed })
    steps(game, 120)
    t.expect(universe.state().seed == target.seed and sensors.state().world ~= key, "away in another system")
    sim.send("jump", { sector = sector, seed = home })
    steps(game, 120)
    local back = economy.state().outposts[sensors.state().world]
    t.expect(sensors.state().world == key and back and back.x == saved.x and back.z == saved.z and back.modules.power,
      "back home, the outpost is as it was")
    t.expect(before ~= sim.hash(), "(time went on)")

    -- the codex: a species found gets a name
    chain.state().at = find("exosuit") and find("exosuit").id or walker.id
    steps(game, survival.CHECK)
    press(t, "X", 2)
    t.expect(dialogue.open() and dialogue.open().tree == "codex", "the codex")
    t.screenshot("progress_codex")
    press(t, "1", 2) -- name the first species found
    press(t, "1", 2) -- the first name offered
    t.expect(next(survival.codex().names) ~= nil, "a species named, kept in the codex")
    print("progression state hash " .. sim.hash())
  end,
}
