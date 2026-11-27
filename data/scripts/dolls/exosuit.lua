-- The Exosuit (3.6 m): the Commander's armour on foot; on foot it is the suit of the range (main.lua), steered in
-- first person. Its hull here is what other dolls see of it.
local HULL, DARK = { 0.85, 0.85, 0.82 }, { 0.3, 0.3, 0.32 }
return {
  id = "exosuit", name = "Exosuit", size_m = 3.6, place = "ground", offset = { 40, 0, 30 },
  seat = { 0, 0.92, 0.05 }, roughness = 0.5, metalness = 0.3,
  hull = {
    { "box", at = { 0.12, 0.24, 0 }, size = { 0.12, 0.48, 0.14 }, color = DARK, mirror = true },
    { "box", at = { 0, 0.66, 0 }, size = { 0.42, 0.36, 0.26 }, color = HULL },
    { "box", at = { 0, 0.92, 0.02 }, size = { 0.2, 0.16, 0.2 }, color = HULL },
    { "box", at = { 0.27, 0.62, 0 }, size = { 0.1, 0.4, 0.12 }, color = DARK, mirror = true },
  },
}
