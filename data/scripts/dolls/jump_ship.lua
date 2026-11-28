-- The Jump Ship (144 km): a moon-sized mothership parked in high orbit; it holds the Space Stations and a Drop Ship.
-- A long armoured spine with a hammerhead bow, the jump ring, hangar bays, radiator wings and a cluster of engines.
local HULL, PANEL, DARK = { 0.6, 0.63, 0.68 }, { 0.46, 0.49, 0.54 }, { 0.22, 0.24, 0.28 }
local RING, ENGINE, WINDOW, BEACON = { 0.95, 0.6, 0.25 }, { 0.5, 0.75, 1 }, { 1, 0.88, 0.6 }, { 1, 0.25, 0.15 }
return {
  id = "jump_ship", name = "Jump Ship", size_m = 144000, place = "orbit", offset = { 0, 3.0e7, 0 },
  carries = { space_station = 2, drop_ship = 1 }, seat = { 0, 0.12, 0.42 }, roughness = 0.45, metalness = 0.55,
  sensors = { range = 1.5e13, resolution = 1e6, kinds = { "thermal", "EM", "exotic" } }, -- (sensor-system spec: how far, how small, which signatures)
  cockpit = { width = 28, height = 8, depth = 18, posts = 6, screens = 8, color = { 0.4, 0.42, 0.46 } },
  controller = { kind = "orbit" },
  hull = {
    -- the spine and its armoured upper and lower decks
    { "lathe", at = { 0, 0, 0 }, stations = { { -0.42, 0.06 }, { -0.3, 0.08 }, { 0.1, 0.085 }, { 0.3, 0.07 } }, sides = 8, color = HULL },
    { "taper", at = { 0, 0.07, -0.02 }, size = { 0.14, 0.05, 0.66 }, top = { 0.1, 0.6 }, color = PANEL },
    { "taper", at = { 0, -0.07, -0.02 }, size = { 0.1, 0.05, 0.6 }, top = { 0.14, 0.66 }, color = PANEL },
    { "greebles", at = { 0, 0.095, -0.05 }, size = { 0.09, 0.56 }, count = 90, height = 0.01, seed = 11, color = DARK },
    { "greebles", at = { 0.085, 0, -0.05 }, size = { 0.1, 0.5 }, count = 50, height = 0.008, seed = 12, face = "right", color = DARK },
    { "greebles", at = { -0.085, 0, -0.05 }, size = { 0.1, 0.5 }, count = 50, height = 0.008, seed = 13, face = "left", color = DARK },
    -- the hammerhead bow, wide and armoured, low in front of the bridge
    { "taper", at = { 0, 0.0, 0.36 }, size = { 0.34, 0.08, 0.14 }, top = { 0.2, 0.1 }, shift = { 0, -0.01 }, color = HULL },
    { "taper", at = { 0, 0.03, 0.46 }, size = { 0.22, 0.05, 0.08 }, top = { 0.12, 0.03 }, shift = { 0, -0.02 }, color = PANEL },
    { "box", at = { 0.12, 0.0, 0.43 }, size = { 0.08, 0.01, 0.004 }, color = WINDOW, glow = true, mirror = true, array = { 3, { 0, -0.02, 0 } } },
    -- the bridge tower (it ends behind the seat)
    { "taper", at = { 0, 0.1, 0.36 }, size = { 0.08, 0.06, 0.1 }, top = { 0.05, 0.08 }, shift = { 0, -0.01 }, color = HULL },
    { "box", at = { 0, 0.125, 0.409 }, size = { 0.04, 0.008, 0.002 }, color = WINDOW, glow = true },
    { "strut", from = { 0.02, 0.13, 0.33 }, to = { 0.02, 0.2, 0.3 }, size = { 0.004, 0.004 }, color = DARK, mirror = true },
    -- the jump ring around the waist, glowing, on four struts
    { "torus", at = { 0, 0, -0.18 }, axis = "z", r = 0.21, tube = 0.014, sides = 8, segments = 40, color = DARK },
    { "torus", at = { 0, 0, -0.18 }, axis = "z", r = 0.21, tube = 0.008, sides = 8, segments = 40, color = RING, glow = true, array = { 2, { 0, 0, 0.03 } } },
    { "strut", from = { 0.06, 0.06, -0.18 }, to = { 0.15, 0.15, -0.18 }, size = { 0.02, 0.02 }, color = PANEL, mirror = true },
    { "strut", from = { 0.06, -0.06, -0.18 }, to = { 0.15, -0.15, -0.18 }, size = { 0.02, 0.02 }, color = PANEL, mirror = true },
    -- hangar bays along the flanks for the stations and the Drop Ship
    { "box", at = { 0.084, 0, 0.06 }, size = { 0.01, 0.07, 0.18 }, color = DARK, mirror = true },
    { "box", at = { 0.09, 0.03, 0.06 }, size = { 0.004, 0.004, 0.16 }, color = WINDOW, glow = true, mirror = true },
    -- radiator wings
    { "taper", at = { 0.18, 0, -0.06 }, size = { 0.2, 0.006, 0.16 }, top = { 0.18, 0.12 }, shift = { 0.01, -0.01 }, color = DARK, mirror = true },
    { "box", at = { 0.18, 0.004, -0.06 }, size = { 0.16, 0.002, 0.004 }, color = RING, glow = true, mirror = true, array = { 3, { 0, 0, -0.04 } } },
    -- the engine cluster at the stern
    { "taper", at = { 0, 0, -0.44 }, size = { 0.2, 0.2, 0.1 }, top = { 0.16, 0.08 }, color = PANEL },
    { "lathe", at = { 0.06, 0.05, -0.5 }, stations = { { -0.03, 0.035 }, { 0.03, 0.045 } }, sides = 12, color = DARK, mirror = true, array = { 2, { 0, -0.1, 0 } } },
    { "lathe", at = { 0, 0, -0.5 }, stations = { { -0.03, 0.05 }, { 0.03, 0.06 } }, sides = 14, color = DARK },
    { "lathe", at = { 0.06, 0.05, -0.531 }, stations = { { 0, 0.032 }, { 0.002, 0.028 } }, sides = 12, color = ENGINE, glow = true, mirror = true, array = { 2, { 0, -0.1, 0 } } },
    { "lathe", at = { 0, 0, -0.531 }, stations = { { 0, 0.045 }, { 0.002, 0.04 } }, sides = 14, color = ENGINE, glow = true },
    -- sensor spires and beacons
    { "strut", from = { 0, 0.09, 0.15 }, to = { 0, 0.16, 0.15 }, size = { 0.006, 0.006 }, color = DARK },
    { "ball", at = { 0, 0.16, 0.15 }, r = 0.006, color = BEACON, glow = true },
    { "strut", from = { 0, -0.09, -0.3 }, to = { 0, -0.14, -0.3 }, size = { 0.006, 0.006 }, color = DARK },
    { "ball", at = { 0, -0.14, -0.3 }, r = 0.005, color = BEACON, glow = true },
  },
}
