-- The in-game Settings > Graphics menu. Changes apply immediately and are saved; the scene keeps running.
local ui = require("fk.ui")
local graphics = require("settings.graphics")

local menu = { open = false }

function menu.toggle()
  menu.open = not menu.open
  if menu.open then ui.reset() end
end

-- An option row over choices (default graphics.CHOICES[key]) with the given labels.
local function option(state, label, key, labels, on_change, choices)
  choices = choices or graphics.CHOICES[key]
  return {
    label = label, values = labels, index = graphics.index_of(choices, state[key]) or 1,
    change = function(i) on_change(choices[i]) end,
  }
end

function menu.draw(state)
  if not menu.open then return end
  local function changed()
    graphics.apply(state)
    graphics.save(state)
  end
  local function level_option(key) -- rows a detail level controls
    return function(value)
      graphics.set(state, key, value)
      changed()
    end
  end
  local function plain(key)
    return function(value)
      state[key] = value
      changed()
    end
  end
  -- The four levels cycle; "Custom" only shows while the options differ from every level.
  local levels, level_choices = { "Low", "Medium", "High", "Ultra" }, { "low", "medium", "high", "ultra" }
  if state.level == "custom" then levels[5], level_choices[5] = "Custom", "custom" end
  local rows = {
    option(state, "Detail level", "level", levels, function(level)
      if level ~= "custom" then
        graphics.set_level(state, level)
        changed()
      end
    end, level_choices),
    option(state, "Resolution", "resolution", { "Classic 480x270", "Sharp 640x360", "Fine 960x540" }, plain("resolution")),
    option(state, "Fill window", "fill", { "On", "Off" }, plain("fill")),
    option(state, "Anti-aliasing", "aa", { "None", "Temporal", "Supersampled" }, level_option("aa")),
    option(state, "Shadows", "shadows", { "Off", "1 cascade", "2 cascades", "3 cascades", "4 cascades" }, level_option("shadows")),
    option(state, "Shadow detail", "shadow_size", { "1024", "2048" }, level_option("shadow_size")),
    option(state, "Ambient occlusion", "ao", { "Off", "6", "10", "16" }, level_option("ao")),
    option(state, "Point lights", "lights", { "4", "8", "16", "32" }, level_option("lights")),
    option(state, "Dithering", "dither", { "On", "Off" }, plain("dither")),
    option(state, "Palette mode", "palette", { "Off", "On" }, plain("palette")),
    { label = "Close", press = function() menu.open = false end },
  }
  if ui.menu("SETTINGS - GRAPHICS", rows) == "back" then menu.open = false end
end

return menu
