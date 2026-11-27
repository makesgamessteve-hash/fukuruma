-- dolls.lua, dolls/hull.lua and chain.lua (doll-chain spec): the registry, the hulls, and deploy, recall and board.
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local dolls = require("dolls")
local hull = require("dolls.hull")
local chain = require("chain")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  sim.step(game)
end

local function step(n)
  for _ = 1, n or 1 do sim.step(game) end
end

local function find(kind)
  for _, d in ipairs(chain.state().dolls) do
    if d.kind == kind then return d end
  end
end

local function fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(text, 1, true), "expected '" .. text .. "', got " .. tostring(err))
end

return {
  ["the chain is Lua data, from the Jump Ship down to the Exosuit"] = function()
    local sizes = { jump_ship = 144000, space_station = 31000, continental_explorer = 6700, land_explorer = 1440,
      walker = 72, exosuit = 3.6, drop_ship = 100 }
    for id, size in pairs(sizes) do assert(dolls.by_id[id].size_m == size, id) end
    assert(dolls.parent_of("walker").id == "land_explorer" and dolls.parent_of("jump_ship") == nil)
    fails(function() dolls.register({ id = "walker", size_m = 1, place = "ground" }) end, "a new string 'id'")
    fails(function() dolls.register({ id = "x1", size_m = 0, place = "ground" }) end, "'size_m' above 0")
    fails(function() dolls.register({ id = "x2", size_m = 1, place = "sea" }) end, "'place' ground, sky or orbit")
    local mod = dolls.register({ id = "test_skiff", size_m = 8, place = "ground" })
    assert(dolls.by_id.test_skiff == mod and mod.seat and mod.hull, "mods add dolls, with defaults")
    dolls.by_id.test_skiff, dolls.list[#dolls.list] = nil, nil
  end,
  ["every doll has a hull at its real size"] = function()
    for _, d in ipairs(dolls.list) do
      local mesh = hull.build(d.hull, d.size_m)
      assert(#mesh.indices > 0 and #mesh.positions == #mesh.colors, d.id)
      local top = 0
      for i = 2, #mesh.positions, 3 do top = math.max(top, mesh.positions[i]) end
      assert(top > d.size_m * 0.05 and top < d.size_m * 1.5, d.id .. " about its size: " .. top)
    end
    local a, b = hull.build({ { "greebles", at = { 0, 0, 0 }, size = { 1, 1 }, count = 5, height = 0.1, seed = 3,
      color = { 1, 1, 1 } } }, 1), hull.build({ { "greebles", at = { 0, 0, 0 }, size = { 1, 1 }, count = 5,
      height = 0.1, seed = 3, color = { 1, 1, 1 } } }, 1)
    assert(a.positions[7] == b.positions[7], "greebles come from their seed")
    fails(function() hull.build({ { "blob" } }, 1) end, "unknown kind 'blob'")
  end,
  ["a new game: the chain stands out, the Commander on foot in the Exosuit"] = function()
    start()
    local s = chain.state()
    assert(#s.dolls == 6 and chain.on_foot() and chain.current().kind == "exosuit")
    assert(find("walker").parent == find("land_explorer").id and find("exosuit").parent == find("walker").id)
    assert(find("walker").hold.exosuit == 0 and find("land_explorer").hold.walker == 1, "one out, one in the hold")
    assert(chain.up() == find("walker").id and chain.down() == nil and chain.next_kind() == nil)
    local w = find("walker")
    assert(math.abs(w.y - chain.ground(w.x, w.z)) < 1e-6, "the Walker stands on the ground")
  end,
  ["board, deploy and recall along the chain"] = function()
    start()
    local suit = sim.get(game.suit, "suit")
    local heard = {}
    for _, name in ipairs({ "board", "deploy", "recall" }) do sim.listen(name, function(e) heard[name] = e.kind end) end
    heard.teleport = nil
    sim.send("board", { id = find("walker").id })
    step()
    assert(chain.current().kind == "walker" and heard.board == "walker" and not chain.on_foot())
    local eye = chain.seat(chain.current())
    assert(eye[2] > find("walker").y + 50, "the Walker's seat is high up")
    -- the suit stands still while the Commander is elsewhere: no walking, digging or scanning from the Walker
    sim.send("move", { x = 3, z = 0, fx = 0, fz = 1 })
    sim.send("dig", {})
    sim.send("scan", {})
    step(10)
    assert(math.abs(suit.vx) < 1e-6 and #require("dig").list() == 0, "the suit waits")
    -- the Exosuit back into the Walker's hold, then out again beside it
    sim.send("recall", { id = find("exosuit").id })
    step()
    assert(find("exosuit") == nil and chain.current().hold.exosuit == 1 and heard.recall == "exosuit")
    assert(chain.next_kind() == "exosuit")
    sim.send("deploy", { kind = "exosuit" })
    step()
    local exo = find("exosuit")
    assert(exo and heard.deploy == "exosuit" and chain.current().hold.exosuit == 0)
    step(3)
    assert(math.abs(suit.x - (find("walker").x + 40)) < 1, "the suit stands where the Exosuit came out")
    sim.send("deploy", { kind = "exosuit" })
    step()
    assert(chain.current().hold.exosuit == 0, "nothing left to deploy")
    -- up the chain: to the Land Explorer, which holds a second Walker
    sim.send("board", { id = chain.up() })
    step()
    assert(chain.current().kind == "land_explorer" and chain.next_kind() == "walker")
    sim.send("recall", { id = find("walker").id })
    step()
    assert(find("walker"), "a Walker with its Exosuit out is not recalled")
    sim.send("board", { id = 999 })
    sim.send("recall", { id = 999 })
    step()
    assert(chain.current().kind == "land_explorer", "unknown dolls change nothing")
    -- up to the Continental Explorer; the station above is reached only by Drop Ship
    sim.send("board", { id = chain.up() })
    step()
    assert(chain.current().kind == "continental_explorer")
    sim.send("board", { id = chain.up() })
    step()
    assert(chain.current().kind == "continental_explorer", "no climbing straight into orbit")
    sim.send("deploy", { kind = "drop_ship" })
    step()
    local drop = find("drop_ship")
    sim.send("board", { id = drop.id })
    step()
    assert(chain.current() == drop and chain.teleport_target() == nil)
    assert(chain.autopilot_target() == find("space_station").id, "low down: the Drop Ship heads for orbit")
    local arrived
    sim.listen("arrived", function(e) arrived = e.id end)
    sim.send("autopilot", { id = chain.autopilot_target() })
    step()
    assert(drop.auto and chain.screens()[6][1] == "AUTOPILOT")
    for _ = 1, 20000 do -- up to the station, faster the higher it climbs
      step()
      if not drop.auto then break end
    end
    local up = drop.y - chain.ground(drop.x, drop.z)
    assert(arrived == find("space_station").id and up > 3e5, "the Drop Ship has climbed to the station: " .. up)
    sim.send("board", { id = find("space_station").id })
    step()
    assert(chain.current().kind == "space_station" and chain.teleport_target() == find("jump_ship").id)
    sim.send("teleport", { id = chain.teleport_target() })
    step()
    assert(chain.current().kind == "jump_ship" and chain.up() == nil and heard.teleport == nil)
    sim.send("teleport", { id = find("walker").id })
    step()
    assert(chain.current().kind == "jump_ship", "no teleport node at the Walker")
    assert(chain.next_kind() == "space_station", "stations before Drop Ships")
    sim.send("deploy", { kind = "drop_ship" })
    step()
    assert(chain.down() and find("drop_ship"), "a Drop Ship out")
    sim.send("board", { id = find("exosuit").id })
    step()
    assert(chain.current().kind == "jump_ship", "too far: the Exosuit is no child of the Jump Ship")
  end,
  ["each doll is steered from its seat by its own controller"] = function()
    start()
    sim.send("drive", { throttle = 1 })
    step()
    assert(chain.current().drive == nil, "the Exosuit walks with the move command, not drive")
    local w = find("walker")
    sim.send("board", { id = w.id })
    local stomps = 0
    sim.listen("stomp", function(e) stomps = stomps + 1 assert(e.strength > 0) end)
    sim.send("drive", { throttle = 1, turn = 0, lift = 0 })
    step(600) -- ten seconds
    assert(w.z > -150 + 40 and math.abs(w.x) < 1e-6 and math.abs(w.y - chain.ground(w.x, w.z)) < 1e-6,
      "the Walker strides forward on the ground: " .. w.z)
    assert(stomps >= 2, "a stomp every stride")
    assert(chain.bob(w) >= 0 and chain.matrix(w)[13] == w.x)
    local seat = chain.seat(w)
    sim.send("drive", { throttle = 0, turn = 1 })
    step(300)
    assert(w.yaw > 0.3, "it turns: " .. w.yaw)
    local turned = chain.seat(w)
    assert(math.abs(turned[1] - w.x) > 1 and seat[3] - w.z ~= turned[3] - w.z, "the seat turns with it")
    sim.send("drive", { throttle = "fast", turn = 5 })
    step()
    assert(w.drive.throttle == 0 and w.drive.turn == 1, "steering is clamped")
    sim.send("board", { id = chain.up() }) -- the Walker stops once the Commander has left
    step(200)
    assert(math.abs(w.speed) < 1e-9 and w.drive == nil)
    sim.send("board", { id = chain.up() })
    step()
    local c = chain.current()
    assert(c.kind == "continental_explorer")
    local y0 = c.y
    sim.send("drive", { throttle = 0.5, lift = 1 })
    step(120)
    assert(c.y > y0 + 50 and c.speed > 0, "it climbs and flies")
    sim.send("drive", { lift = -1 })
    step(3000)
    assert(c.y >= chain.ground(c.x, c.z) + 1500 - 1e-6, "no lower than its floor")
    local station = find("space_station")
    local x0 = station.x
    sim.send("autopilot", { id = find("land_explorer").id }) -- then the hands take over again
    step()
    assert(c.auto)
    sim.send("drive", { throttle = 1 })
    step(60)
    local R = -require("universe").ground().centre[2]
    local r = math.sqrt(station.x * station.x + (station.y + R) ^ 2)
    assert(c.auto == nil and station.x > x0 and math.abs(r - R - 4.0e5) < 1, "the hands cancel the autopilot; the station orbits")
    c.auto = 999
    step()
    assert(c.auto == nil, "a vanished target ends the autopilot")
    c.auto = find("land_explorer").id -- on autopilot it goes on after the Commander has left
    sim.send("board", { id = chain.down() })
    step(10)
    assert(c.speed > 0 and c.auto)
    sim.send("autopilot", { id = chain.current().id })
    step()
    assert(chain.current().auto == nil, "no autopilot to the doll itself")
    local old = { kind = "walker", x = 0, y = 0, z = 0 } -- a doll saved before the controllers
    assert(chain.bob(old) == 0 and chain.seat(old)[2] > 0)
  end,
  ["the legs of the dolls on the ground are solid"] = function()
    start()
    local w = find("walker")
    assert(w.bodies and #w.bodies == 4, "four leg columns")
    local foot = hull.feet(dolls.by_id.walker.hull, 72)[1]
    local fx, fz = w.x + foot[1], w.z + foot[2]
    local suit = sim.get(game.suit, "suit")
    local h = game.world:height(fx, fz + 12) or chain.ground(fx, fz + 12)
    game.world:set(suit.body, { position = { fx, h + 1.85, fz + 12 }, velocity = { 0, 0, 0 } })
    suit.x, suit.y, suit.z = fx, h, fz + 12
    step(30)
    sim.send("move", { x = 0, z = -2.6, fx = 0, fz = -1 })
    step(400)
    assert(suit.z > fz + foot[3] / 2, "the suit stops at the leg: " .. suit.z - fz)
    sim.send("board", { id = w.id })
    step()
    sim.send("board", { id = chain.up() })
    step()
    sim.send("deploy", { kind = "walker" })
    step()
    local new = chain.state().dolls[#chain.state().dolls]
    assert(new.kind == "walker" and #new.bodies == 4)
    local ids = new.bodies
    sim.send("recall", { id = new.id })
    step()
    assert(not pcall(game.world.get, game.world, ids[1]), "recalled: its legs are gone")
  end,
  ["the jump drive is on the Jump Ship's bridge, and the chain stays behind in its system"] = function()
    start()
    local universe = require("universe")
    local galaxy = require("fk.galaxy")
    local home, sector, target = universe.state().seed, universe.state().sector, nil
    for _, s in ipairs(galaxy.near(universe.view().star.position, universe.RANGE)) do
      if s.seed ~= home then target = s break end
    end
    sim.send("jump", { sector = target.sector, seed = target.seed })
    step()
    assert(universe.state().seed == home, "no jump from the Exosuit")
    local ship = find("jump_ship")
    chain.state().at = ship.id -- (the way up is tested above)
    sim.send("jump", { sector = target.sector, seed = target.seed })
    step(2)
    assert(universe.state().seed == target.seed and ship.system == target.seed, "the Jump Ship jumps")
    local walker = find("walker")
    assert(not chain.here(walker) and walker.bodies == nil and not chain.suit_out(), "the rest stays behind")
    assert(chain.teleport_target() == nil and chain.down() == nil and chain.draw({}, { 0, 0, 0 }) == 1)
    assert(chain.next_kind() == "space_station", "one station is still in the hold")
    sim.send("deploy", { kind = "space_station" })
    step()
    local station = chain.state().dolls[#chain.state().dolls]
    assert(station.system == target.seed and chain.here(station) and chain.teleport_target() == station.id)
    sim.send("jump", { sector = sector, seed = home })
    step(2)
    assert(chain.here(walker) and chain.suit_out() and walker.bodies, "back home: the chain is there again")
  end,
  ["the chain is saved and drawn"] = function()
    start()
    sim.send("board", { id = find("walker").id })
    step()
    local snap = sim.snapshot()
    sim.send("board", { id = chain.up() })
    step()
    sim.restore(snap)
    assert(chain.current().kind == "walker", "the saved chain comes back")
    assert(chain.draw({}, { 0, 2, 0 }) == 5, "every doll but the Exosuit")
    chain.tick("another/world")
    local w = find("walker")
    assert(math.abs(w.y - chain.ground(w.x, w.z)) < 1e-6, "on another world, on its ground")
  end,
}
