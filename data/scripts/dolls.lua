-- The doll registry (doll-chain spec): every doll of the Fukuruma chain is Lua data, one file each in dolls/, and
-- mods add their own with dolls.register. A definition:
--   id, name, size_m (height, or length for ships), carries = {kind = count} (what it holds docked at the start),
--   place = "ground" | "sky" | "orbit" (where it stands once deployed), offset = {x, y, z} (metres from the doll
--   that deploys it; y: height above the ground or the parent), seat = {x, y, z} (the Commander's eye at its
--   controls, in units of size_m), hull = {parts} (dolls/hull.lua), roughness, metalness, cockpit (dolls/cockpit.lua;
--   none for the Exosuit, which is steered on foot), controller (chain.lua: legged, flight, orbit or fixed).
local dolls = { list = {}, by_id = {} }

local PLACES = { ground = true, sky = true, orbit = true }

function dolls.register(def)
  if type(def.id) ~= "string" or dolls.by_id[def.id] then error("dolls.register: a new string 'id' is needed", 2) end
  if type(def.size_m) ~= "number" or def.size_m <= 0 then error("dolls.register: " .. def.id .. " needs 'size_m' above 0", 2) end
  if not PLACES[def.place] then error("dolls.register: " .. def.id .. " needs 'place' ground, sky or orbit", 2) end
  def.carries, def.offset, def.seat, def.hull = def.carries or {}, def.offset or { 0, 0, 0 }, def.seat or { 0, 1, 0 }, def.hull or {}
  dolls.list[#dolls.list + 1] = def
  dolls.by_id[def.id] = def
  return def
end

-- The doll whose carries holds kind (the one that deploys it), or nil.
function dolls.parent_of(kind)
  for _, d in ipairs(dolls.list) do
    if d.carries[kind] then return d end
  end
end

for _, name in ipairs({ "jump_ship", "space_station", "continental_explorer", "land_explorer", "walker", "exosuit",
  "drop_ship" }) do
  dolls.register(require("dolls." .. name))
end

return dolls
