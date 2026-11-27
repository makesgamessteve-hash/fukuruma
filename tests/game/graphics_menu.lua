-- graphics-settings spec: the menu switches detail levels live, Custom keeps the rest, palette mode by
-- tapping, game controls pause while the menu is open, and every change is stored. The menu drops in over
-- a quarter of a second; the screenshots wait for it.
local sim = require("fk.sim")
local ui = require("fk.ui")
local graphics = require("settings.graphics")
local game -- require("game") works once main.lua has run, inside run()

local ROWS = 25 -- rows of the settings menu; row 14 is Palette mode

local function stored()
  return graphics.decode(fk.storage.load("graphics"), {})
end

local function wanted_x()
  return sim.get(game.suit, "suit").wx
end

local function press(t, key)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(1)
end

return scenario {
  seed = 1,
  timeout_s = 60,
  run = function(t)
    game = require("game")
    t.expect(stored().level == "low", "software renderers start on Low, and the choice is stored")
    t.expect(fk.gfx.settings().shadow_cascades == 1 and fk.gfx.settings().ao_samples == 0, "Low settings")
    t.screenshot("level_low")

    press(t, "Escape") -- open the menu: the Detail level row has the focus
    t.frames(15)
    t.screenshot("menu_open")
    t.key("D", true); t.frames(2) -- D is "right" in menus; the suit must not walk
    t.expect(wanted_x() == 0 and stored().level == "medium", "D changes the option, not the suit")
    t.key("D", false); t.frames(20)
    t.expect(fk.gfx.settings().taa, "Medium uses temporal anti-aliasing")
    t.screenshot("level_medium")
    press(t, "Right"); t.frames(20)
    t.expect(stored().level == "high" and fk.gfx.settings().shadow_cascades == 3, "High")
    t.screenshot("level_high")
    press(t, "Right"); t.frames(5)
    t.expect(stored().level == "ultra" and fk.gfx.settings().supersample == 2 and fk.gfx.settings().ao_samples == 16, "Ultra")
    t.screenshot("level_ultra")
    press(t, "Right")
    t.expect(stored().level == "low", "the levels wrap around")

    press(t, "Right"); press(t, "Right") -- High
    for _ = 1, 4 do press(t, "Down") end -- Shadows
    press(t, "Left")
    local c = stored()
    t.expect(c.level == "custom" and c.shadows == 2 and c.ao == 10 and c.lights == 16 and c.aa == "taa", "Custom keeps the rest")

    local x, width, first = ui.layout(ROWS)
    local w, h = fk.gfx.size()
    local px, py = x + width * 0.9, first + 13 * ui.ROW + 4 -- the right half of row 14's value
    t.touch(1, px / w, py / h); t.frames(1)
    t.touch(1); t.frames(2)
    t.expect(stored().palette == true and ui.focus() == 14, "tapping the value's right half turns the palette on")
    t.screenshot("menu_palette")

    press(t, "Escape") -- close: the controls work again
    t.key("D", true); t.frames(2)
    t.expect(wanted_x() == -game.WALK, "the suit walks again after closing the menu")
    t.key("D", false)
  end,
}
