-- Mods (mods spec; docs/MODDING.md). Each folder mods/<name>/ beside the executable with a mod.lua manifest is a mod:
-- its files overlay data/ (scripts, shaders, assets; the last mod in load order wins), and its script, if it names
-- one, runs once the game's modules are loaded, to register content with the game's registries. A manifest is data:
--   return { name = "Example", version = "1.0", order = 10 (load order, lowest first), script = "example.init",
--            enabled = true (false: skipped) }
local mods = { list = {} }

-- Reads the manifests and sets the overlay. Returns the mods in load order.
function mods.load()
  local list = {}
  for _, m in ipairs(fk.mods()) do
    if m.enabled ~= false then list[#list + 1] = m end
  end
  table.sort(list, function(a, b)
    local oa, ob = tonumber(a.order) or 0, tonumber(b.order) or 0
    if oa ~= ob then return oa < ob end
    return a.folder < b.folder
  end)
  local folders = {}
  for i, m in ipairs(list) do folders[i] = m.folder end
  fk.vfs_mods(folders)
  mods.list = list
  return list
end

-- Runs the mods' scripts (each once; a failing script is reported, not fatal). Returns how many ran.
function mods.run()
  local n = 0
  for _, m in ipairs(mods.list) do
    if type(m.script) == "string" then
      local ok, err = pcall(require, m.script)
      if ok then n = n + 1 else print("mod " .. m.folder .. ": " .. tostring(err)) end
    end
  end
  return n
end

return mods
