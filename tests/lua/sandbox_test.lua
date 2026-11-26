-- The script-runtime spec: game scripts cannot reach the file system or native code.
return {
  ["no io, os, debug or package"] = function()
    assert(io == nil and os == nil and debug == nil and package == nil)
  end,
  ["no dofile, loadfile or load"] = function()
    assert(dofile == nil and loadfile == nil and load == nil)
  end,
  ["no global random generator"] = function()
    assert(math.random == nil and math.randomseed == nil and math.sqrt ~= nil)
  end,
  ["io.open fails as a script error"] = function()
    local ok, err = pcall(function() return io.open("/etc/passwd") end)
    assert(not ok and err:find("io"))
  end,
  ["require rejects paths"] = function()
    for _, name in ipairs({ "../secret", "a..b", ".hidden", "a/b", "" }) do
      local ok, err = pcall(require, name)
      assert(not ok and err:find("not valid"), name)
    end
  end,
  ["require reports a missing module with its path"] = function()
    local ok, err = pcall(require, "does.not.exist")
    assert(not ok and err:find("data/scripts/does/not/exist.lua", 1, true))
  end,
  ["require caches modules"] = function()
    assert(require("mat4") == require("mat4"))
  end,
  ["fk.seed is the world seed"] = function()
    assert(math.type(fk.seed()) == "integer")
  end,
}
