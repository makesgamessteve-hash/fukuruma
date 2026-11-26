-- The M1 sandbox (main.lua): the suit's simulation, input commands and presentation without a window.
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local feel = require("fk.feel")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  return sim.get(game.suit, "suit")
end

local function with_keys(held, fn)
  local real = fk.input
  fk.input = setmetatable({ key = function(k) return held[k] == true end, device = function() return "keyboard" end },
    { __index = real })
  local ok, err = pcall(fn)
  fk.input = real
  assert(ok, err)
end

return {
  ["init creates the suit at the origin, facing +z"] = function()
    local s = start()
    assert(s.x == 0 and s.z == 0 and s.fz == 1)
  end,
  ["the suit accelerates, moves and turns in the simulation"] = function()
    local s = start()
    sim.send("move", { x = -2.6, z = 0 })
    for _ = 1, 60 do sim.step(game) end
    assert(s.vx == -2.6 and s.x < -1.5, "reaches walking speed within a second")
    assert(s.fx < -0.9, "faces where it goes")
    for _ = 1, 3000 do sim.step(game) end
    assert(s.x == -78, "stops at the edge of the ground")
  end,
  ["input becomes move and scan commands"] = function()
    start()
    with_keys({ W = true, ["Left Shift"] = true }, function()
      game.input()
      game.input() -- unchanged input sends nothing more
    end)
    for _ = 1, 30 do sim.step(game) end
    local s = sim.get(game.suit, "suit")
    assert(s.wz == game.RUN and s.z > 0, "W with Shift runs forward")
    local scans = 0
    sim.listen("scan", function() scans = scans + 1 end)
    with_keys({ E = true }, function() game.input() end)
    sim.step(game)
    assert(s.wz == 0 and scans == 1, "E alone stops the suit and scans once")
  end,
  ["the menu holds the suit"] = function()
    start()
    with_keys({ Escape = true }, function() game.input() end)
    with_keys({ W = true }, function() game.input() end)
    sim.step(game)
    assert(sim.get(game.suit, "suit").wz == 0)
    require("menu").open = false
  end,
  ["draw animates, raises dust at footsteps and follows with the camera"] = function()
    start()
    feel.reset()
    sim.send("move", { x = 0, z = 6.3 })
    for _ = 1, 90 do
      sim.step(game)
      game.draw(1, 1 / 60)
    end
    assert(fk.gfx.particles(0) > 0, "footsteps raised dust")
    game.draw(0.5) -- without dt: no time passes
  end,
}
