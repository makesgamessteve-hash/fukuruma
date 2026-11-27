-- The Land Explorer (1.44 km): a slow, armoured walking city, an expedition's base camp; it deploys Walkers.
local HULL, DARK, LIGHT = { 0.55, 0.5, 0.42 }, { 0.3, 0.28, 0.26 }, { 1, 0.85, 0.55 }
return {
  id = "land_explorer", name = "Land Explorer", size_m = 1440, place = "ground", offset = { 900, 0, 4200 },
  carries = { walker = 2 }, seat = { 0, 0.93, 0.34 }, roughness = 0.7, metalness = 0.35,
  hull = {
    { "legs", count = 6, at = { 0, 0.5, 0 }, spread = { 0.42, 0.3 }, length = 0.5, thick = 0.07, color = DARK },
    { "box", at = { 0, 0.6, 0 }, size = { 0.55, 0.2, 0.85 }, color = HULL },
    { "box", at = { 0, 0.76, 0.1 }, size = { 0.4, 0.12, 0.5 }, color = HULL },
    { "box", at = { 0, 0.86, 0.26 }, size = { 0.18, 0.08, 0.12 }, color = LIGHT },
    { "greebles", at = { 0, 0.82, -0.2 }, size = { 0.4, 0.3 }, count = 40, height = 0.04, seed = 41, color = DARK },
  },
}
