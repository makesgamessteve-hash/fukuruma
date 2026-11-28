-- The Exploration Walker (72 m): the agile giant on four legs, with manipulators, a sample bay and the Exosuit dock.
local HULL, PANEL, DARK, GLASS = { 0.84, 0.6, 0.26 }, { 0.66, 0.5, 0.28 }, { 0.22, 0.22, 0.24 }, { 0.15, 0.24, 0.3 }
local LAMP, BEACON = { 1, 0.92, 0.7 }, { 1, 0.3, 0.15 }
return {
  id = "walker", name = "Exploration Walker", size_m = 72, place = "ground", offset = { -260, 0, 160 },
  carries = { exosuit = 1 }, seat = { 0, 0.88, 0.32 }, roughness = 0.5, metalness = 0.45,
  sensors = { range = 2000, resolution = 0.5, kinds = { "thermal", "bio", "seismic", "EM" } }, -- (sensor-system spec: how far, how small, which signatures)
  cockpit = { width = 8, height = 5, depth = 7, posts = 2, screens = 3, color = { 0.55, 0.42, 0.24 } },
  controller = { kind = "legged", speed = 9, accel = 2.5, turn = 0.35, stride = 22 },
  hull = {
    { "legs", count = 4, at = { 0, 0.64, 0 }, spread = { 0.34, 0.22 }, length = 0.64, thick = 0.055, color = PANEL, joint = DARK },
    { "box", at = { 0.2, 0.655, 0 }, size = { 0.1, 0.09, 0.56 }, color = DARK, mirror = true }, -- the hip rails
    -- the chassis: an armoured belly, the main hull, its side armour and top deck
    { "taper", at = { 0, 0.6, -0.01 }, size = { 0.22, 0.05, 0.38 }, top = { 0.38, 0.56 }, color = DARK },
    { "taper", at = { 0, 0.7, 0 }, size = { 0.42, 0.16, 0.6 }, top = { 0.34, 0.5 }, color = HULL },
    { "taper", at = { 0.2, 0.7, 0 }, size = { 0.05, 0.12, 0.5 }, top = { 0.02, 0.42 }, shift = { 0.01, 0 }, color = PANEL, mirror = true },
    { "box", at = { 0, 0.785, -0.04 }, size = { 0.3, 0.02, 0.38 }, color = PANEL },
    { "greebles", at = { 0, 0.795, -0.08 }, size = { 0.26, 0.26 }, count = 30, height = 0.025, seed = 51, color = DARK },
    { "greebles", at = { 0.225, 0.7, -0.05 }, size = { 0.08, 0.3 }, count = 14, height = 0.012, seed = 52, face = "right", color = DARK },
    { "greebles", at = { -0.225, 0.7, -0.05 }, size = { 0.08, 0.3 }, count = 14, height = 0.012, seed = 53, face = "left", color = DARK },
    -- the cockpit module (its front ends behind the seat; the view ahead is the cockpit's own windows)
    { "taper", at = { 0, 0.845, 0.2 }, size = { 0.24, 0.1, 0.22 }, top = { 0.19, 0.17 }, shift = { 0, -0.02 }, color = HULL },
    { "taper", at = { 0, 0.82, 0.33 }, size = { 0.2, 0.04, 0.06 }, top = { 0.17, 0.02 }, shift = { 0, -0.02 }, color = PANEL },
    { "box", at = { 0, 0.875, 0.309 }, size = { 0.17, 0.035, 0.006 }, color = GLASS },
    { "box", at = { 0.105, 0.86, 0.22 }, size = { 0.006, 0.03, 0.14 }, color = GLASS, mirror = true },
    { "box", at = { 0.085, 0.8, 0.32 }, size = { 0.03, 0.015, 0.01 }, color = LAMP, glow = true, mirror = true },
    -- manipulator arms under the cockpit
    { "ball", at = { 0.13, 0.66, 0.28 }, r = 0.03, color = DARK, mirror = true },
    { "strut", from = { 0.13, 0.66, 0.28 }, to = { 0.17, 0.6, 0.38 }, size = { 0.03, 0.035 }, color = PANEL, mirror = true },
    { "ball", at = { 0.17, 0.6, 0.38 }, r = 0.022, color = DARK, mirror = true },
    { "strut", from = { 0.17, 0.6, 0.38 }, to = { 0.15, 0.54, 0.44 }, size = { 0.024, 0.026 }, color = PANEL, mirror = true },
    { "taper", at = { 0.15, 0.525, 0.45 }, size = { 0.02, 0.03, 0.04 }, top = { 0.04, 0.05 }, color = DARK, mirror = true },
    -- the sample bay pod at the back, the Exosuit dock, vents
    { "lathe", at = { 0, 0.69, -0.33 }, stations = { { -0.08, 0.04 }, { -0.06, 0.08 }, { 0.04, 0.08 }, { 0.06, 0.06 } }, sides = 12, color = PANEL },
    { "torus", at = { 0, 0.69, -0.36 }, axis = "z", r = 0.08, tube = 0.008, sides = 6, segments = 16, color = DARK },
    { "box", at = { 0.215, 0.66, 0.12 }, size = { 0.02, 0.08, 0.08 }, color = DARK, mirror = true },
    { "box", at = { 0, 0.75, -0.305 }, size = { 0.05, 0.01, 0.01 }, color = BEACON, glow = true, array = { 3, { 0, -0.025, 0 } } },
    -- the sensor mast: a dish, an antenna and a beacon
    { "strut", from = { 0.09, 0.79, 0.04 }, to = { 0.09, 0.95, 0.04 }, size = { 0.014, 0.014 }, color = DARK },
    { "lathe", axis = "y", at = { 0.09, 0.95, 0.04 }, stations = { { 0, 0.006 }, { 0.012, 0.045 }, { 0.016, 0.048 } }, sides = 14, color = HULL },
    { "strut", from = { -0.1, 0.79, -0.12 }, to = { -0.1, 1.0, -0.12 }, size = { 0.006, 0.006 }, color = DARK },
    { "ball", at = { -0.1, 1.0, -0.12 }, r = 0.008, color = BEACON, glow = true },
  },
}
