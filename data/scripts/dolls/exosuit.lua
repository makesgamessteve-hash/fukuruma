-- The Exosuit (3.6 m): the Commander's armour on foot; on foot it is the suit of the range (main.lua), steered in
-- first person. Its hull here is what other dolls see of it: an armoured humanoid with a glowing visor.
local HULL, PLATE, DARK, VISOR = { 0.86, 0.86, 0.83 }, { 0.92, 0.55, 0.18 }, { 0.22, 0.23, 0.26 }, { 0.4, 0.9, 1 }
return {
  id = "exosuit", name = "Exosuit", size_m = 3.6, place = "ground", offset = { 40, 0, 30 },
  seat = { 0, 0.92, 0.05 }, roughness = 0.45, metalness = 0.35,
  sensors = { range = 150, resolution = 0.01, kinds = { "thermal", "bio", "EM", "seismic", "chemical", "exotic" } },
  hull = {
    -- legs: thigh and shin on joints, armoured knees, boots
    { "ball", at = { 0.09, 0.5, 0 }, r = 0.055, color = DARK, mirror = true },
    { "strut", from = { 0.09, 0.5, 0 }, to = { 0.1, 0.28, 0.02 }, size = { 0.08, 0.09 }, color = HULL, mirror = true },
    { "ball", at = { 0.1, 0.28, 0.02 }, r = 0.045, color = DARK, mirror = true },
    { "taper", at = { 0.1, 0.29, 0.06 }, size = { 0.07, 0.08, 0.03 }, top = { 0.05, 0.02 }, color = PLATE, mirror = true },
    { "strut", from = { 0.1, 0.28, 0.02 }, to = { 0.1, 0.05, -0.01 }, size = { 0.07, 0.08 }, color = HULL, mirror = true },
    { "taper", at = { 0.1, 0.025, 0.02 }, size = { 0.1, 0.05, 0.17 }, top = { 0.08, 0.12 }, color = DARK, mirror = true },
    -- pelvis, torso and chest plate
    { "taper", at = { 0, 0.52, 0 }, size = { 0.22, 0.08, 0.14 }, top = { 0.26, 0.16 }, color = DARK },
    { "taper", at = { 0, 0.66, 0 }, size = { 0.26, 0.22, 0.17 }, top = { 0.4, 0.22 }, color = HULL },
    { "taper", at = { 0, 0.69, 0.1 }, size = { 0.2, 0.16, 0.03 }, top = { 0.3, 0.02 }, shift = { 0, -0.01 }, color = PLATE },
    { "box", at = { 0, 0.8, -0.13 }, size = { 0.26, 0.2, 0.1 }, color = DARK }, -- backpack
    { "lathe", axis = "y", at = { 0.08, 0.73, -0.18 }, stations = { { 0, 0.03 }, { 0.12, 0.03 } }, sides = 8, color = HULL, mirror = true },
    { "box", at = { 0, 0.82, -0.19 }, size = { 0.12, 0.04, 0.02 }, color = VISOR, glow = true },
    -- shoulders and arms
    { "ball", at = { 0.21, 0.76, 0 }, r = 0.06, color = PLATE, mirror = true },
    { "taper", at = { 0.22, 0.8, 0 }, size = { 0.12, 0.05, 0.14 }, top = { 0.09, 0.1 }, color = PLATE, mirror = true },
    { "strut", from = { 0.22, 0.75, 0 }, to = { 0.25, 0.58, 0.02 }, size = { 0.06, 0.06 }, color = HULL, mirror = true },
    { "ball", at = { 0.25, 0.58, 0.02 }, r = 0.035, color = DARK, mirror = true },
    { "strut", from = { 0.25, 0.58, 0.02 }, to = { 0.25, 0.44, 0.07 }, size = { 0.065, 0.065 }, color = HULL, mirror = true },
    { "box", at = { 0.25, 0.42, 0.08 }, size = { 0.06, 0.05, 0.06 }, color = DARK, mirror = true },
    -- helmet with its visor
    { "strut", from = { 0, 0.78, 0 }, to = { 0, 0.86, 0.01 }, size = { 0.08, 0.08 }, color = DARK },
    { "ball", at = { 0, 0.92, 0.01 }, r = 0.09, sides = 12, color = HULL },
    { "taper", at = { 0, 0.925, 0.075 }, size = { 0.13, 0.05, 0.03 }, top = { 0.1, 0.02 }, color = VISOR, glow = true },
    { "strut", from = { 0.06, 0.96, -0.02 }, to = { 0.07, 1.06, -0.04 }, size = { 0.012, 0.012 }, color = DARK },
  },
}
