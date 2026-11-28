-- Saves (save spec): the world seed and the simulation's snapshot, versioned, written as Lua-table text in
-- fk.storage slots (files on desktop, IndexedDB in the browser). The text is read by a parser that only accepts
-- what the writer produces (tables, strings, numbers, booleans): a save file can never run code.
local sim = require("fk.sim")

local save = { VERSION = 2 } -- 2: the format of release 1.0 (tests/lua/save_compat_test.lua keeps it loadable)

-- save.MIGRATIONS[n](data) turns version n data into version n + 1 (filled in as the format changes).
save.MIGRATIONS = {
  [1] = function() error("save: made by a development version from before release 1.0, which this game cannot load", 0) end,
}

local HEADER = "-- fukuruma save\n"
local MAX_DEPTH = 24

-- Writer -------------------------------------------------------------------------

local function number_text(n)
  if math.type(n) == "integer" then return string.format("%d", n) end
  local s = string.format("%.17g", n)
  if not s:find("[%.eEn]") then s = s .. ".0" end -- keep floats floats (2.0, not 2)
  return s
end

local function key_order(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta == "number" end
  return a < b
end

local function write(value, out, indent)
  local kind = type(value)
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then error("save: a number is not finite", 0) end
    out[#out + 1] = number_text(value)
  elseif kind == "string" then
    out[#out + 1] = string.format("%q", value)
  elseif kind == "boolean" then
    out[#out + 1] = tostring(value)
  elseif kind == "table" then
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, key_order)
    if #keys == 0 then
      out[#out + 1] = "{}"
      return
    end
    out[#out + 1] = "{\n"
    for _, k in ipairs(keys) do
      out[#out + 1] = indent .. "  "
      if type(k) == "string" and k:match("^[%a_][%w_]*$") then out[#out + 1] = k
      else
        out[#out + 1] = "["
        write(k, out, indent)
        out[#out + 1] = "]"
      end
      out[#out + 1] = " = "
      write(value[k], out, indent .. "  ")
      out[#out + 1] = ",\n"
    end
    out[#out + 1] = indent .. "}"
  else
    error("save: cannot store a " .. kind, 0)
  end
end

function save.encode(value)
  local out = { HEADER, "return " }
  write(value, out, "")
  out[#out + 1] = "\n"
  return table.concat(out)
end

-- Parser -------------------------------------------------------------------------

local function fail(text, pos, what)
  local line = select(2, text:sub(1, pos):gsub("\n", "")) + 1
  error("save: line " .. line .. ": " .. what, 0)
end

local function skip(text, pos)
  while true do
    local s, e = text:find("^%s+", pos)
    if s then pos = e + 1 end
    s, e = text:find("^%-%-[^\n]*", pos)
    if not s then return pos end
    pos = e + 1
  end
end

local ESCAPES = { n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v", ["\\"] = "\\", ['"'] = '"',
  ["'"] = "'", ["\n"] = "\n" }

local function parse_string(text, pos)
  local out, i = {}, pos + 1
  while true do
    local c = text:sub(i, i)
    if c == "" or c == "\n" then fail(text, i, "unfinished string") end
    if c == '"' then return table.concat(out), i + 1 end
    if c == "\\" then
      local e = text:sub(i + 1, i + 1)
      local digits = text:match("^%d%d?%d?", i + 1)
      if digits then
        local code = tonumber(digits)
        if code > 255 then fail(text, i, "bad escape") end
        out[#out + 1], i = string.char(code), i + 1 + #digits
      elseif ESCAPES[e] then
        out[#out + 1], i = ESCAPES[e], i + 2
      else
        fail(text, i, "bad escape")
      end
    else
      out[#out + 1], i = c, i + 1
    end
  end
end

local parse_value

local function parse_table(text, pos, depth)
  if depth > MAX_DEPTH then fail(text, pos, "nested too deeply") end
  local result, i = {}, skip(text, pos + 1)
  while text:sub(i, i) ~= "}" do
    local key
    if text:sub(i, i) == "[" then
      key, i = parse_value(text, skip(text, i + 1), depth + 1)
      if type(key) ~= "string" and math.type(key) ~= "integer" then fail(text, i, "keys must be strings or integers") end
      i = skip(text, i)
      if text:sub(i, i) ~= "]" then fail(text, i, "']' expected") end
      i = i + 1
    else
      key = text:match("^[%a_][%w_]*", i)
      if not key then fail(text, i, "a key expected") end
      i = i + #key
    end
    i = skip(text, i)
    if text:sub(i, i) ~= "=" then fail(text, i, "'=' expected") end
    if result[key] ~= nil then fail(text, i, "a key appears twice") end
    result[key], i = parse_value(text, skip(text, i + 1), depth + 1)
    i = skip(text, i)
    local sep = text:sub(i, i)
    if sep == "," then i = skip(text, i + 1)
    elseif sep ~= "}" then fail(text, i, "',' or '}' expected") end
  end
  return result, i + 1
end

function parse_value(text, pos, depth)
  local c = text:sub(pos, pos)
  if c == "{" then return parse_table(text, pos, depth) end
  if c == '"' then return parse_string(text, pos) end
  local word = text:match("^[%w%.%+%-]+", pos)
  if word == "true" then return true, pos + 4 end
  if word == "false" then return false, pos + 5 end
  local n = word and word:match("^%-?[%d%.]") and tonumber(word)
  if not n or n ~= n or n == math.huge or n == -math.huge then fail(text, pos, "a value expected") end
  return n, pos + #word
end

function save.decode(text)
  text = text:gsub("\r\n", "\n") -- saved or copied on Windows (strings never hold a raw \r: %q escapes it)
  if text:sub(1, #HEADER) ~= HEADER then error("save: not a Fukuruma save", 0) end
  local pos = skip(text, #HEADER + 1)
  if text:sub(pos, pos + 6) ~= "return " then fail(text, pos, "'return' expected") end
  local value, after = parse_value(text, skip(text, pos + 7), 0)
  if skip(text, after) <= #text then fail(text, after, "text after the end") end
  return value
end

-- Snapshots and slots --------------------------------------------------------------

-- The whole game: the world seed, the simulation, and game data that must survive (extra, plain data).
function save.snapshot(extra)
  return { version = save.VERSION, seed = fk.seed(), sim = sim.snapshot(), game = extra or {} }
end

-- Continues from a snapshot (migrating older versions); returns its game data.
function save.restore(data)
  if type(data) ~= "table" or math.type(data.version) ~= "integer" then error("save: no version", 0) end
  if data.version > save.VERSION then error("save: made by a newer version of the game", 0) end
  for v = data.version, save.VERSION - 1 do data = save.MIGRATIONS[v](data) end
  fk.seed(data.seed)
  sim.restore(data.sim)
  return data.game
end

local function slot_name(slot)
  assert(type(slot) == "string" and slot:match("^[a-z0-9_]+$"), "save: slot names use a-z, 0-9 and _")
  return "save_" .. slot
end

function save.write(slot, extra)
  fk.storage.save(slot_name(slot), save.encode(save.snapshot(extra)))
end

-- Loads a slot: returns its game data, or nil when the slot is empty.
function save.read(slot)
  local text = fk.storage.load(slot_name(slot))
  if not text then return nil end
  return save.restore(save.decode(text))
end

return save
