-- vessel-interiors spec: from the Exosuit beside the Walker, F goes in through its suit bay and the Commander walks as
-- a human. A shut door stops the walk and stays shut over a save and load. Up the corridor to the bridge and the
-- controls; up again from the seat, back to the suit bay, and out in the Exosuit.
local sim = require("fk.sim")

local function press(t, key, frames)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(frames or 1)
end

local function walk(t, key, frames)
  t.key(key, true); t.frames(frames)
  t.key(key, false); t.frames(2)
end

return scenario {
  seed = 1,
  timeout_s = 120,
  run = function(t)
    local game = require("game")
    local chain = require("chain")
    local interior = require("interior")
    t.frames(5)
    t.expect(chain.use_hint() == "ENTER THE EXPLORATION WALKER", "beside the Walker, F goes in: " .. tostring(chain.use_hint()))
    press(t, "F", 2)
    local w = chain.walking()
    t.expect(w and chain.current().kind == "walker", "inside the Walker, on foot")
    local layout = interior.layout("walker")
    local bay
    for _, r in ipairs(layout.rooms) do
      if r.name == "suit bay" then bay = r end
    end
    game.helmet.yaw, game.helmet.pitch = -math.pi / 2, 0 -- facing the bay's door (-x)
    t.frames(3)
    t.screenshot("interior_suit_bay")
    walk(t, "W", 120)
    w = chain.walking()
    t.expect(w.x < bay.x0 + 1.2, "walked to the door: " .. w.x)
    t.expect(chain.use_hint() == "CLOSE THE SUIT BAY DOOR", "the door is in reach: " .. tostring(chain.use_hint()))
    press(t, "F", 2)
    t.expect(not chain.door_open("walker")("suit bay"), "the door shut")
    t.screenshot("interior_door")
    walk(t, "W", 60)
    t.expect(chain.walking().x > bay.x0, "the shut door stops the walk")
    press(t, "F5")
    t.expect(game.toast.text == "Game saved", "saved")
    press(t, "F", 2)
    t.expect(chain.door_open("walker")("suit bay"), "the door opened")
    press(t, "F9")
    t.expect(game.toast.text == "Game loaded", "loaded")
    t.expect(not chain.door_open("walker")("suit bay"), "the door is shut again after loading")
    press(t, "F", 2)
    game.helmet.yaw = -math.pi / 2 -- (loading turns the view to the saved facing)
    walk(t, "W", 90)
    t.expect(chain.walking().x < 1.2, "through the open door into the corridor: " .. chain.walking().x)
    game.helmet.yaw = 0 -- up the corridor to the bridge
    local seat
    for _, f in ipairs(layout.fixtures) do
      if f[1] == "seat" then seat = f end
    end
    walk(t, "W", math.floor((seat[3] - chain.walking().z) / (game.WALK * chain.WALK) * 60)) -- as far as the seat
    t.expect(chain.use_hint() == "TAKE THE CONTROLS", "at the bridge seat: " .. tostring(chain.use_hint()))
    t.screenshot("interior_bridge")
    press(t, "F", 2)
    t.expect(not chain.walking() and not chain.on_foot(), "at the Walker's controls")
    press(t, "F", 2)
    t.expect(chain.walking(), "up from the seat")
    w = chain.walking()
    w.x, w.z = layout.fixtures[1][2], layout.fixtures[1][3] -- shortcut: back at the suit stand without the walk
    t.frames(2)
    t.expect(chain.use_hint() == "SUIT UP AND GO OUT", "the suit stand is in reach")
    press(t, "F", 3)
    t.expect(chain.on_foot() and chain.current().kind == "exosuit", "in the Exosuit, outside")
    print("interiors state hash " .. sim.hash())
  end,
}
