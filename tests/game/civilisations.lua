-- factions, native-settlements, dialogue, artifact-sites and thieves-and-boarding specs: thieves take the unattended
-- Land Explorer, whose beacon shows where it goes, and the Commander recovers it on foot; a boarding party loots the
-- Jump Ship's cargo deck, and a second one is stopped by sealed sectors; a native tells of the ruin; at the ruin a
-- wrong pylon wakes the guardian and the right order yields the artifact.
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
    local thieves = require("thieves")
    local artifacts = require("artifacts")
    local dialogue = require("dialogue")
    t.frames(3)
    local function find(kind)
      for _, d in ipairs(chain.state().dolls) do
        if d.kind == kind then return d end
      end
    end

    -- a theft: the next raid is due now; the Land Explorer is left alone
    local le = find("land_explorer")
    thieves.state().raid_at = sim.tick
    steps(game, thieves.CHECK - sim.tick % thieves.CHECK + 1)
    t.expect(le.stolen ~= nil, "thieves took the unattended Land Explorer")
    local x0, z0 = le.x, le.z
    steps(game, 60 * 20)
    t.expect((le.x - x0) ^ 2 + (le.z - z0) ^ 2 > 200 * 200, "driven off towards the hideout")
    local suit = chain.current()
    game.helmet.yaw = math.atan(le.x - suit.x, le.z - suit.z)
    game.helmet.pitch = -0.05
    t.frames(3)
    t.screenshot("civ_stolen_beacon")
    chain.move_suit(le.x + 20, chain.ground(le.x + 20, le.z), le.z) -- shortcut: tracked down by its beacon
    t.frames(2)
    t.expect(chain.use_hint() == "RECOVER THE LAND EXPLORER", "in reach: " .. tostring(chain.use_hint()))
    press(t, "F", 2)
    t.expect(le.stolen == nil, "recovered")

    -- boarding parties on the Jump Ship
    local ship = find("jump_ship")
    chain.state().at, chain.state().walk = ship.id, nil
    t.frames(2)
    thieves.board(ship)
    steps(game, 60 * 90)
    t.expect(ship.looted == 1 and #thieves.state().parties == 0, "unopposed, the boarders looted the cargo deck")
    local party = thieves.board(ship)
    press(t, "L", 2)
    t.expect(not chain.door_open("jump_ship")("cargo deck"), "the sectors are sealed")
    press(t, "F", 2) -- up from the seat, to see them coming
    local w = chain.walking()
    w.x, w.z = 0, party.path[1][2] + 6
    game.helmet.yaw, game.helmet.pitch = math.pi, 0
    steps(game, 60 * 25)
    t.frames(3)
    t.screenshot("civ_boarders")
    steps(game, 60 * (thieves.PATIENCE + 70)) -- (the walk down the corridor to the cargo deck, then the wait)
    t.expect(ship.looted == 1 and #thieves.state().parties == 0, "the sealed cargo deck held; they gave up")

    -- a native tells of the ruin
    chain.state().at, chain.state().walk = find("exosuit") and find("exosuit").id or chain.state().at, nil
    local native
    for _, h in ipairs(sensors.hazards()) do
      if h.kind == "native" and not native then native = h end
    end
    chain.move_suit(native.x + 3, chain.ground(native.x + 3, native.z), native.z)
    t.frames(2)
    t.expect(chain.use_hint() and chain.use_hint():find("TALK TO", 1, true), "a native in reach: " .. tostring(chain.use_hint()))
    game.helmet.yaw, game.helmet.pitch = -math.pi / 2, 0.05
    press(t, "F", 3)
    t.expect(dialogue.open() ~= nil, "talking")
    t.screenshot("civ_talk")
    press(t, "1", 2) -- ask about the ruins
    t.expect(sensors.state().contacts["told-ruin"] ~= nil, "the ruin is on the sensors now")
    press(t, "1", 2)
    t.expect(dialogue.open() == nil, "the talk ended")

    -- the ruin's puzzle
    local key = sensors.state().world
    local site = artifacts.of(key)
    local wrong = site.order[2]
    local function touch(i)
      local p = site.pylons[i]
      chain.move_suit(p.x + 1, chain.ground(p.x + 1, p.z), p.z)
      t.frames(2)
      t.expect(chain.use_hint() == "TOUCH THE PYLON", "a pylon in reach")
      press(t, "F", 2)
    end
    touch(wrong)
    t.expect(artifacts.progress(key).guard > sim.tick, "a wrong pylon wakes the guardian")
    for _, i in ipairs(site.order) do touch(i) end
    t.expect(artifacts.progress(key).solved, "the artifact is found")
    game.helmet.yaw = math.atan(site.x - site.pylons[1].x, site.z - site.pylons[1].z)
    game.helmet.pitch = 0.1
    t.frames(4)
    t.screenshot("civ_ruin")
    print("civilisations state hash " .. sim.hash())
  end,
}
