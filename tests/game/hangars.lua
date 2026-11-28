-- vessel-interiors spec (hangar boarding, interior transit, drones): from the Jump Ship's bridge down its corridor,
-- by tram along the hangars to the docked Space Station, up its ramp, to its bridge, and out of the hold at its
-- controls.
local sim = require("fk.sim")

local function press(t, key, frames)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(frames or 1)
end

local function fixture(layout, name, kind)
  for _, f in ipairs(layout.fixtures) do
    if f[1] == name and (not kind or f.kind == kind) then return f end
  end
end

return scenario {
  seed = 1,
  timeout_s = 180,
  run = function(t)
    local game = require("game")
    local chain = require("chain")
    local interior = require("interior")
    t.frames(5)
    local ship
    for _, d in ipairs(chain.state().dolls) do
      if d.kind == "jump_ship" then ship = d end
    end
    chain.state().at = ship.id
    t.frames(2)
    press(t, "F", 2)
    game.helmet.yaw, game.helmet.pitch = math.pi, 0 -- down the corridor
    t.key("W", true); t.frames(120); t.key("W", false); t.frames(2)
    t.screenshot("hangars_corridor")
    local l = interior.layout("jump_ship")
    local w = chain.walking()
    t.expect(w.z < l.seat[2] - 3, "walked down the corridor")
    local stop = fixture(l, "tram")
    w.x, w.z = stop[2], stop[3] + 1 -- shortcut: the rest of the corridor without the walk
    t.frames(2)
    t.expect(chain.use_hint() == "TRAM TO THE DROP SHIP HANGAR", "the tram stop: " .. tostring(chain.use_hint()))
    press(t, "F", 2)
    t.expect(chain.walking().ride, "riding the tram")
    t.frames(60)
    w = chain.walking()
    t.expect(not w.ride and chain.use_hint() == "TRAM TO THE SPACE STATION HANGAR", "at the Drop Ship's hangar")
    press(t, "F", 6 * 60)
    t.expect(chain.walking().ride and chain.use_hint() == nil, "on the tram along the hangar")
    t.screenshot("hangars_tram")
    t.frames(6 * 60 + 30)
    w = chain.walking()
    local ramp = fixture(l, "ramp", "space_station")
    t.expect(not w.ride and math.abs(w.z - ramp[3]) < 2, "at the Space Station's hangar")
    game.helmet.yaw, game.helmet.pitch = math.pi, 0.1 -- the docked station, down the hangar
    t.frames(3)
    t.screenshot("hangars_station")
    w.x, w.z = ramp[2], ramp[3]
    t.frames(2)
    t.expect(chain.use_hint() == "BOARD THE SPACE STATION")
    press(t, "F", 2)
    w = chain.walking()
    t.expect(w.docked == "space_station", "inside the docked station")
    local seat = fixture(interior.layout("space_station"), "seat")
    w.x, w.z = seat[2], seat[3]
    game.helmet.yaw, game.helmet.pitch = 0, 0
    t.frames(3)
    t.screenshot("hangars_station_bridge")
    t.expect(chain.use_hint() == "LAUNCH THE SPACE STATION")
    press(t, "F", 3)
    t.expect(chain.current().kind == "space_station" and not chain.walking(), "out of the hold at the station's controls")
    print("hangars state hash " .. sim.hash())
  end,
}
