-- The Drop Ship (100 m): outside the chain, the Commander's shuttle between dolls where there is no teleporter. A ball
-- of a hull with an armoured belt, small fins, huge engines and huge hangar bay doors in its flanks and belly.
local HULL, PANEL, DARK, DOOR = { 0.8, 0.82, 0.86 }, { 0.58, 0.62, 0.68 }, { 0.2, 0.22, 0.26 }, { 0.34, 0.36, 0.4 }
local GLOW, WINDOW, NAV_R, NAV_G = { 0.45, 0.8, 1 }, { 1, 0.88, 0.6 }, { 1, 0.15, 0.1 }, { 0.2, 1, 0.3 }
return {
  id = "drop_ship", name = "Drop Ship", size_m = 100, place = "sky", offset = { 300, 120, 0 },
  sensors = { range = 2e5, resolution = 20, kinds = { "thermal", "EM", "seismic" } },
  seat = { 0, 0.48, 0.3 }, roughness = 0.35, metalness = 0.6, -- (just in front of the ball: nothing ahead of the eye)
  cockpit = { width = 6, height = 4.4, depth = 5, posts = 2, screens = 2, color = { 0.6, 0.62, 0.66 } },
  controller = { kind = "flight", speed = 180, accel = 25, turn = 0.45, climb = 120, min_altitude = 2 },
  hull = {
    -- the ball and its armoured belt
    { "ball", at = { 0, 0.4, 0 }, r = 0.3, sides = 24, color = HULL },
    { "torus", at = { 0, 0.4, 0 }, axis = "y", r = 0.3, tube = 0.022, sides = 8, segments = 40, color = PANEL },
    { "torus", at = { 0, 0.4, 0 }, axis = "z", r = 0.3, tube = 0.012, sides = 6, segments = 40, color = PANEL },
    { "greebles", at = { 0, 0.69, -0.04 }, size = { 0.18, 0.18 }, count = 24, height = 0.015, seed = 61, color = PANEL },
    -- the bridge's window band under the seat, and nav lights on the belt
    { "taper", at = { 0, 0.445, 0.27 }, size = { 0.16, 0.03, 0.05 }, top = { 0.14, 0.03 }, shift = { 0, -0.01 }, color = DARK },
    { "box", at = { 0, 0.445, 0.294 }, size = { 0.12, 0.01, 0.004 }, color = WINDOW, glow = true },
    { "ball", at = { 0.322, 0.4, 0 }, r = 0.012, color = NAV_G, glow = true },
    { "ball", at = { -0.322, 0.4, 0 }, r = 0.012, color = NAV_R, glow = true },
    -- huge hangar bay doors in both flanks, framed in lights
    { "box", at = { 0.27, 0.4, -0.02 }, size = { 0.07, 0.26, 0.3 }, color = DOOR, mirror = true },
    { "box", at = { 0.307, 0.31, -0.02 }, size = { 0.004, 0.006, 0.3 }, color = DARK, mirror = true, array = { 4, { 0, 0.06, 0 } } }, -- (door seams)
    { "box", at = { 0.307, 0.53, -0.02 }, size = { 0.006, 0.008, 0.3 }, color = GLOW, glow = true, mirror = true, array = { 2, { 0, -0.26, 0 } } },
    -- and a huge bay door in the belly, the ramp down to the ground
    { "taper", at = { 0, 0.13, 0.0 }, size = { 0.3, 0.05, 0.32 }, top = { 0.4, 0.42 }, color = DOOR },
    { "box", at = { 0, 0.104, 0.0 }, size = { 0.26, 0.004, 0.28 }, color = DARK },
    { "box", at = { 0, 0.1, 0.15 }, size = { 0.28, 0.006, 0.01 }, color = GLOW, glow = true, array = { 2, { 0, 0, -0.3 } } },
    -- small fins
    { "taper", at = { 0.14, 0.69, -0.16 }, size = { 0.02, 0.08, 0.1 }, top = { 0.01, 0.05 }, shift = { 0.02, -0.03 }, color = PANEL, mirror = true },
    { "taper", at = { 0.2, 0.18, -0.18 }, size = { 0.02, 0.07, 0.1 }, top = { 0.01, 0.05 }, shift = { 0.03, -0.03 }, color = PANEL, mirror = true },
    -- huge engines: two nacelles on short pylons and a big central engine, all glowing
    { "strut", from = { 0.2, 0.42, -0.18 }, to = { 0.36, 0.42, -0.24 }, size = { 0.08, 0.06 }, color = DARK, mirror = true },
    { "lathe", at = { 0.4, 0.42, -0.28 }, stations = { { 0.16, 0.06 }, { 0.12, 0.11 }, { -0.12, 0.13 }, { -0.2, 0.15 } }, sides = 16, color = PANEL, mirror = true },
    { "torus", at = { 0.4, 0.42, -0.42 }, axis = "z", r = 0.14, tube = 0.015, sides = 6, segments = 20, color = DARK, mirror = true },
    { "lathe", at = { 0.4, 0.42, -0.481 }, stations = { { 0, 0.13 }, { 0.002, 0.11 } }, sides = 16, color = GLOW, glow = true, mirror = true },
    { "lathe", at = { 0, 0.4, -0.3 }, stations = { { 0.06, 0.14 }, { -0.04, 0.17 }, { -0.12, 0.19 } }, sides = 18, color = DARK },
    { "lathe", at = { 0, 0.4, -0.421 }, stations = { { 0, 0.17 }, { 0.002, 0.15 } }, sides = 18, color = GLOW, glow = true },
    -- landing legs
    { "strut", from = { 0.18, 0.2, 0.14 }, to = { 0.26, 0.02, 0.2 }, size = { 0.025, 0.025 }, color = DARK, mirror = true },
    { "strut", from = { 0.18, 0.2, -0.14 }, to = { 0.26, 0.02, -0.2 }, size = { 0.025, 0.025 }, color = DARK, mirror = true },
    { "taper", at = { 0.26, 0.01, 0.2 }, size = { 0.07, 0.02, 0.07 }, top = { 0.04, 0.04 }, color = DARK, mirror = true },
    { "taper", at = { 0.26, 0.01, -0.2 }, size = { 0.07, 0.02, 0.07 }, top = { 0.04, 0.04 }, color = DARK, mirror = true },
  },
}
