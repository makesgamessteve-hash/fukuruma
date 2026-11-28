-- The Space Station (31 km): deployed into orbit over one planet, its base; it holds Continental Explorers.
local HULL, DARK, GLOW = { 0.72, 0.74, 0.78 }, { 0.36, 0.38, 0.42 }, { 0.4, 0.85, 1 }
return {
  id = "space_station", name = "Space Station", size_m = 31000, place = "orbit", offset = { 0, 4.0e5, 0 },
  carries = { continental_explorer = 2, drop_ship = 1 }, seat = { 0, 0.18, 0.3 }, roughness = 0.45, metalness = 0.6,
  sensors = { range = 1e7, resolution = 1e4, kinds = { "thermal", "EM", "seismic" } }, -- (sensor-system spec: how far, how small, which signatures)
  cockpit = { width = 18, height = 6, depth = 14, posts = 4, screens = 6, color = { 0.5, 0.52, 0.56 } },
  controller = { kind = "orbit" },
  hull = {
    { "lathe", axis = "y", at = { 0, 0, 0 }, stations = { { -0.5, 0.02 }, { -0.3, 0.08 }, { 0.3, 0.08 }, { 0.5, 0.02 } }, sides = 12, color = HULL },
    { "lathe", axis = "y", at = { 0, 0, 0 }, stations = { { -0.04, 0.42 }, { 0, 0.46 }, { 0.04, 0.42 }, { 0, 0.38 }, { -0.04, 0.42 } }, sides = 32, color = HULL },
    { "box", at = { 0.25, 0, 0 }, size = { 0.34, 0.025, 0.025 }, color = DARK, mirror = true },
    { "box", at = { 0, 0, 0.25 }, size = { 0.025, 0.025, 0.34 }, color = DARK },
    { "box", at = { 0, 0, -0.25 }, size = { 0.025, 0.025, 0.34 }, color = DARK },
    { "lathe", axis = "y", at = { 0, 0.5, 0 }, stations = { { 0, 0.03 }, { 0.04, 0 } }, sides = 8, color = GLOW },
    { "greebles", at = { 0, 0.3, 0 }, size = { 0.12, 0.12 }, count = 24, height = 0.02, seed = 21, color = DARK },
  },
}
