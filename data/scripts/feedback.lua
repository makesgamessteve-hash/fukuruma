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
  -- The suit's excavator blasting a hole: a fountain of earth and stones, an orange flash, a heavy jolt and rumble.
  dig = {
    particles = {
      { count = 60, radius = 1.2, direction = { 0, 1, 0 }, spread = 0.9, speed_min = 3, speed_max = 9, life_min = 0.8,
        life_max = 1.6, size = 0.35, size_end = 0.8, gravity = 9, drag = 0.8, color = { 0.42, 0.34, 0.26 }, alpha = 0.9,
        alpha_end = 0 },
      { count = 30, radius = 1.5, direction = { 0, 1, 0 }, spread = 1.4, speed_min = 0.5, speed_max = 2, life_min = 1.2,
        life_max = 2.4, size = 0.8, size_end = 2.4, gravity = -0.2, drag = 1.5, color = { 0.55, 0.5, 0.44 }, alpha = 0.5,
        alpha_end = 0 },
    },
    light = { color = { 1, 0.6, 0.25 }, intensity = 40, radius = 12, duration = 0.35, offset = { 0, 1, 0 } },
    trauma = 0.35,
    rumble = { 0.9, 0.5, 0.3 },
    sound = "dig",
  },
  -- A doll deployed out of the one the Commander is in: the hold's clamps let go (a jolt, a boom, a flash outside).
  deploy = { light = { color = { 1, 0.8, 0.5 }, intensity = 12, radius = 40, duration = 0.5, offset = { 0, 2, 0 } },
    trauma = 0.25, rumble = { 0.6, 0.3, 0.35 }, sound = "impact" },
  -- A doll taken back into its hold: a softer clunk, a short hum.
  recall = { trauma = 0.12, rumble = { 0.3, 0.2, 0.25 }, sound = "ui_open" },
  -- A Walker's or Land Explorer's foot coming down: the cabin jolts, the ground booms (scaled by the doll's size).
  stomp = {
    particles = { count = 40, radius = 6, direction = { 0, 1, 0 }, spread = 1.4, speed_min = 2, speed_max = 8,
      life_min = 1, life_max = 2.2, size = 2.5, size_end = 7, gravity = 0.8, drag = 1.2, color = { 0.6, 0.55, 0.47 },
      alpha = 0.6, alpha_end = 0 },
    trauma = 0.3,
    rumble = { 0.7, 0.25, 0.2 },
    sound = "impact",
  },
  -- Teleported between the Jump Ship and a station: a white flash, a hard shake, the drive's roar.
  teleport = { light = { color = { 0.8, 0.9, 1 }, intensity = 40, radius = 30, duration = 0.4, offset = { 0, 2, 0 } },
    trauma = 0.45, rumble = { 0.5, 0.8, 0.4 }, sound = "jump" },
  -- The autopilot takes over: a soft confirming chime and a light buzz in the sticks.
  autopilot = { trauma = 0.04, rumble = { 0.1, 0.3, 0.2 }, sound = "ui_confirm" },
  -- The autopilot has arrived: a scan-like ping and a nudge.
  arrived = { trauma = 0.1, rumble = { 0.2, 0.4, 0.2 }, sound = "scan" },
  -- The Commander at another doll's controls: the seat settles, the instruments chime.
  board = { trauma = 0.08, rumble = { 0.15, 0.25, 0.15 }, sound = "ui_confirm" },
  -- A door inside a doll slides: a light knock and a click.
  door = { trauma = 0.02, rumble = { 0.08, 0.1, 0.08 }, sound = "ui_move" },
  -- A hostile heard the ping: a sharp jolt and a warning.
  alerted = { trauma = 0.15, rumble = { 0.4, 0.2, 0.3 }, sound = "impact" },
  -- The autopilot stops for a hazard: a hard brake.
  hazard_stop = { trauma = 0.3, rumble = { 0.6, 0.4, 0.5 }, sound = "ui_open" },
  -- The suit is breached (a quarter of its integrity gone): a hard jolt, a red flash, a warning.
  breach = { trauma = 0.35, rumble = { 0.7, 0.5, 0.4 }, sound = "impact",
    light = { color = { 1, 0.15, 0.1 }, intensity = 20, radius = 8, duration = 0.4, offset = { 0, 2, 0 } } },
  -- Death: everything shakes and goes dark; the clone wakes to a soft chime.
  death = { trauma = 1, rumble = { 1, 1, 1 }, sound = "impact" },
  clone = { trauma = 0.1, rumble = { 0.2, 0.2, 0.3 }, sound = "ui_confirm" },
  -- Ground gives way under a doll: a deep lurch and a dust cloud.
  collapse = { trauma = 0.7, rumble = { 0.9, 0.7, 0.8 }, sound = "impact",
    particles = { { count = 80, radius = 6, direction = { 0, 1, 0 }, spread = 0.6, speed_min = 2, speed_max = 6, life_min = 1.5,
      life_max = 3, size = 1.5, size_end = 4, drag = 0.5, color = { 0.45, 0.4, 0.33 }, alpha = 0.7, alpha_end = 0 } } },
  -- A gas pocket explodes: a fireball, a flash and a blast.
  explosion = { trauma = 0.8, rumble = { 1, 0.8, 0.9 }, sound = "impact",
    particles = { { count = 120, radius = 1, direction = { 0, 1, 0 }, spread = 1, speed_min = 4, speed_max = 14, life_min = 0.4,
      life_max = 1.2, size = 1.2, size_end = 0.2, drag = 0.8, color = { 1, 0.55, 0.15 }, intensity = 12, alpha = 1, alpha_end = 0,
      glow = true } },
    light = { color = { 1, 0.6, 0.25 }, intensity = 120, radius = 40, duration = 0.5, offset = { 0, 2, 0 } } },
  -- A flare goes up: sparks and a red glow where it lands.
  flare = { trauma = 0.05, rumble = { 0.2, 0.1, 0.1 }, sound = "ui_open",
    particles = { { count = 40, radius = 0.3, direction = { 0, 1, 0 }, spread = 0.7, speed_min = 2, speed_max = 6, life_min = 0.5,
      life_max = 1.2, size = 0.2, size_end = 0.05, gravity = -6, color = { 1, 0.35, 0.15 }, intensity = 10, alpha = 1,
      alpha_end = 0, glow = true } },
    light = { color = { 1, 0.3, 0.1 }, intensity = 40, radius = 30, duration = 0.8, offset = { 0, 1, 0 } } },
  -- The stun pulse: a blue ring and a crackle.
  stun = { trauma = 0.12, rumble = { 0.3, 0.5, 0.2 }, sound = "scan",
    particles = { { count = 60, ring = true, direction = { 0, 1, 0 }, speed_min = 12, speed_max = 14, life_min = 0.3,
      life_max = 0.4, size = 0.25, size_end = 0.05, color = { 0.5, 0.7, 1 }, intensity = 10, alpha = 1, alpha_end = 0,
      glow = true } },
    light = { color = { 0.5, 0.7, 1 }, intensity = 30, radius = 16, duration = 0.3 } },
  -- A predator notices the Commander, or bites: a jolt.
  noticed = { trauma = 0.08, rumble = { 0.2, 0.1, 0.2 }, sound = "ui_move" },
  bite = { trauma = 0.45, rumble = { 0.8, 0.6, 0.3 }, sound = "impact" },
  -- Thieves: a doll taken, a doll recovered, boarders aboard, sectors sealed, boarders repelled, the cargo looted.
  theft = { trauma = 0.1, rumble = { 0.3, 0.2, 0.3 }, sound = "ui_open" },
  recovered = { trauma = 0.15, rumble = { 0.3, 0.3, 0.3 }, sound = "ui_confirm" },
  boarders = { trauma = 0.25, rumble = { 0.5, 0.4, 0.5 }, sound = "impact",
    light = { color = { 1, 0.15, 0.1 }, intensity = 15, radius = 12, duration = 1.2 } },
  sealed = { trauma = 0.12, rumble = { 0.4, 0.3, 0.4 }, sound = "ui_move" },
  repelled = { trauma = 0.05, rumble = { 0.2, 0.1, 0.1 }, sound = "ui_confirm" },
  looted = { trauma = 0.2, rumble = { 0.4, 0.3, 0.3 }, sound = "impact" },
  -- The ruin: a pylon wakes with a chime and a cyan flash; the artifact with a burst; the guardian with a red pulse.
  pylon = { trauma = 0.05, rumble = { 0.2, 0.2, 0.2 }, sound = "scan",
    light = { color = { 0.3, 0.9, 1 }, intensity = 30, radius = 12, duration = 0.6 } },
  artifact = { trauma = 0.3, rumble = { 0.5, 0.6, 0.5 }, sound = "scan",
    particles = { { count = 120, radius = 2, direction = { 0, 1, 0 }, spread = 0.8, speed_min = 3, speed_max = 9, life_min = 0.8,
      life_max = 1.6, size = 0.3, size_end = 0.05, drag = 0.6, color = { 0.4, 0.95, 1 }, intensity = 10, alpha = 1, alpha_end = 0,
      glow = true } },
    light = { color = { 0.4, 0.95, 1 }, intensity = 80, radius = 30, duration = 1.2 } },
  guardian = { trauma = 0.35, rumble = { 0.7, 0.5, 0.6 }, sound = "impact",
    light = { color = { 1, 0.2, 0.15 }, intensity = 60, radius = 40, duration = 0.5 } },
  -- A native's spear hits; a talk begins.
  spear = { trauma = 0.25, rumble = { 0.5, 0.3, 0.2 }, sound = "impact" },
  talk = { trauma = 0, rumble = { 0.05, 0.05, 0.05 }, sound = "ui_confirm" },
  -- The economy: a sale, a thing made, a sample taken, an outpost unpacked, research begun and done, a repair, a name.
  trade = { trauma = 0, rumble = { 0.05, 0.05, 0.05 }, sound = "ui_confirm" },
  crafted = { trauma = 0.05, rumble = { 0.2, 0.2, 0.2 }, sound = "dig" },
  sample = { trauma = 0.03, rumble = { 0.15, 0.1, 0.1 }, sound = "ui_move",
    light = { color = { 0.5, 1, 0.6 }, intensity = 8, radius = 4, duration = 0.3 } },
  outpost = { trauma = 0.2, rumble = { 0.5, 0.4, 0.4 }, sound = "impact",
    particles = { { count = 60, radius = 3, direction = { 0, 1, 0 }, spread = 0.6, speed_min = 1, speed_max = 3, life_min = 1,
      life_max = 2, size = 1, size_end = 2.5, drag = 0.5, color = { 0.5, 0.45, 0.4 }, alpha = 0.6, alpha_end = 0 } } },
  research_started = { trauma = 0, rumble = { 0.1, 0.1, 0.1 }, sound = "ui_open" },
  researched = { trauma = 0.05, rumble = { 0.2, 0.3, 0.2 }, sound = "scan" },
  repaired = { trauma = 0.05, rumble = { 0.2, 0.2, 0.2 }, sound = "ui_confirm" },
  named = { trauma = 0, rumble = { 0.05, 0.05, 0.05 }, sound = "ui_confirm" },
  -- The tram pulls away: a push and a hum.
  tram = { trauma = 0.1, rumble = { 0.3, 0.2, 0.4 }, sound = "ui_open" },
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
