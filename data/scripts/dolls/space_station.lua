-- The Space Station (31 km): deployed into orbit over one planet, its base; it holds Continental Explorers. A spindle
-- with twin habitat rings on spokes, solar arrays, docking arms and the command arm with the bridge.
local HULL, PANEL, DARK, SOLAR = { 0.76, 0.78, 0.82 }, { 0.58, 0.6, 0.66 }, { 0.26, 0.28, 0.32 }, { 0.12, 0.16, 0.34 }
local GLOW, WINDOW, BEACON = { 0.4, 0.85, 1 }, { 1, 0.9, 0.65 }, { 1, 0.3, 0.15 }
return {
  id = "space_station", name = "Space Station", size_m = 31000, place = "orbit", offset = { 0, 4.0e5, 0 },
  carries = { continental_explorer = 2, drop_ship = 1 }, seat = { 0, 0.18, 0.3 }, roughness = 0.4, metalness = 0.65,
  sensors = { range = 1e7, resolution = 1e4, kinds = { "thermal", "EM", "seismic" } }, -- (sensor-system spec: how far, how small, which signatures)
  cockpit = { width = 18, height = 6, depth = 14, posts = 4, screens = 6, color = { 0.5, 0.52, 0.56 } },
  controller = { kind = "orbit" },
  hull = {
    -- the spindle: hub, modules and the docking spires at both ends
    { "lathe", axis = "y", at = { 0, 0, 0 }, stations = { { -0.5, 0.01 }, { -0.42, 0.03 }, { -0.3, 0.06 }, { -0.12, 0.08 }, { 0.12, 0.08 }, { 0.3, 0.06 }, { 0.42, 0.03 }, { 0.5, 0.01 } }, sides = 16, color = HULL },
    { "torus", at = { 0, 0.2, 0 }, axis = "y", r = 0.08, tube = 0.015, segments = 20, color = PANEL, array = { 2, { 0, -0.4, 0 } } },
    { "torus", at = { 0, 0.08, 0 }, axis = "y", r = 0.085, tube = 0.004, segments = 24, color = WINDOW, glow = true, array = { 2, { 0, -0.16, 0 } } },
    { "greebles", at = { 0, 0.12, 0.075 }, size = { 0.08, 0.2 }, count = 24, height = 0.01, seed = 21, face = "front", color = DARK },
    -- the habitat rings, their lit window belts and the spokes
    { "torus", at = { 0, 0.06, 0 }, axis = "y", r = 0.42, tube = 0.03, sides = 10, segments = 48, color = HULL },
    { "torus", at = { 0, -0.06, 0 }, axis = "y", r = 0.42, tube = 0.03, sides = 10, segments = 48, color = HULL },
    { "torus", at = { 0, 0.06, 0 }, axis = "y", r = 0.452, tube = 0.004, segments = 64, color = WINDOW, glow = true },
    { "torus", at = { 0, -0.06, 0 }, axis = "y", r = 0.452, tube = 0.004, segments = 64, color = WINDOW, glow = true },
    { "strut", from = { 0.07, 0.06, 0 }, to = { 0.4, 0.06, 0 }, size = { 0.02, 0.02 }, color = DARK, mirror = true, array = { 2, { 0, -0.12, 0 } } },
    { "strut", from = { 0, 0.06, 0.07 }, to = { 0, 0.06, 0.4 }, size = { 0.02, 0.02 }, color = DARK, array = { 2, { 0, -0.12, 0 } } },
    { "strut", from = { 0, 0.06, -0.07 }, to = { 0, 0.06, -0.4 }, size = { 0.02, 0.02 }, color = DARK, array = { 2, { 0, -0.12, 0 } } },
    { "strut", from = { 0.3, 0.06, 0 }, to = { 0.3, -0.06, 0 }, size = { 0.012, 0.012 }, color = DARK, mirror = true },
    -- solar arrays on trusses above and below
    { "strut", from = { 0, 0.36, 0 }, to = { 0.3, 0.36, 0 }, size = { 0.012, 0.012 }, color = DARK, mirror = true },
    { "box", at = { 0.2, 0.36, 0.06 }, size = { 0.16, 0.003, 0.1 }, color = SOLAR, mirror = true, array = { 2, { 0, 0, -0.12 } } },
    { "strut", from = { 0, -0.36, 0 }, to = { 0, -0.36, 0.3 }, size = { 0.012, 0.012 }, color = DARK },
    { "box", at = { 0.06, -0.36, 0.2 }, size = { 0.1, 0.003, 0.16 }, color = SOLAR, mirror = true },
    -- docking arms for the Continental Explorers
    { "strut", from = { 0.05, -0.22, 0 }, to = { 0.2, -0.28, 0 }, size = { 0.02, 0.02 }, color = PANEL, mirror = true },
    { "box", at = { 0.21, -0.28, 0 }, size = { 0.04, 0.03, 0.06 }, color = DARK, mirror = true },
    { "box", at = { 0.232, -0.28, 0 }, size = { 0.004, 0.008, 0.04 }, color = GLOW, glow = true, mirror = true },
    -- the command arm and its bridge (the bridge ends behind the seat)
    { "strut", from = { 0, 0.18, 0.06 }, to = { 0, 0.18, 0.24 }, size = { 0.03, 0.025 }, color = PANEL },
    { "taper", at = { 0, 0.18, 0.265 }, size = { 0.06, 0.04, 0.05 }, top = { 0.05, 0.04 }, color = HULL },
    { "box", at = { 0, 0.187, 0.29 }, size = { 0.04, 0.01, 0.002 }, color = WINDOW, glow = true },
    -- beacons at the spires
    { "ball", at = { 0, 0.5, 0 }, r = 0.008, color = BEACON, glow = true },
    { "ball", at = { 0, -0.5, 0 }, r = 0.008, color = GLOW, glow = true },
  },
}
