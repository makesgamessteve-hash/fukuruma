-- The example mod's content: what a mod adds goes through the game's registries, never by editing the game's files.
local research = require("research")
local sensors = require("sensors")

-- A research project: a longer ping for the Exosuit, from radiation samples (research/tree.lua's format).
research.register({ "long_ping", "LONG PING (EXAMPLE MOD)", needs = { radiation = 2 }, after = { "bio_sensors" }, time = 30,
  upgrade = { sensors = { kind = "exosuit", range = 1.5 } } })

-- A hazard kind the sensors know (sensors.lua's format); a mod would also place it, e.g. from sensors.world_hooks.
sensors.HAZARDS.crystal_bloom = { signature = "exotic", size = { 2, 6 }, stealth = 0.4, name = "CRYSTAL BLOOM" }

return true
