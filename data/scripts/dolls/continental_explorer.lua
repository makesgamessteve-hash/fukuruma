-- The Continental Explorer (6.7 km): a flying mountain that cruises low over a continent; it deploys Land Explorers.
-- A rock underside crowned with a city platform, citadel towers and the lift engines that hold it up.
local ROCK, ROCK2, HULL, DARK = { 0.4, 0.37, 0.34 }, { 0.32, 0.3, 0.28 }, { 0.62, 0.63, 0.66 }, { 0.26, 0.27, 0.3 }
local GLASS, GLOW, WINDOW = { 0.15, 0.2, 0.26 }, { 1, 0.62, 0.3 }, { 1, 0.85, 0.55 }
return {
  id = "continental_explorer", name = "Continental Explorer", size_m = 6700, place = "sky", offset = { 0, 3500, -14000 },
  carries = { land_explorer = 2 }, -- (the Drop Ship that brought it down carries it: it is the bigger one) seat = { 0, 0.3, 0.4 }, roughness = 0.7, metalness = 0.25,
  sensors = { range = 1e6, resolution = 50, kinds = { "thermal", "EM", "seismic", "bio" } }, -- (sensor-system spec: how far, how small, which signatures)
  cockpit = { width = 22, height = 7, depth = 14, posts = 5, screens = 6 },
  controller = { kind = "flight", speed = 250, accel = 15, turn = 0.08, climb = 60, min_altitude = 1500 },
  hull = {
    -- the mountain: a craggy inverted peak under a flat rim
    { "lathe", axis = "y", at = { 0, 0, 0 }, stations = { { -0.32, 0 }, { -0.26, 0.08 }, { -0.18, 0.2 }, { -0.08, 0.33 }, { 0.0, 0.4 }, { 0.04, 0.41 } }, sides = 11, color = ROCK },
    { "lathe", axis = "y", at = { 0.12, 0, 0.06 }, stations = { { -0.24, 0 }, { -0.14, 0.12 }, { -0.02, 0.2 } }, sides = 7, color = ROCK2 },
    { "lathe", axis = "y", at = { -0.1, 0, -0.1 }, stations = { { -0.27, 0 }, { -0.15, 0.1 }, { -0.03, 0.18 } }, sides = 7, color = ROCK2 },
    -- the city platform on top, its armoured rim and terraces
    { "lathe", axis = "y", at = { 0, 0.04, 0 }, stations = { { 0, 0.42 }, { 0.03, 0.43 }, { 0.06, 0.4 } }, sides = 24, color = HULL },
    { "taper", at = { 0, 0.12, 0 }, size = { 0.5, 0.06, 0.62 }, top = { 0.44, 0.54 }, color = HULL },
    { "taper", at = { 0, 0.18, -0.04 }, size = { 0.38, 0.06, 0.42 }, top = { 0.3, 0.34 }, color = HULL },
    { "torus", at = { 0, 0.09, 0 }, axis = "y", r = 0.41, tube = 0.006, segments = 48, color = WINDOW, glow = true },
    { "box", at = { 0.252, 0.12, 0 }, size = { 0.004, 0.01, 0.5 }, color = WINDOW, glow = true, mirror = true, array = { 2, { -0.01, 0.025, 0 } } },
    { "greebles", at = { 0, 0.15, -0.05 }, size = { 0.44, 0.52 }, count = 80, height = 0.025, seed = 31, color = DARK },
    { "greebles", at = { 0, 0.21, -0.04 }, size = { 0.28, 0.3 }, count = 40, height = 0.03, seed = 32, color = HULL },
    -- the citadel: towers and spires
    { "taper", at = { 0.1, 0.28, -0.1 }, size = { 0.06, 0.14, 0.06 }, top = { 0.03, 0.03 }, color = HULL, mirror = true },
    { "taper", at = { 0, 0.32, -0.16 }, size = { 0.08, 0.22, 0.08 }, top = { 0.02, 0.02 }, color = HULL },
    { "strut", from = { 0, 0.43, -0.16 }, to = { 0, 0.52, -0.16 }, size = { 0.004, 0.004 }, color = DARK },
    { "ball", at = { 0, 0.52, -0.16 }, r = 0.006, color = GLOW, glow = true },
    { "box", at = { 0.1, 0.3, -0.069 }, size = { 0.03, 0.004, 0.002 }, color = WINDOW, glow = true, mirror = true, array = { 3, { 0, -0.025, 0 } } },
    { "ball", at = { -0.16, 0.2, 0.16 }, r = 0.06, sides = 14, color = GLASS },
    -- the bridge at the front (it ends behind the seat; the view ahead is the cockpit's windows)
    { "taper", at = { 0, 0.26, 0.31 }, size = { 0.14, 0.1, 0.16 }, top = { 0.1, 0.1 }, shift = { 0, -0.02 }, color = HULL },
    { "taper", at = { 0, 0.2, 0.42 }, size = { 0.2, 0.06, 0.08 }, top = { 0.16, 0.02 }, shift = { 0, -0.03 }, color = HULL },
    { "box", at = { 0, 0.3, 0.389 }, size = { 0.09, 0.02, 0.002 }, color = GLASS },
    -- lift engines: four nacelles on pylons, glowing downwards, and thrusters at the back
    { "strut", from = { 0.25, 0.08, 0.2 }, to = { 0.38, 0.04, 0.26 }, size = { 0.03, 0.02 }, color = DARK, mirror = true },
    { "strut", from = { 0.25, 0.08, -0.2 }, to = { 0.38, 0.04, -0.26 }, size = { 0.03, 0.02 }, color = DARK, mirror = true },
    { "lathe", axis = "y", at = { 0.4, 0.0, 0.27 }, stations = { { -0.04, 0.05 }, { 0.0, 0.07 }, { 0.06, 0.06 }, { 0.08, 0.03 } }, sides = 14, color = HULL, mirror = true },
    { "lathe", axis = "y", at = { 0.4, 0.0, -0.27 }, stations = { { -0.04, 0.05 }, { 0.0, 0.07 }, { 0.06, 0.06 }, { 0.08, 0.03 } }, sides = 14, color = HULL, mirror = true },
    { "lathe", axis = "y", at = { 0.4, -0.045, 0.27 }, stations = { { 0, 0.045 }, { 0.002, 0.04 } }, sides = 14, color = GLOW, glow = true, mirror = true },
    { "lathe", axis = "y", at = { 0.4, -0.045, -0.27 }, stations = { { 0, 0.045 }, { 0.002, 0.04 } }, sides = 14, color = GLOW, glow = true, mirror = true },
    { "lathe", at = { 0.12, 0.1, -0.42 }, stations = { { -0.02, 0.03 }, { 0.06, 0.045 } }, sides = 12, color = DARK, mirror = true },
    { "lathe", at = { 0.12, 0.1, -0.443 }, stations = { { 0, 0.028 }, { 0.002, 0.025 } }, sides = 12, color = GLOW, glow = true, mirror = true },
    -- a docking bay in each flank
    { "box", at = { 0.252, 0.1, 0.12 }, size = { 0.01, 0.04, 0.1 }, color = DARK, mirror = true },
  },
}
