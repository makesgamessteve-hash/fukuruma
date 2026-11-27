-- The feedback table (effects spec): what every event looks, sounds and feels like. Designers and modders
-- tune the game's feel here without touching code. See fk/feel.lua for the fields.
return {
  -- A 3.6 m Exosuit foot hitting the deck: a puff of dust, a thud, a little shake.
  footstep = {
    particles = { count = 10, radius = 0.15, direction = { 0, 1, 0 }, spread = 1.3, speed_min = 0.4, speed_max = 1.4,
      life_min = 0.5, life_max = 1.1, size = 0.25, size_end = 0.9, gravity = 0.6, drag = 2.5,
      color = { 0.62, 0.58, 0.52 }, alpha = 0.55, alpha_end = 0 },
    trauma = 0.06,
    rumble = { 0.25, 0.05, 0.07 },
    sound = "footstep",
  },
  -- Something heavy hitting the deck or the suit: a burst of grit, a boom, a jolt (scaled by how hard).
  impact = {
    particles = { count = 14, radius = 0.4, direction = { 0, 1, 0 }, spread = 1.5, speed_min = 0.8, speed_max = 2.4,
      life_min = 0.4, life_max = 0.9, size = 0.2, size_end = 0.7, gravity = 1.2, drag = 2, color = { 0.6, 0.56, 0.5 },
      alpha = 0.6, alpha_end = 0 },
    trauma = 0.12,
    rumble = { 0.45, 0.2, 0.12 },
    sound = "impact",
  },
  -- The Jump Ship's drive: a long, deep shake and rumble with the jump's roar.
  jump = { trauma = 0.6, rumble = { 0.8, 0.6, 0.9 }, sound = "jump" },
  -- The suit's sensor pulse: a ring of light racing over the ground, a cyan flash, a ping.
  scan = {
    particles = {
      { count = 90, ring = true, direction = { 0, 1, 0 }, speed_min = 9, speed_max = 10, life_min = 0.9, life_max = 1.0,
        size = 0.35, size_end = 0.1, drag = 0.6, color = { 0.4, 0.95, 1 }, intensity = 6, alpha = 1, alpha_end = 0,
        glow = true, offset = { 0, 0.15, 0 } },
      { count = 24, radius = 0.3, direction = { 0, 1, 0 }, spread = 0.5, speed_min = 1, speed_max = 3, life_min = 0.4,
        life_max = 0.8, size = 0.15, size_end = 0.02, gravity = -1, color = { 0.6, 1, 1 }, intensity = 8, alpha = 1,
        glow = true, offset = { 0, 3.4, 0 } },
    },
    light = { color = { 0.4, 0.9, 1 }, intensity = 30, radius = 14, duration = 0.6, offset = { 0, 2, 0 } },
    trauma = 0.22,
    rumble = { 0.35, 0.7, 0.18 },
    sound = "scan",
  },
}
