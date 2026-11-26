-- Settings stored with fk.storage as sorted "key=value" lines; only allowed values are read back.
local store = {}

function store.encode(state, choices)
  local keys, lines = {}, {}
  for key in pairs(choices) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do lines[#lines + 1] = key .. "=" .. tostring(state[key]) end
  return table.concat(lines, "\n") .. "\n"
end

-- Reads stored lines over a copy of base; unknown keys and values that are not allowed are ignored.
function store.decode(text, base, choices)
  local state = {}
  for key, value in pairs(base) do state[key] = value end
  for key, raw in text:gmatch("([%w_]+)=([^\n]*)") do
    for _, choice in ipairs(choices[key] or {}) do
      if tostring(choice) == raw then state[key] = choice end
    end
  end
  return state
end

-- The stored settings under name, or defaults (stored right away, so they stay the same next time).
function store.load(name, defaults, choices)
  local text = fk.storage.load(name)
  if text then return store.decode(text, defaults, choices) end
  fk.storage.save(name, store.encode(defaults, choices))
  return defaults
end

return store
