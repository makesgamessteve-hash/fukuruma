-- sensor-system spec: a gas pocket smaller than the Walker's resolution stays off the Walker's sensors and shows on
-- the Exosuit's visor; an active ping wakes a predator; the Walker's autopilot stops short of a sinkhole its sensors
-- found, and its window shows the sinkhole's marker.
local sim = require("fk.sim")

local function press(t, key, frames)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(frames or 1)
end

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    local chain = require("chain")
    local sensors = require("sensors")
    t.frames(3)
    local function find(kind)
      for _, d in ipairs(chain.state().dolls) do
        if d.kind == kind then return d end
      end
    end
    local walker = find("walker")
    local suit = chain.current()
    local gas = sensors.place("gas_pocket", (suit.x + walker.x) / 2, (suit.z + walker.z) / 2, 0.2)
    local function known(h) return sensors.state().contacts["h" .. h.id] ~= nil end
    sim.send("board", { id = walker.id })
    t.frames(sensors.PASSIVE + 2)
    t.expect(chain.current() == walker and not known(gas), "the gas pocket is below the Walker's resolution")
    sim.send("board", { id = chain.down() })
    t.frames(sensors.PASSIVE + 2)
    t.expect(chain.on_foot() and known(gas), "the Exosuit's sensors find it")
    suit = chain.current()
    game.helmet.yaw, game.helmet.pitch = math.atan(gas.x - suit.x, gas.z - suit.z), -0.3
    t.frames(3)
    t.screenshot("sensors_visor")

    local predator = sensors.place("predator", suit.x + 200, suit.z, 3)
    t.frames(2)
    t.expect(not predator.alerted and not known(predator), "out of passive range, unaware")
    press(t, "E", 2)
    t.expect(predator.alerted and known(predator), "the ping found the predator, and it heard the ping")

    sim.send("board", { id = walker.id })
    t.frames(2)
    local target = chain.find(walker.parent)
    local dx, dz = target.x - walker.x, target.z - walker.z
    local len = math.sqrt(dx * dx + dz * dz)
    local hole = sensors.place("sinkhole", walker.x + dx / len * 500, walker.z + dz / len * 500, 40)
    local stops = 0
    sim.listen("hazard_stop", function() stops = stops + 1 end)
    sim.send("autopilot", { id = target.id })
    t.frames(1)
    for _ = 1, 60 * 120 do
      sim.step(game)
      if not walker.auto then break end
    end
    for _ = 1, 60 * 6 do sim.step(game) end -- braking
    local left = math.sqrt((hole.x - walker.x) ^ 2 + (hole.z - walker.z) ^ 2)
    t.expect(walker.auto == nil and stops == 1 and known(hole), "the autopilot stopped for the sinkhole")
    t.expect(left > hole.size and left < 500, "short of it, after going some way: " .. left)
    game.helmet.yaw, game.helmet.pitch = 0, -0.15
    t.frames(5)
    t.screenshot("sensors_window")
    print("sensors state hash " .. sim.hash())
  end,
}
