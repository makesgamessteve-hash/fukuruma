-- voxel-terrain spec: the suit digs a pit and a tunnel forward and down from it, walks into the tunnel (with ground
-- over its head), saves, wanders off, loads, and walks through the tunnel again.
local sim = require("fk.sim")
local dig = require("dig")

return scenario {
  seed = 1,
  timeout_s = 120,
  run = function(t)
    local game = require("game")
    local s = sim.get(game.suit, "suit")
    t.frames(2)
    -- off the deck: 120 m north of it, facing north
    local h0 = game.world:height(0, 120) or 0
    game.world:set(s.body, { position = { 0, h0 + 1.8 + 0.05, 120 } })
    s.x, s.y, s.z, s.fx, s.fz, s.lx, s.lz = 0, h0, 120, 0, 1, 0, 1
    game.helmet.yaw, game.helmet.pitch = 0, -0.25
    t.frames(30) -- the ground under the suit's new place
    local function walk(frames, speed)
      sim.send("move", { x = 0, z = speed, fx = 0, fz = 1 })
      t.frames(frames)
      sim.send("move", { x = 0, z = 0, fx = 0, fz = 1 })
      t.frames(20)
    end
    sim.send("dig", {})
    t.frames(40)
    t.expect(#dig.list() == 4, "the first dig: a pit")
    t.screenshot("dig_pit")
    walk(60, 2.6) -- into the pit
    for _ = 1, 5 do
      sim.send("dig", {})
      t.frames(40)
      walk(70, 2.6)
    end
    t.expect(#dig.list() == 24, "six digs")
    local ground = game.world:height(s.x, s.z)
    t.expect(s.y < ground - 4, "the suit is deep below the surface: " .. s.y .. " under " .. ground)
    t.expect(s.y + 3.6 < ground, "with ground over its head")
    t.screenshot("dig_tunnel")
    local deep_z, deep_y = s.z, s.y
    walk(150, -2.6) -- back to the pit
    game.save()
    walk(60, 2.6)
    s.x = s.x -- (anything the save does not hold would show below)
    game.load()
    s = sim.get(game.suit, "suit")
    t.frames(5)
    t.expect(#dig.list() == 24, "the tunnel is still there after a load")
    walk(150, 2.6) -- through the tunnel again
    t.expect(s.z > deep_z - 0.5 and s.y < deep_y + 0.5, "the suit walks back down the tunnel: " .. s.z .. ", " .. s.y)
    t.screenshot("dig_after_load")
  end,
}
