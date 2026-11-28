-- The Continental Explorer (6.7 km): a flying mountain that cruises low over a continent; it deploys Land Explorers.
local ROCK, HULL, GLOW = { 0.42, 0.4, 0.37 }, { 0.58, 0.58, 0.6 }, { 1, 0.7, 0.35 }
return {
  id = "continental_explorer", name = "Continental Explorer", size_m = 6700, place = "sky", offset = { 0, 3500, -14000 },
  carries = { land_explorer = 2, drop_ship = 1 }, seat = { 0, 0.3, 0.4 }, roughness = 0.75, metalness = 0.2,
  sensors = { range = 1e6, resolution = 50, kinds = { "thermal", "EM", "seismic", "bio" } }, -- (sensor-system spec: how far, how small, which signatures)
  cockpit = { width = 22, height = 7, depth = 14, posts = 5, screens = 6 },
  controller = { kind = "flight", speed = 250, accel = 15, turn = 0.08, climb = 60, min_altitude = 1500 },
  hull = {
    { "lathe", axis = "y", at = { 0, 0, 0 }, stations = { { -0.25, 0 }, { -0.18, 0.2 }, { -0.05, 0.36 }, { 0.02, 0.4 }, { 0.04, 0 } }, sides = 9, color = ROCK },
    { "box", at = { 0, 0.1, 0 }, size = { 0.62, 0.12, 0.8 }, color = HULL },
    { "box", at = { 0, 0.22, 0.25 }, size = { 0.3, 0.14, 0.2 }, color = HULL },
    { "lathe", at = { 0.33, 0.05, -0.38 }, stations = { { -0.05, 0.06 }, { 0, 0.08 }, { 0.06, 0.05 } }, sides = 10, color = GLOW, mirror = true },
    { "greebles", at = { 0, 0.16, -0.1 }, size = { 0.55, 0.5 }, count = 50, height = 0.03, seed = 31, color = HULL },
  },
}
