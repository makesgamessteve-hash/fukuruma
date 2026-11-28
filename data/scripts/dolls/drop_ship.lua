-- The Drop Ship (100 m): outside the chain, the Commander's shuttle between dolls where there is no teleporter. A sleek
-- lifting body with delta wings, twin tail fins, a canopy and three engines.
local HULL, PANEL, DARK, GLASS = { 0.82, 0.84, 0.88 }, { 0.62, 0.66, 0.72 }, { 0.22, 0.24, 0.28 }, { 0.12, 0.2, 0.28 }
local GLOW, NAV_R, NAV_G = { 0.45, 0.8, 1 }, { 1, 0.15, 0.1 }, { 0.2, 1, 0.3 }
return {
  id = "drop_ship", name = "Drop Ship", size_m = 100, place = "sky", offset = { 300, 120, 0 },
  sensors = { range = 2e5, resolution = 20, kinds = { "thermal", "EM", "seismic" } },
  seat = { 0, 0.12, 0.38 }, roughness = 0.35, metalness = 0.6,
  cockpit = { width = 6, height = 4.4, depth = 5, posts = 2, screens = 2, color = { 0.6, 0.62, 0.66 } },
  controller = { kind = "flight", speed = 180, accel = 25, turn = 0.45, climb = 120, min_altitude = 2 },
  hull = {
    -- the fuselage: a lifting body from the nose to the engine block
    { "lathe", at = { 0, 0.1, 0 }, stations = { { -0.46, 0.06 }, { -0.36, 0.1 }, { 0.0, 0.11 }, { 0.22, 0.095 }, { 0.32, 0.07 } }, sides = 10, color = HULL },
    { "taper", at = { 0, 0.06, -0.02 }, size = { 0.16, 0.06, 0.62 }, top = { 0.22, 0.66 }, color = PANEL },
    -- the nose, low in front of the canopy so the view ahead stays clear
    { "lathe", at = { 0, 0.065, 0.32 }, stations = { { 0, 0.045 }, { 0.1, 0.03 }, { 0.17, 0.01 } }, sides = 10, color = HULL },
    { "taper", at = { 0, 0.15, 0.27 }, size = { 0.12, 0.05, 0.12 }, top = { 0.08, 0.06 }, shift = { 0, -0.02 }, color = PANEL },
    { "box", at = { 0, 0.168, 0.33 }, size = { 0.08, 0.02, 0.004 }, color = GLASS },
    { "box", at = { 0.042, 0.16, 0.28 }, size = { 0.004, 0.02, 0.07 }, color = GLASS, mirror = true },
    -- delta wings with dark leading edges and nav lights at the tips
    { "taper", at = { 0.22, 0.07, -0.12 }, size = { 0.3, 0.02, 0.4 }, top = { 0.26, 0.34 }, shift = { 0.01, -0.02 }, color = HULL, mirror = true },
    { "strut", from = { 0.08, 0.075, 0.1 }, to = { 0.36, 0.075, -0.24 }, size = { 0.016, 0.022 }, color = DARK, mirror = true },
    { "box", at = { 0.37, 0.075, -0.28 }, size = { 0.012, 0.012, 0.03 }, color = NAV_G, glow = true },
    { "box", at = { -0.37, 0.075, -0.28 }, size = { 0.012, 0.012, 0.03 }, color = NAV_R, glow = true },
    -- twin tail fins
    { "taper", at = { 0.07, 0.2, -0.36 }, size = { 0.02, 0.14, 0.18 }, top = { 0.01, 0.08 }, shift = { 0.02, -0.06 }, color = HULL, mirror = true },
    -- the engine block: three nozzles glowing blue
    { "box", at = { 0, 0.1, -0.44 }, size = { 0.26, 0.1, 0.08 }, color = DARK },
    { "lathe", at = { 0.08, 0.1, -0.5 }, stations = { { -0.03, 0.045 }, { 0.03, 0.035 } }, sides = 12, color = DARK, mirror = true },
    { "lathe", at = { 0, 0.11, -0.5 }, stations = { { -0.03, 0.04 }, { 0.03, 0.032 } }, sides = 12, color = DARK },
    { "lathe", at = { 0.08, 0.1, -0.531 }, stations = { { 0, 0.04 }, { 0.002, 0.036 } }, sides = 12, color = GLOW, glow = true, mirror = true },
    { "lathe", at = { 0, 0.11, -0.531 }, stations = { { 0, 0.035 }, { 0.002, 0.03 } }, sides = 12, color = GLOW, glow = true },
    -- landing gear, RCS blocks and a sensor blister
    { "strut", from = { 0.07, 0.04, 0.12 }, to = { 0.08, -0.01, 0.12 }, size = { 0.012, 0.012 }, color = DARK, mirror = true },
    { "strut", from = { 0.07, 0.04, -0.25 }, to = { 0.09, -0.01, -0.25 }, size = { 0.014, 0.014 }, color = DARK, mirror = true },
    { "box", at = { 0.085, -0.012, 0.12 }, size = { 0.03, 0.008, 0.05 }, color = DARK, mirror = true },
    { "box", at = { 0.095, -0.012, -0.25 }, size = { 0.035, 0.008, 0.06 }, color = DARK, mirror = true },
    { "box", at = { 0.11, 0.12, 0.08 }, size = { 0.02, 0.02, 0.03 }, color = DARK, mirror = true },
    { "ball", at = { 0, 0.04, 0.05 }, r = 0.035, color = DARK },
    { "greebles", at = { 0, 0.2, -0.15 }, size = { 0.12, 0.3 }, count = 18, height = 0.012, seed = 61, color = PANEL },
  },
}
