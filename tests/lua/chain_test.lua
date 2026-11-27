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
    -- all the way up, and the Space Station's reach is the whole orbit
    for _ = 1, 3 do
      sim.send("board", { id = chain.up() })
      step()
    end
    assert(chain.current().kind == "jump_ship" and chain.up() == nil)
    assert(chain.next_kind() == "space_station", "stations before Drop Ships")
    sim.send("deploy", { kind = "drop_ship" })
    step()
    assert(chain.down() and find("drop_ship"), "a Drop Ship out")
    sim.send("board", { id = find("exosuit").id })
    step()
    assert(chain.current().kind == "jump_ship", "too far: the Exosuit is no child of the Jump Ship")
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
