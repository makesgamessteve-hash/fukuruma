-- The Drop Ship (100 m): outside the chain, the Commander's shuttle between dolls where there is no teleporter.
local HULL, DARK, GLOW = { 0.78, 0.8, 0.84 }, { 0.3, 0.32, 0.36 }, { 0.5, 0.8, 1 }
return {
  id = "drop_ship", name = "Drop Ship", size_m = 100, place = "sky", offset = { 300, 120, 0 },
  sensors = { range = 2e5, resolution = 20, kinds = { "thermal", "EM", "seismic" } },
  seat = { 0, 0.12, 0.38 }, roughness = 0.4, metalness = 0.55,
  cockpit = { width = 6, height = 4.4, depth = 5, posts = 2, screens = 2, color = { 0.6, 0.62, 0.66 } },
  controller = { kind = "flight", speed = 180, accel = 25, turn = 0.45, climb = 120, min_altitude = 2 },
  hull = {
    { "lathe", at = { 0, 0.1, 0 }, stations = { { -0.5, 0.04 }, { -0.4, 0.1 }, { 0.2, 0.12 }, { 0.42, 0.07 }, { 0.5, 0 } }, sides = 8, color = HULL },
    { "box", at = { 0.2, 0.1, -0.1 }, size = { 0.3, 0.02, 0.3 }, color = HULL, mirror = true },
    { "lathe", at = { 0.12, 0.08, -0.45 }, stations = { { -0.06, 0.04 }, { 0, 0.05 } }, sides = 8, color = GLOW, mirror = true },
    { "box", at = { 0, 0.2, 0.25 }, size = { 0.08, 0.04, 0.12 }, color = DARK },
  },
}
