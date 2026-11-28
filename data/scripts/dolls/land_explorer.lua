-- The Land Explorer (1.44 km): a slow, armoured walking city, an expedition's base camp; it deploys Walkers.
local HULL, DECK, DARK, GLASS = { 0.56, 0.52, 0.45 }, { 0.68, 0.64, 0.56 }, { 0.25, 0.24, 0.23 }, { 0.16, 0.22, 0.26 }
local WINDOW, BEACON = { 1, 0.82, 0.5 }, { 1, 0.3, 0.15 }
return {
  id = "land_explorer", name = "Land Explorer", size_m = 1440, place = "ground", offset = { 900, 0, 4200 },
  carries = { walker = 2 }, seat = { 0, 0.93, 0.34 }, roughness = 0.65, metalness = 0.35,
  sensors = { range = 3e4, resolution = 5, kinds = { "thermal", "bio", "seismic", "EM" } }, -- (sensor-system spec: how far, how small, which signatures)
  cockpit = { width = 16, height = 6, depth = 12, posts = 4, screens = 5, color = { 0.42, 0.38, 0.32 } },
  controller = { kind = "legged", speed = 5, accel = 0.6, turn = 0.06, stride = 320 },
  hull = {
    { "legs", count = 6, at = { 0, 0.52, 0 }, spread = { 0.44, 0.32 }, length = 0.52, thick = 0.07, color = HULL, joint = DARK },
    { "box", at = { 0.27, 0.53, 0 }, size = { 0.1, 0.1, 0.78 }, color = DARK, mirror = true },
    -- the hull: a broad armoured base, the city decks stepping up towards the bridge tower
    { "taper", at = { 0, 0.5, 0 }, size = { 0.4, 0.06, 0.66 }, top = { 0.58, 0.86 }, color = DARK },
    { "taper", at = { 0, 0.6, 0 }, size = { 0.6, 0.14, 0.88 }, top = { 0.54, 0.8 }, color = HULL },
    { "taper", at = { 0, 0.7, -0.04 }, size = { 0.5, 0.06, 0.7 }, top = { 0.42, 0.6 }, color = DECK },
    { "taper", at = { 0, 0.765, 0.0 }, size = { 0.36, 0.07, 0.48 }, top = { 0.3, 0.4 }, color = HULL },
    -- lit window bands along the decks, walker hangar doors in the flanks
    { "box", at = { 0.3, 0.61, 0 }, size = { 0.006, 0.012, 0.7 }, color = WINDOW, glow = true, mirror = true, array = { 3, { -0.002, 0.03, 0 } } },
    { "box", at = { 0.215, 0.71, -0.04 }, size = { 0.006, 0.01, 0.5 }, color = WINDOW, glow = true, mirror = true },
    { "box", at = { 0.29, 0.6, -0.2 }, size = { 0.02, 0.09, 0.14 }, color = DARK, mirror = true },
    { "box", at = { 0.3, 0.645, -0.2 }, size = { 0.012, 0.006, 0.12 }, color = BEACON, glow = true, mirror = true },
    -- domes, towers and cranes on the decks
    { "ball", at = { 0.14, 0.73, -0.24 }, r = 0.07, sides = 14, color = GLASS, mirror = true },
    { "ball", at = { 0, 0.8, -0.12 }, r = 0.06, sides = 14, color = GLASS },
    { "taper", at = { 0.12, 0.84, 0.0 }, size = { 0.06, 0.12, 0.06 }, top = { 0.03, 0.03 }, color = HULL, mirror = true },
    { "box", at = { 0.12, 0.88, 0.032 }, size = { 0.03, 0.006, 0.004 }, color = WINDOW, glow = true, mirror = true, array = { 3, { 0, -0.02, 0 } } },
    { "strut", from = { -0.22, 0.73, 0.2 }, to = { -0.22, 0.9, 0.22 }, size = { 0.012, 0.012 }, color = DARK },
    { "strut", from = { -0.22, 0.9, 0.22 }, to = { -0.12, 0.88, 0.34 }, size = { 0.01, 0.01 }, color = DARK },
    { "greebles", at = { 0, 0.8, -0.05 }, size = { 0.3, 0.38 }, count = 60, height = 0.02, seed = 41, color = DARK },
    { "greebles", at = { 0, 0.73, -0.3 }, size = { 0.4, 0.14 }, count = 30, height = 0.025, seed = 42, color = DECK },
    -- radiator fins at the back
    { "box", at = { 0.1, 0.72, -0.42 }, size = { 0.006, 0.08, 0.1 }, color = DARK, mirror = true, array = { 4, { 0.04, 0, 0 } } },
    -- the bridge tower at the front (its windows end behind the seat)
    { "taper", at = { 0, 0.86, 0.25 }, size = { 0.2, 0.12, 0.16 }, top = { 0.14, 0.12 }, shift = { 0, -0.01 }, color = HULL },
    { "box", at = { 0, 0.92, 0.325 }, size = { 0.13, 0.04, 0.006 }, color = GLASS },
    { "taper", at = { 0, 0.8, 0.36 }, size = { 0.22, 0.04, 0.08 }, top = { 0.18, 0.02 }, shift = { 0, -0.03 }, color = DECK },
    { "box", at = { 0.11, 0.81, 0.4 }, size = { 0.04, 0.02, 0.01 }, color = WINDOW, glow = true, mirror = true },
    { "strut", from = { 0, 0.96, 0.24 }, to = { 0, 1.06, 0.24 }, size = { 0.008, 0.008 }, color = DARK },
    { "ball", at = { 0, 1.06, 0.24 }, r = 0.01, color = BEACON, glow = true },
  },
}
