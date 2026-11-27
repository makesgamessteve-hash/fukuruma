-- The Exploration Walker (72 m): the agile giant on four legs, with manipulators, a sample bay and the Exosuit dock.
local HULL, DARK, GLASS = { 0.82, 0.62, 0.3 }, { 0.28, 0.27, 0.27 }, { 0.2, 0.3, 0.35 }
return {
  id = "walker", name = "Exploration Walker", size_m = 72, place = "ground", offset = { -260, 0, 160 },
  carries = { exosuit = 1 }, seat = { 0, 0.88, 0.32 }, roughness = 0.55, metalness = 0.4,
  cockpit = { width = 8, height = 5, depth = 7, posts = 2, screens = 3, color = { 0.55, 0.42, 0.24 } },
  controller = { kind = "legged", speed = 9, accel = 2.5, turn = 0.35, stride = 22 },
  hull = {
    { "legs", count = 4, at = { 0, 0.62, 0 }, spread = { 0.32, 0.2 }, length = 0.62, thick = 0.06, color = DARK },
    { "box", at = { 0, 0.72, 0 }, size = { 0.36, 0.2, 0.55 }, color = HULL },
    { "box", at = { 0, 0.86, 0.22 }, size = { 0.22, 0.1, 0.16 }, color = HULL },
    { "box", at = { 0, 0.87, 0.31 }, size = { 0.18, 0.06, 0.02 }, color = GLASS },
    { "box", at = { 0.2, 0.66, 0.3 }, size = { 0.04, 0.04, 0.3 }, color = DARK, mirror = true },
    { "greebles", at = { 0, 0.82, -0.12 }, size = { 0.3, 0.25 }, count = 24, height = 0.03, seed = 51, color = DARK },
  },
}
