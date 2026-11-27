-- travel spec: up from the range to the Continental Explorer, out in a Drop Ship on autopilot to the station in orbit,
-- by teleport to the Jump Ship and back, and down again by Drop Ship to the Continental Explorer.
local sim = require("fk.sim")
local chain = require("chain")

local function find(kind)
  for _, d in ipairs(chain.state().dolls) do
    if d.kind == kind then return d end
  end
end

return scenario {
  seed = 1,
  timeout_s = 300,
  run = function(t)
    local game = require("game")
    t.frames(2)
    for _ = 1, 3 do
      sim.send("board", { id = chain.up() })
      t.frames(1)
    end
    t.expect(chain.current().kind == "continental_explorer")
    sim.send("deploy", { kind = "drop_ship" })
    t.frames(1)
    local drop = find("drop_ship")
    sim.send("board", { id = drop.id })
    t.frames(1)
    local function fly_to(target) -- the autopilot, ticked without drawing until it arrives
      sim.send("autopilot", { id = target.id })
      t.frames(1)
      for _ = 1, 30000 do
        sim.step(game)
        if not drop.auto then break end
      end
      t.expect(drop.auto == nil, "the Drop Ship arrived at the " .. target.kind)
    end
    local station = find("space_station")
    fly_to(station)
    game.helmet.yaw, game.helmet.pitch = 0, 0.2
    t.frames(20)
    t.screenshot("travel_drop_ship_at_station")
    sim.send("board", { id = station.id })
    t.frames(1)
    sim.send("teleport", { id = chain.teleport_target() })
    t.frames(1)
    t.expect(chain.current().kind == "jump_ship", "teleported to the Jump Ship")
    game.helmet.yaw, game.helmet.pitch = 0, -0.5
    t.frames(20)
    t.screenshot("travel_jump_ship_bridge")
    sim.send("teleport", { id = chain.teleport_target() })
    t.frames(1)
    sim.send("board", { id = drop.id })
    t.frames(1)
    fly_to(find("continental_explorer"))
    sim.send("board", { id = find("continental_explorer").id })
    t.frames(1)
    t.expect(chain.current().kind == "continental_explorer", "back down at the Continental Explorer")
    game.helmet.yaw, game.helmet.pitch = 0, -0.15
    t.frames(20)
    t.screenshot("travel_back_down")
  end,
}
