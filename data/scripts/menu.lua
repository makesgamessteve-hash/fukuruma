-- The in-game Settings menu (graphics, comfort and audio). Changes apply immediately and are saved; the scene keeps running.
local ui = require("fk.ui")
local graphics = require("settings.graphics")
local comfort = require("settings.comfort")
local audio = require("settings.audio")
local tween = require("fk.tween")

ui.sound = function(name) fk.audio.play(name, { bus = "ui", volume = 0.6 }) end

local menu = { open = false }

function menu.toggle()
  menu.open = not menu.open
  if menu.open then
    ui.reset()
    ui.sound("ui_open")
    menu.slide = tween.new(-24, 0, 0.25, "back_out") -- the panel drops in and settles
  end
end

-- An option row over choices (default graphics.CHOICES[key]) with the given labels.
local function option(state, label, key, labels, on_change, choices)
  choices = choices or graphics.CHOICES[key]
  return {
    label = label, values = labels, index = graphics.index_of(choices, state[key]) or 1,
    change = function(i) on_change(choices[i]) end,
  }
end

function menu.draw(state, dt)
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
    option(state, "Terrain detail", "terrain", { "Coarse", "Medium", "Fine", "Finest" }, level_option("terrain")),
    option(state, "Plants", "plants", { "Sparse", "Some", "Full", "Lush" }, level_option("plants")),
    option(state, "Ground detail", "material", { "Layers", "Detail", "Bumps" }, level_option("material")),
    option(state, "Dithering", "dither", { "On", "Off" }, plain("dither")),
    option(state, "Palette mode", "palette", { "Off", "On" }, plain("palette")),
  }
  local function comfort_option(label, key, labels)
    rows[#rows + 1] = option(comfort.current, label, key, labels, function(value)
      comfort.current[key] = value
      comfort.save()
    end, comfort.CHOICES[key])
  end
  comfort_option("Camera shake", "shake", { "100%", "50%", "Off" })
  comfort_option("Light flashes", "flashes", { "100%", "50%", "Off" })
  comfort_option("Rumble", "rumble", { "On", "Off" })
  comfort_option("Head bob", "head_bob", { "100%", "50%", "Off" })
  comfort_option("Field of view", "fov", { "70", "80", "90", "60" })
  comfort_option("Turning vignette", "vignette", { "On", "Off" })
  local levels = { "100%", "75%", "50%", "25%", "Off" }
  for _, row in ipairs({ { "Music volume", "music" }, { "Effects volume", "effects" } }) do
    rows[#rows + 1] = option(audio.current, row[1], row[2], levels, function(value)
      audio.current[row[2]] = value
      audio.save()
    end, audio.CHOICES[row[2]])
  end
  for _, row in ipairs({ { "Save game", "save" }, { "Load game", "load" } }) do -- set by the game
    if menu.actions and menu.actions[row[2]] then
      rows[#rows + 1] = { label = row[1], press = function()
        menu.open = false
        menu.actions[row[2]]()
      end }
    end
  end
  rows[#rows + 1] = { label = "Close", press = function() menu.open = false end }
  if ui.menu("SETTINGS", rows, menu.slide:update(dt or 0)) == "back" then menu.open = false end
end

return menu
