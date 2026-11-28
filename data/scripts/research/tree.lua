-- The research tree (research spec): {id, name, needs = {samples}, after = {ids done first}, time (seconds),
-- upgrade = what it changes}. Upgrades: sensors = {kind, range, resolution (factors), kinds (added)}; filter (how much
-- longer the filter lasts), armour (what the suit's integrity takes), jump (the drive's range). Mods add nodes with
-- research.register.
return {
  { "bio_sensors", "BIO-SENSORS", needs = { grazer = 1 }, time = 20,
    upgrade = { sensors = { kind = "exosuit", range = 2, resolution = 0.5 } } },
  { "chemical_mapping", "CHEMICAL MAPPING", needs = { gas_pocket = 1, vent = 1 }, time = 30,
    upgrade = { sensors = { kind = "walker", range = 1.5, kinds = { "chemical" } } } },
  { "filter_chemistry", "FILTER CHEMISTRY", needs = { gas_pocket = 2 }, after = { "chemical_mapping" }, time = 40,
    upgrade = { filter = 2 } },
  { "armour_weave", "ARMOUR WEAVE", needs = { predator = 1, radiation = 1 }, time = 45, upgrade = { armour = 0.7 } },
  { "drive_tuning", "DRIVE TUNING", needs = { exotic = 1 }, time = 60, upgrade = { jump = 1.5 } },
}
