-- The Jump Ship (144 km): a moon-sized mothership parked in high orbit; it holds the Space Stations and a Drop Ship.
local HULL, DARK, GLOW = { 0.6, 0.63, 0.68 }, { 0.32, 0.34, 0.38 }, { 0.95, 0.6, 0.25 }
return {
  id = "jump_ship", name = "Jump Ship", size_m = 144000, place = "orbit", offset = { 0, 3.0e7, 0 },
  carries = { space_station = 2, drop_ship = 1 }, seat = { 0, 0.12, 0.42 }, roughness = 0.5, metalness = 0.5,
  sensors = { range = 1.5e13, resolution = 1e6, kinds = { "thermal", "EM", "exotic" } }, -- (sensor-system spec: how far, how small, which signatures)
  cockpit = { width = 28, height = 8, depth = 18, posts = 6, screens = 8, color = { 0.4, 0.42, 0.46 } },
  controller = { kind = "orbit" },
  hull = {
    { "lathe", at = { 0, 0, 0 }, stations = { { -0.5, 0 }, { -0.42, 0.07 }, { -0.1, 0.11 }, { 0.25, 0.09 }, { 0.5, 0 } }, sides = 10, color = HULL },
    { "lathe", at = { 0, 0, -0.18 }, stations = { { -0.03, 0.2 }, { 0, 0.215 }, { 0.03, 0.2 }, { 0, 0.185 }, { -0.03, 0.2 } }, sides = 24, color = GLOW },
    { "box", at = { 0.12, 0, -0.3 }, size = { 0.05, 0.05, 0.25 }, color = DARK, mirror = true },
    { "box", at = { 0, 0.1, 0.38 }, size = { 0.06, 0.04, 0.1 }, color = DARK },
    { "greebles", at = { 0, 0.095, 0.05 }, size = { 0.12, 0.5 }, count = 60, height = 0.012, seed = 11, color = DARK },
  },
}
