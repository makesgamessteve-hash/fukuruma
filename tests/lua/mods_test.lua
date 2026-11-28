-- mods.lua and the VFS overlay (mods spec): the example mod beside the executable is found, overlays data/ and
-- registers its content.
require("main")
local mods = require("mods")
local research = require("research")
local sensors = require("sensors")

return {
  ["the example mod is loaded and registers its content"] = function()
    local found
    for _, m in ipairs(mods.list) do
      if m.folder == "example-mod" then found = m end
    end
    assert(found and found.name == "Example mod" and found.script == "example.init")
    local has
    for _, n in ipairs(research.tree) do has = has or n[1] == "long_ping" end
    assert(has and sensors.HAZARDS.crystal_bloom, "its research and its hazard kind")
    assert(require("example.init") == true, "its scripts resolve through the overlay")
  end,
  ["only plain folder names overlay data"] = function()
    assert(fk.vfs_mods({ "../escape", "a/b", "", "ok-mod" }) == 1)
    assert(fk.vfs_mods({ "example-mod" }) == 1)
    local before = #mods.list
    assert(#mods.load() == before and mods.run() >= 0)
  end,
}
