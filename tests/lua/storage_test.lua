-- fk.storage (storage spec). The test runner keeps values in memory, never in the user's files.
local function fails(fn, pattern)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(pattern, 1, true), tostring(err))
end

return {
  ["round trip"] = function()
    fk.storage.save("graphics_test_value", "level=ultra")
    assert(fk.storage.load("graphics_test_value") == "level=ultra")
  end,
  ["missing values are nil"] = function()
    assert(fk.storage.load("never_saved") == nil)
  end,
  ["names are checked"] = function()
    fails(function() fk.storage.save("../evil", "x") end, "not a valid name")
    fails(function() fk.storage.save("Upper", "x") end, "not a valid name")
    fails(function() fk.storage.load("") end, "not a valid name")
    fails(function() fk.storage.save(string.rep("a", 65), "x") end, "not a valid name")
  end,
  ["values are limited to 64 KiB"] = function()
    fails(function() fk.storage.save("big", string.rep("x", 64 * 1024 + 1)) end, "larger than 64 KiB")
  end,
}
