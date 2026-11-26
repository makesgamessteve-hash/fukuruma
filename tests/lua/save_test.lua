-- fk/save.lua and sim snapshots (save spec).
local save = require("fk.save")
local sim = require("fk.sim")

local function fails(fn, pattern)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(pattern, 1, true), tostring(err))
end

local function same(a, b)
  if type(a) ~= type(b) or math.type(a) ~= math.type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

return {
  ["values round-trip exactly"] = function()
    local value = { 1, 2.0, -0.1, 1 / 3, 1e300, -7, math.maxinteger, true, false, "a\"b\\c\nd\0e\127\255", {},
      nested = { deep = { deeper = { "x" } }, ["key with spaces"] = 3, [10] = "ten" }, ["end"] = 0.5 }
    local text = save.encode(value)
    assert(text:sub(1, 16) == "-- fukuruma save", "a readable header")
    local back = save.decode(text)
    assert(same(back, value), text)
    assert(math.type(back[2]) == "float" and math.type(back[1]) == "integer", "integers stay integers, floats floats")
    assert(save.decode(text:gsub("\n", "\r\n")) ~= nil, "Windows line breaks are fine")
  end,
  ["only plain data can be written"] = function()
    fails(function() save.encode({ f = print }) end, "cannot store a function")
    fails(function() save.encode({ 0 / 0 }) end, "a number is not finite")
  end,
  ["the parser accepts only what the writer writes"] = function()
    local cases = {
      { "return {}", "not a Fukuruma save" },
      { "-- fukuruma save\nprint('x')", "'return' expected" },
      { "-- fukuruma save\nreturn os.exit()", "a value expected" },
      { "-- fukuruma save\nreturn { a = 1 } junk", "text after the end" },
      { "-- fukuruma save\nreturn { a = 1 b = 2 }", "',' or '}' expected" },
      { "-- fukuruma save\nreturn { a 1 }", "'=' expected" },
      { "-- fukuruma save\nreturn { 'x' = 1 }", "a key expected" },
      { "-- fukuruma save\nreturn { [true] = 1 }", "keys must be strings or integers" },
      { "-- fukuruma save\nreturn { [1 = 1 }", "']' expected" },
      { "-- fukuruma save\nreturn { a = 1, a = 2 }", "a key appears twice" },
      { "-- fukuruma save\nreturn \"abc", "unfinished string" },
      { "-- fukuruma save\nreturn \"a\\qb\"", "bad escape" },
      { "-- fukuruma save\nreturn \"a\\999\"", "bad escape" },
      { "-- fukuruma save\nreturn 1e999", "a value expected" },
      { "-- fukuruma save\nreturn " .. string.rep("{ a = ", 30) .. "1" .. string.rep(" }", 30), "nested too deeply" },
    }
    for _, c in ipairs(cases) do fails(function() save.decode(c[1]) end, c[2]) end
    assert(save.decode("-- fukuruma save\n-- a comment\nreturn { a = \"\\65\\t\" } -- end") .a == "A\t")
  end,
  ["snapshots restore the simulation exactly, then run on the same way"] = function()
    sim.reset()
    sim.on("grow", function(args)
      for id, body in sim.each("body") do
        body.size = body.size * args.factor + id
        if body.size > 50 then sim.destroy(id) end
      end
    end)
    local rng = fk.rng("save test")
    for i = 1, 8 do
      local id = sim.create()
      sim.set(id, "body", { size = rng:float() * 10, name = "b" .. i, tags = { i, i * 2 } })
    end
    sim.create() -- an entity without components
    for _ = 1, 3 do
      sim.send("grow", { factor = 1.5 })
      sim.step({})
    end
    sim.send("grow", { factor = 1.25 }) -- queued, not yet applied
    local seed = fk.seed()
    local text = save.encode(save.snapshot({ note = "quick" }))
    local hash = sim.hash()
    for _ = 1, 5 do
      sim.send("grow", { factor = 2 })
      sim.step({})
    end
    local later = sim.hash()
    fk.seed(12345)
    assert(save.restore(save.decode(text)).note == "quick")
    assert(sim.hash() == hash and fk.seed() == seed, "the state and the seed are back")
    for _ = 1, 5 do -- the same commands again, including the queued one: the same result
      sim.send("grow", { factor = 2 })
      sim.step({})
    end
    assert(sim.hash() == later and later ~= hash, "the restored game runs on exactly as before")
    sim.reset()
  end,
  ["versions and slots"] = function()
    fails(function() save.restore({}) end, "no version")
    fails(function() save.restore({ version = save.VERSION + 1 }) end, "made by a newer version of the game")
    save.MIGRATIONS[0] = function(data) data.version, data.game = 1, { migrated = true } return data end
    sim.reset()
    local old = save.snapshot()
    old.version = 0
    assert(save.restore(old).migrated, "older saves are migrated")
    save.MIGRATIONS[0] = nil
    assert(save.read("never_written") == nil)
    save.write("slot_test", { x = 1 })
    assert(save.read("slot_test").x == 1)
    fails(function() save.write("Bad Slot") end, "slot names use a-z, 0-9 and _")
  end,
}
