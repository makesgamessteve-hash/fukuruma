-- strings.lua (accessibility spec): text by key, with arguments, falling back to English and then to the key.
local strings = require("strings")
local ship_ai = require("ship_ai")

return {
  ["keys, arguments and fallbacks"] = function()
    assert(strings.t("ship.sealed") == "SECTORS SEALED.")
    assert(strings.t("ship.breach", 75) == "SUIT BREACH. INTEGRITY 75 PERCENT.")
    assert(strings.t("no.such.key") == "no.such.key")
    strings.language = "xx" -- no such table: English
    assert(strings.t("ship.sealed") == "SECTORS SEALED.")
    strings.language = "en"
    assert(ship_ai.line("nothing", {}, function() end) == nil)
    assert(ship_ai.line("autopilot", { id = 1 }, function() return nil end) == "AUTOPILOT ENGAGED: TARGET.")
    assert(ship_ai.line("hazard_stop", { hazard = "gas_pocket" }, function() end):find("GAS POCKET", 1, true))
  end,
}
