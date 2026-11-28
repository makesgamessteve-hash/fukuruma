-- String tables (accessibility spec): the game's text by key, in the current language (strings/<language>.lua; mods
-- can add languages or replace lines through the overlay). A missing key falls back to English, then to the key.
local strings = { language = "en", tables = {} }

local function table_for(language)
  if strings.tables[language] == nil then
    local ok, t = pcall(require, "strings." .. language)
    strings.tables[language] = ok and type(t) == "table" and t or false
  end
  return strings.tables[language] or nil
end

-- The text for key, with %s/%d filled from the arguments.
function strings.t(key, ...)
  local t = table_for(strings.language)
  local text = t and t[key] or (table_for("en") or {})[key] or key
  if select("#", ...) > 0 then return string.format(text, ...) end
  return text
end

return strings
