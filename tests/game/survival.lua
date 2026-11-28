-- exosuit-survival, death-modes, ecology and defensive-tools specs: without a filter in a toxic zone the Commander
-- dies. In Legacy mode the run ends and the codex keeps what was found for the next Commander (F starts the new run);
-- in Clone mode the Commander wakes in the Jump Ship's clone bay and the lost suit's spare waits in the Walker. A
-- predator pack passed at a walk does not notice the suit; one that hunts it is drawn away by a flare.
local sim = require("fk.sim")

local function press(t, key, frames)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(frames or 1)
end

return scenario {
  seed = 1,
  timeout_s = 300,
  run = function(t)
    local game = require("game")
    local chain = require("chain")
    local survival = require("survival")
    local sensors = require("sensors")
    local environment = require("environment")
    local ecology = require("ecology")
    fk.storage.save("codex", "")
    t.frames(3)
    local function into_toxic_zone()
      local zone = environment.zones(sensors.state().world)[1]
      chain.move_suit(zone.x, chain.ground(zone.x, zone.z), zone.z)
      survival.state().filter = 0 -- no filter
      t.frames(2)
      t.expect(environment.at(zone.x, zone.z).toxin > 0.3, "a toxic zone")
    end
    local function wait(until_fn, seconds)
      for _ = 1, seconds * 60 do
        sim.step(game)
        if until_fn() then return true end
      end
    end

    sim.send("mode", { mode = "legacy" })
    into_toxic_zone()
    t.screenshot("survival_toxic")
    t.expect(wait(function() return survival.state().over end, 120), "without a filter, the Legacy Commander dies")
    t.frames(2)
    t.screenshot("survival_legacy_end")
    local codex = survival.codex()
    t.expect(codex.commanders == 1 and survival.codex_size(codex) > 0, "the codex keeps what was found")
    press(t, "F", 3)
    t.expect(not survival.state().over and survival.state().mode == "clone" and chain.on_foot(), "a new Commander, a new run")

    into_toxic_zone()
    t.expect(wait(function() return survival.state().deaths == 1 end, 120), "the Clone-mode Commander dies too")
    t.frames(3)
    local w = chain.walking()
    t.expect(w and chain.current().kind == "jump_ship" and survival.state().integrity == 1, "awake in the clone bay")
    local walker
    for _, d in ipairs(chain.state().dolls) do
      if d.kind == "walker" then walker = d end
    end
    t.expect(walker.hold.exosuit == 1, "a spare suit waits in the Walker")
    game.helmet.yaw, game.helmet.pitch = math.pi / 2, 0
    t.frames(3)
    t.screenshot("survival_clone_bay")

    chain.state().at, chain.state().walk = walker.id, nil -- shortcut: back at the Walker (tests/game/travel.lua goes the way)
    t.frames(1)
    sim.send("deploy", { kind = "exosuit" }) -- out in the spare suit
    t.frames(1)
    sim.send("board", { id = chain.down() })
    t.frames(2)
    t.expect(chain.on_foot(), "out again")
    local suit = chain.current()
    local pack = {}
    for i = 1, 3 do pack[i] = sensors.place("predator", suit.x + 40 + i * 3, suit.z + 10, 2.5) end
    t.frames(2)
    sim.send("move", { x = 0, z = 2.6, fx = 0, fz = 1 }) -- a walk past them, 40 m off
    t.frames(200)
    sim.send("move", { x = 0, z = 0, fx = 0, fz = 1 })
    t.frames(2)
    local noticed = false
    for _, h in ipairs(pack) do noticed = noticed or h.hunting ~= nil end
    t.expect(not noticed, "walking by, the pack does not notice the suit")
    game.helmet.yaw, game.helmet.pitch = -math.pi / 2 + 0.2, -0.05
    t.frames(3)
    t.screenshot("survival_pack")

    local p = sim.get(game.suit, "suit")
    local hunter = sensors.place("predator", p.x, p.z + 18, 3)
    t.frames(ecology.THINK * 2)
    t.expect(hunter.hunting, "a predator close by hunts the suit")
    game.helmet.yaw, game.helmet.pitch = math.pi / 2, -0.1 -- facing +x, the predator to the side
    t.frames(2)
    press(t, "C", 2) -- a flare, thrown ahead, away from the predator
    t.frames(60 * 6)
    local dx, dz = hunter.x - p.x, hunter.z - p.z
    t.expect(not hunter.hunting and dx * dx + dz * dz > 15 * 15, "the flare drew it away")
    t.screenshot("survival_flare")
    print("survival state hash " .. sim.hash())
  end,
}
