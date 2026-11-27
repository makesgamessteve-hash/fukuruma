-- rivers-and-lakes spec: the range's world has rivers in carved channels, lakes in their basins, and white water
-- where a river falls; seen from their banks.
local sim = require("fk.sim")

return scenario {
  seed = 1,
  timeout_s = 240,
  run = function(t)
    local game = require("game")
    local s = sim.get(game.suit, "suit")
    t.frames(2)
    local w = require("universe").ground().waters
    t.expect(w and w.rivers > 0 and w.lakes > 0 and w.fall, "rivers, lakes and a fall around the range")
    -- stands back from a place and to one side, looking along the water (or at it)
    local function look(p, back, side, pitch, name)
      local dx, dz = p[3] or 0, p[4] or 1
      local x, z = p[1] - dx * back + dz * side, p[2] - dz * back - dx * side
      for _ = 1, 3 do -- the ground there streams in under the suit
        local h = game.world:height(x, z) or 0
        game.world:set(s.body, { position = { x, h + 1.85, z }, velocity = { 0, 0, 0 } })
        s.x, s.y, s.z = x, h, z
        t.frames(40)
      end
      local tx, tz = p[1] - x, p[2] - z
      game.helmet.yaw, game.helmet.pitch = math.atan(tx, tz), pitch
      t.frames(10)
      t.screenshot(name)
    end
    look(w.lake, 0, 70, -0.12, "rivers_lake")
    look(w.river, 40, 18, -0.25, "rivers_river")
    look(w.fall, 30, 14, -0.3, "rivers_fall")
  end,
}
