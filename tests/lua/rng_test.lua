-- fk.rng and fk.hash (simulation spec: random streams). The test runner uses world seed 1.
return {
  ["recorded sequence for seed 1 and key 'test'"] = function()
    local r = fk.rng("test")
    assert(r:int() == 7782953607450231717 and r:int() == 340023469424535954 and r:int() == 885364895529590449)
  end,
  ["same keys give the same numbers"] = function()
    local a, b = fk.rng("weather", 3), fk.rng("weather", 3)
    for _ = 1, 100 do assert(a:int() == b:int()) end
  end,
  ["different keys give different numbers"] = function()
    assert(fk.rng("weather", 3):int() ~= fk.rng("weather", 4):int())
    assert(fk.rng("1"):int() ~= fk.rng(1):int())
  end,
  ["floats are in [0, 1)"] = function()
    local r = fk.rng("floats")
    for _ = 1, 1000 do local f = r:float(); assert(f >= 0 and f < 1) end
  end,
  ["ranges include both bounds"] = function()
    local r, seen = fk.rng("dice"), {}
    for _ = 1, 1000 do local v = r:range(1, 6); assert(v >= 1 and v <= 6); seen[v] = true end
    for v = 1, 6 do assert(seen[v]) end
    assert(r:range(7, 7) == 7)
    assert(math.type(r:range(math.mininteger, math.maxinteger)) == "integer")
  end,
  ["range rejects reversed bounds"] = function()
    assert(not pcall(function() fk.rng("x"):range(5, 1) end))
  end,
  ["chance"] = function()
    local r = fk.rng("chance")
    assert(r:chance(1) and not r:chance(0))
  end,
  ["keys must be strings or integers"] = function()
    assert(not pcall(fk.rng, 1.5))
    assert(not pcall(fk.rng))
    assert(not pcall(fk.hash, {}))
  end,
  ["hash is stable"] = function()
    assert(fk.hash("test") == -6364794010310347860 and fk.hash(1, "a") == -2129633123755272495)
    assert(fk.hash("a", 1) ~= fk.hash(1, "a"))
  end,
}
