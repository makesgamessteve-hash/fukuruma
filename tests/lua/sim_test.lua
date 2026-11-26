-- fk.sim (simulation spec): commands, events, entities and the state hash.
local sim = require("fk.sim")

local game = {}
local function fails(fn, pattern)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(pattern, 1, true), tostring(err))
end

return {
  ["commands run at the start of the next tick, in order"] = function()
    sim.reset()
    local log = {}
    sim.on("a", function(args) log[#log + 1] = "a" .. args.n end)
    sim.on("b", function() log[#log + 1] = "b" end)
    game.tick = function()
      log[#log + 1] = "tick"
      if sim.tick == 0 then sim.send("b"); sim.send("a", { n = 1 }) end
    end
    sim.step(game)
    assert(table.concat(log, " ") == "tick")
    sim.step(game)
    assert(table.concat(log, " ") == "tick b a1 tick", table.concat(log, " "))
    assert(sim.tick == 2)
  end,
  ["commands sent by handlers wait for the following tick"] = function()
    sim.reset()
    local count = 0
    sim.on("again", function() count = count + 1; sim.send("again") end)
    sim.send("again")
    sim.step({})
    sim.step({})
    assert(count == 2)
  end,
  ["unknown command"] = function()
    sim.reset()
    sim.send("nobody")
    fails(function() sim.step({}) end, "no handler for command 'nobody'")
  end,
  ["arguments are validated"] = function()
    sim.reset()
    fails(function() sim.send("x", { f = print }) end, "args.f is a function")
    fails(function() sim.send("x", { n = 0 / 0 }) end, "args.n is not a finite number")
    fails(function() sim.send("x", { n = math.huge }) end, "not a finite number")
    fails(function() sim.send("x", { [true] = 1 }) end, "key that is not a string or an integer")
    fails(function() sim.send("x", { [1.5] = 1 }) end, "key that is not a string or an integer")
    local cycle = {}
    cycle.self = cycle
    fails(function() sim.send("x", cycle) end, "nested more than 8 levels")
    fails(function() sim.send(42) end, "a command needs a name")
  end,
  ["arguments are copied when sent"] = function()
    sim.reset()
    local got
    sim.on("set", function(args) got = args.list[1] end)
    local args = { list = { "before" }, flag = true }
    sim.send("set", args)
    args.list[1] = "after"
    sim.step({})
    assert(got == "before")
  end,
  ["events reach listeners after the tick, in order"] = function()
    sim.reset()
    local log = {}
    sim.listen("footstep", function(data) log[#log + 1] = "step" .. data.foot end)
    sim.listen("footstep", function() log[#log + 1] = "second listener" end)
    game.tick = function()
      sim.emit("footstep", { foot = 1 })
      sim.emit("footstep", { foot = 2 })
      sim.emit("nobody listens", {})
      log[#log + 1] = "tick done"
    end
    sim.step(game)
    assert(table.concat(log, ",") == "tick done,step1,second listener,step2,second listener", table.concat(log, ","))
  end,
  ["entity ids are never reused"] = function()
    sim.reset()
    local a, b = sim.create(), sim.create()
    sim.destroy(a)
    local c = sim.create()
    assert(c > a and c > b and sim.alive(b) and not sim.alive(a))
  end,
  ["components follow their entity"] = function()
    sim.reset()
    local a, b, c = sim.create(), sim.create(), sim.create()
    sim.set(a, "pos", { x = 1 })
    sim.set(b, "pos", { x = 2 })
    sim.set(c, "pos", { x = 3 })
    sim.set(b, "name", "b")
    sim.destroy(a)
    local seen = {}
    for id, pos in sim.each("pos") do seen[#seen + 1] = id .. "=" .. pos.x end
    assert(table.concat(seen, " ") == c .. "=3 " .. b .. "=2", table.concat(seen, " ")) -- swap-remove order
    assert(sim.get(a, "pos") == nil and sim.get(b, "name") == "b" and sim.get(b, "missing") == nil)
    sim.set(b, "name", nil)
    assert(sim.get(b, "name") == nil)
    sim.set(b, "name", nil) -- removing twice is harmless
    for _ in sim.each("never used") do error("no entities expected") end
    fails(function() sim.set(a, "pos", {}) end, "does not exist")
  end,
  ["entities can be destroyed while iterating"] = function()
    sim.reset()
    for _ = 1, 5 do sim.set(sim.create(), "tag", true) end
    local visited = 0
    for id in sim.each("tag") do sim.destroy(id); visited = visited + 1 end
    assert(visited == 5)
    for _ in sim.each("tag") do error("all destroyed") end
  end,
  ["the hash depends only on the state"] = function()
    local function build(order)
      sim.reset()
      local id = sim.create()
      local value = {}
      for _, k in ipairs(order) do value[k] = k == "f" and 0.5 or k end
      value.list, value.flag, value.int = { 1, 2, 3 }, false, 7
      sim.set(id, "data", value)
      return sim.hash()
    end
    local h1 = build({ "a", "b", "c", "f" })
    local h2 = build({ "f", "c", "b", "a" })
    assert(h1 == h2 and #h1 == 16)
    sim.set(1, "data", { int = 7.0 })
    assert(sim.hash() ~= h1)
    local float_hash = sim.hash()
    sim.set(1, "data", { int = 7 })
    assert(sim.hash() ~= float_hash, "integers and floats are different values")
  end,
  ["the hash rejects non-data"] = function()
    sim.reset()
    sim.set(sim.create(), "bad", { fn = print })
    fails(function() sim.hash() end, "contains a function")
  end,
}
