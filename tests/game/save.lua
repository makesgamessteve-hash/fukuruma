-- save spec: a save/load round trip keeps the Exosuit's position and the whole simulation state, and the
-- game continues from there; loading with no save says so.
local sim = require("fk.sim")

local function press(t, key)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(1)
end

return scenario {
  seed = 1,
  timeout_s = 30,
  run = function(t)
    local game = require("game")
    local suit = function() return sim.get(game.suit, "suit") end
    press(t, "F9")
    t.expect(game.toast and game.toast.text == "No saved game yet", "nothing to load yet")
    t.key("W", true); t.frames(60)
    t.key("W", false); t.frames(30)
    press(t, "F5")
    t.expect(game.toast.text == "Game saved", "saved")
    local x, z, hash = suit().x, suit().z, sim.hash()
    t.expect(z > 1, "walked forward first")
    t.key("D", true); t.frames(60)
    t.key("D", false); t.frames(20)
    t.expect(suit().x ~= x, "moved on after saving")
    press(t, "F9")
    t.expect(game.toast.text == "Game loaded", "loaded")
    t.expect(suit().x == x and suit().z == z and sim.hash() == hash, "the position and state are back exactly")
    t.key("W", true); t.frames(10)
    t.expect(suit().z > z, "the game goes on from there")
    t.key("W", false)
  end,
}
