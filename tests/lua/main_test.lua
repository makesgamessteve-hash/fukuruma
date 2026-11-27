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
    sim.send("move", { x = -2.6, z = 0, fx = -1, fz = 0 })
    for _ = 1, 60 do sim.step(game) end
    assert(math.abs(s.vx + 2.6) < 1e-3 and s.x < -1.5, "reaches walking speed within a second")
    assert(s.fx < -0.9, "faces where the Commander looks")
    for _ = 1, 3000 do sim.step(game) end
    local h = game.world:height(s.x, s.z)
    assert(s.x < -120 and h and math.abs(s.y - h) < 0.05, "walks off the deck onto the world's own ground")
  end,
  ["the suit pushes crates, stops at the tower and the crates thud"] = function()
    local s = start()
    local crate = game.world:get(game.crates[3]).position -- at (9, 0.8, -4)
    s.x, s.z = 5, -4
    game.world:set(s.body, { position = { 5, 1.8, -4 } })
    sim.send("move", { x = 2.6, z = 0, fx = 1, fz = 0 })
    local impacts = 0
    sim.listen("impact", function(e) impacts = impacts + 1; assert(e.strength > 0 and e.strength <= 1) end)
    for _ = 1, 180 do sim.step(game) end
    local moved = game.world:get(game.crates[3]).position
    assert(moved[1] > crate[1] + 2, "the crate was pushed along")
    assert(s.x > 7, "the suit walked on behind it")
    s = start()
    s.x, s.z = 6, 1
    game.world:set(s.body, { position = { 6, 1.8, 1 } })
    sim.send("move", { x = 0, z = 2.6, fx = 0, fz = 1 })
    for _ = 1, 120 do sim.step(game) end
    assert(math.abs(s.z - (4 - 0.4 - 0.8)) < 0.02 and math.abs(s.x - 6) < 0.05, "the beacon tower stops the suit")
    local drop = game.world:add({ shape = "box", size = { 1, 1, 1 }, mass = 50, position = { 0, 3, 10 } })
    for _ = 1, 60 do sim.step(game) end
    assert(impacts > 0 and game.world:get(drop).position[2] < 0.6, "a dropped box lands with an impact")
  end,
  ["saves keep the physics world"] = function()
    local s = start()
    local crate = game.world:get(game.crates[1]).position
    game.save()
    s.x = 3
    game.world:set(game.crates[1], { position = { 0, 10, 0 } })
    game.load()
    local back = game.world:get(game.crates[1]).position
    assert(sim.get(game.suit, "suit").x == 0 and back[1] == crate[1] and back[2] == crate[2], "back where they were")
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
    with_keys({}, function() game.input() end)
    with_keys({ E = true }, function() game.input() end)
    sim.step(game)
    assert(scans == 1, "the scanner needs time to recharge")
  end,
  ["walking goes where the Commander looks"] = function()
    start()
    game.helmet:look(math.pi / 2, 0, 0) -- a quarter turn to the right: forward is -x
    with_keys({ W = true }, function() game.input() end)
    for _ = 1, 60 do sim.step(game) end
    local s = sim.get(game.suit, "suit")
    assert(s.x < -1.5 and math.abs(s.z) < 1e-9 and s.fx < -0.99, "walks and turns towards -x")
  end,
  ["the outside view is for looking only"] = function()
    start()
    with_keys({ V = true }, function() game.input() end)
    assert(game.view == "drone" and game.drone.yaw == game.helmet.yaw)
    local yaw = game.drone.yaw
    local scans = 0
    sim.listen("scan", function() scans = scans + 1 end)
    with_keys({ W = true, E = true }, function() game.input() end)
    sim.step(game)
    assert(sim.get(game.suit, "suit").wz == 0 and scans == 0, "the suit holds still and does not scan")
    local real = actions.touch_look
    actions.touch_look = function() return 0.1, 0 end
    with_keys({}, function() game.input() end)
    actions.touch_look = real
    assert(game.drone.yaw < yaw and game.helmet.yaw == 0, "looking orbits the drone, not the helmet")
    game.draw(1, 1 / 60)
    with_keys({ V = true }, function() game.input() end)
    assert(game.view == "helmet", "V returns to the Commander's eyes")
  end,
  ["the mouse is captured once it is used, until touch or the menu"] = function()
    start()
    local captured = {}
    local real = fk.input
    local device = "keyboard"
    fk.input = setmetatable({ device = function() return device end, key = function() return false end,
      capture = function(on) captured[#captured + 1] = on end }, { __index = real })
    local ok, err = pcall(function()
      game.input()
      assert(#captured == 0, "not before the mouse is used")
      device = "mouse"; game.input()
      device = "keyboard"; game.input()
      assert(#captured == 1 and captured[1] == true, "stays captured for keyboard play")
      device = "touch"; game.input()
      assert(captured[2] == false, "touch releases it")
    end)
    fk.input = real
    assert(ok, err)
  end,
  ["M opens the maps, which hold the suit; a jump plays its sequence"] = function()
    start()
    local navmap = require("navmap")
    with_keys({ M = true }, function() game.input() end)
    assert(navmap.open)
    with_keys({ W = true }, function() game.input() end)
    sim.step(game)
    assert(sim.get(game.suit, "suit").wz == 0, "the suit holds still while the maps are open")
    with_keys({}, function() game.input() end)
    with_keys({ M = true }, function() game.input() end)
    assert(not navmap.open, "M closes them")
    sim.emit("jump", {})
    sim.step(game)
    for _ = 1, 100 do game.draw(1, 1 / 60) end
    assert(game.jump_fx == nil, "the sequence ends")
  end,
  ["the menu holds the suit"] = function()
    start()
    with_keys({ Escape = true }, function() game.input() end)
    with_keys({ W = true }, function() game.input() end)
    sim.step(game)
    assert(sim.get(game.suit, "suit").wz == 0)
    require("menu").open = false
  end,
  ["quick save and load with a notice that fades out"] = function()
    local s = start()
    game.save()
    sim.send("move", { x = 2.6, z = 0, fx = 1, fz = 0 })
    for _ = 1, 30 do sim.step(game) end
    s = sim.get(game.suit, "suit")
    assert(s.x > 0)
    game.load()
    assert(sim.get(game.suit, "suit").x == 0 and game.toast.text == "Game loaded")
    assert(math.abs(game.helmet.yaw) < 1e-9, "the view turns to where the loaded suit looked")
    for _ = 1, 200 do game.draw(1, 1 / 60) end
    assert(game.toast == nil, "the notice is gone after 2.5 s")
  end,
  ["draw animates, raises dust at footsteps and sees through the visor"] = function()
    start()
    feel.reset()
    require("settings.comfort").current.head_bob = 0.5
    sim.send("move", { x = 0, z = 6.3, fx = 0, fz = 1 })
    for _ = 1, 90 do
      sim.step(game)
      game.draw(1, 1 / 60)
    end
    assert(fk.gfx.particles(0) > 0, "footsteps raised dust")
    game.draw(0.5) -- without dt: no time passes
    require("settings.comfort").current.head_bob = 1
  end,
}
