-- Key bindings (accessibility spec): any of the game's main actions can be moved to another key in the settings menu;
-- the choices are saved with fk.storage as "action=Key" lines and applied when the game starts.
local actions = require("fk.actions")

local controls = {}

controls.NAMES = { "use", "scan", "sprint", "dig", "stun", "flare", "seal", "workshop", "outpost", "codex" }

local function valid(key) return type(key) == "string" and pcall(fk.input.key, key) end

-- The stored bindings {action = key}.
function controls.load()
  local out, text = {}, fk.storage.load("controls") or ""
  for name, key in text:gmatch("([%w_]+)=([^\n]+)") do
    for _, n in ipairs(controls.NAMES) do
      if n == name and valid(key) then out[name] = key end
    end
  end
  return out
end

function controls.save(t)
  local lines = {}
  for _, name in ipairs(controls.NAMES) do
    if t[name] then lines[#lines + 1] = name .. "=" .. t[name] end
  end
  fk.storage.save("controls", table.concat(lines, "\n") .. "\n")
end

-- Applies stored bindings to the defined actions.
function controls.apply(t)
  for name, key in pairs(t or controls.load()) do
    if actions.def(name) then actions.bind(name, { keys = { key } }) end
  end
end

-- Binds action name to key now and saves it; false for a key the game does not know.
function controls.rebind(name, key)
  if not valid(key) or not actions.def(name) then return false end
  local t = controls.load()
  t[name] = key
  controls.save(t)
  actions.bind(name, { keys = { key } })
  return true
end

-- The key an action is on (its first).
function controls.key(name)
  local def = actions.def(name)
  return def and def.keys and def.keys[1] or "?"
end

return controls
