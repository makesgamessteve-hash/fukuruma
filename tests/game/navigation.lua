-- navigation-maps spec: M opens the galaxy map; from the Jump Ship's bridge, Enter jumps to the chosen star within range; Tab shows the
-- system map. Three jumps in a row reach three new systems, each with its own sky, light and gravity, and the result
-- is the same on every platform.
local sim = require("fk.sim")
local universe = require("universe")

local RECORDED_HASH = "f692acde720c37d7"

local function press(t, key, frames)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(frames or 1)
end

return scenario {
  seed = 1,
  timeout_s = 60,
  run = function(t)
    local game = require("game")
    t.frames(5)
    local chain = require("chain") -- the jump drive is on the Jump Ship's bridge (the way up there: tests/game/travel.lua)
    for _, d in ipairs(chain.state().dolls) do
      if d.kind == "jump_ship" then chain.state().at = d.id end
    end
    game.helmet.pitch = -0.35
    local seen = { [universe.state().seed] = true }
    local gravity = { game.world:gravity()[2] }
    press(t, "M", 5)
    t.expect(require("navmap").open, "M opens the galaxy map")
    t.screenshot("nav_galaxy")
    press(t, "Tab", 5)
    t.screenshot("nav_system")
    press(t, "Right", 2)
    press(t, "Tab", 2)
    for jump = 1, 3 do
      if not require("navmap").open then press(t, "M", 3) end
      press(t, "Right", 1) -- the second-nearest star, so the jumps do not go back and forth
      press(t, "Return", 1)
      t.frames(100) -- the jump sequence
      local u = universe.state()
      t.expect(u.jumps == jump, "jump " .. jump .. " happened")
      t.expect(not seen[u.seed], "jump " .. jump .. " reached a new system")
      seen[u.seed] = true
      gravity[#gravity + 1] = game.world:gravity()[2]
      t.screenshot("nav_arrival_" .. jump)
    end
    t.expect(gravity[1] ~= gravity[4] or gravity[2] ~= gravity[3], "gravity follows the world")
    print("navigation state hash " .. sim.hash())
    t.expect(sim.hash() == RECORDED_HASH, "the state hash differs from the recorded one")
  end,
}
