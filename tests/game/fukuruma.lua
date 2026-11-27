-- The Fukuruma test (plan M6): the whole chain down and back up, in first person. From the Exosuit up to the Jump Ship
-- (boarding, a Drop Ship on autopilot to the station, the teleport); then down again, deploying a fresh Land Explorer,
-- Walker and Exosuit and walking on; then every doll recalled into its parent's hold on the way back up.
local sim = require("fk.sim")
local chain = require("chain")

local function find(kind, newest)
  local found
  for _, d in ipairs(chain.state().dolls) do
    if d.kind == kind and (not found or newest) then found = d end
  end
  return found
end

return scenario {
  seed = 1,
  timeout_s = 600,
  run = function(t)
    local game = require("game")
    t.frames(2)
    local function act(name, args)
      sim.send(name, args)
      t.frames(1)
    end
    local function fly(drop, target) -- the autopilot, ticked without drawing until it arrives
      act("autopilot", { id = target.id })
      for _ = 1, 30000 do
        sim.step(game)
        if not drop.auto then break end
      end
      t.expect(drop.auto == nil, "the Drop Ship reached the " .. target.kind)
    end
    -- up
    for _ = 1, 3 do act("board", { id = chain.up() }) end
    act("deploy", { kind = "drop_ship" })
    local drop = find("drop_ship")
    act("board", { id = drop.id })
    fly(drop, find("space_station"))
    act("board", { id = find("space_station").id })
    act("teleport", { id = chain.teleport_target() })
    t.expect(chain.current().kind == "jump_ship", "up at the Jump Ship")
    -- down
    act("teleport", { id = chain.teleport_target() })
    act("board", { id = drop.id })
    local continental = find("continental_explorer")
    fly(drop, continental)
    act("board", { id = continental.id })
    act("deploy", { kind = "land_explorer" })
    local land = find("land_explorer", true)
    act("board", { id = land.id })
    act("deploy", { kind = "walker" })
    local walker = find("walker", true)
    act("board", { id = walker.id })
    act("deploy", { kind = "exosuit" })
    t.expect(chain.current() == walker, "the Exosuit is out beside the Walker")
    local exo = find("exosuit", true)
    act("board", { id = exo.id })
    t.expect(chain.on_foot(), "on foot again, far from the range")
    t.frames(60) -- the ground streams in under the suit
    local suit = sim.get(game.suit, "suit")
    local x0, z0 = suit.x, suit.z
    sim.send("move", { x = 0, z = 2.6, fx = 0, fz = 1 })
    t.frames(120)
    sim.send("move", { x = 0, z = 0, fx = 0, fz = 1 })
    t.expect(math.abs(suit.z - z0) > 3 and math.abs(suit.x - x0) < 1, "the Commander walks on: " .. suit.z - z0)
    game.helmet.yaw, game.helmet.pitch = math.pi, 0.1 -- back towards the new Walker
    t.frames(20)
    t.screenshot("fukuruma_on_foot")
    -- back up, each doll into its parent's hold
    act("board", { id = walker.id })
    act("recall", { id = exo.id })
    act("board", { id = land.id })
    act("recall", { id = walker.id })
    act("board", { id = continental.id })
    act("recall", { id = land.id })
    t.expect(not find("exosuit", true) or find("exosuit", true) ~= exo, "the new dolls are back in their holds")
    act("board", { id = drop.id })
    fly(drop, find("space_station"))
    act("board", { id = find("space_station").id })
    act("teleport", { id = chain.teleport_target() })
    t.expect(chain.current().kind == "jump_ship", "back on the Jump Ship")
    game.helmet.yaw, game.helmet.pitch = 0, -0.3
    t.frames(20)
    t.screenshot("fukuruma_back_on_jump_ship")
  end,
}
