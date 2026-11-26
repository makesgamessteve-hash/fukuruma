-- The deterministic simulation: ticks, commands, events, entities and the state hash.
-- The engine calls sim.step(game) once per 1/60 s tick (see the simulation spec).
local sim = {}

local MAX_DEPTH = 8

sim.dt = 1 / 60 -- seconds of game time per tick

local handlers, listeners, attached
local queue, events
local next_id, alive, components

function sim.reset()
  sim.tick = 0
  handlers, listeners, attached = {}, {}, {}
  queue, events = {}, {}
  next_id, alive, components = 1, {}, {}
end

-- Validates plain data (finite numbers, strings, booleans, tables of those) and returns a deep copy.
local function copy(value, path, depth)
  local kind = type(value)
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error(path .. " is not a finite number", 0)
    end
    return value
  elseif kind == "string" or kind == "boolean" then
    return value
  elseif kind == "table" then
    if depth > MAX_DEPTH then error(path .. " is nested more than " .. MAX_DEPTH .. " levels deep", 0) end
    local result = {}
    for k, v in pairs(value) do
      if type(k) ~= "string" and math.type(k) ~= "integer" then
        error(path .. " has a key that is not a string or an integer", 0)
      end
      result[k] = copy(v, path .. "." .. k, depth + 1)
    end
    return result
  end
  error(path .. " is a " .. kind .. " (only numbers, strings, booleans and tables are allowed)", 0)
end

-- Commands ------------------------------------------------------------------------

function sim.on(name, handler)
  handlers[name] = handler
end

-- Queues a command for the start of the next tick. args are validated and copied.
function sim.send(name, args)
  assert(type(name) == "string", "a command needs a name")
  queue[#queue + 1] = { name = name, args = copy(args or {}, "args", 1) }
end

-- Events --------------------------------------------------------------------------

function sim.listen(name, listener)
  local list = listeners[name] or {}
  list[#list + 1] = listener
  listeners[name] = list
end

function sim.emit(name, data)
  events[#events + 1] = { name = name, data = data }
end

-- One tick: apply the queued commands, run the game's tick, then deliver this tick's events.
function sim.step(game)
  local commands = queue
  queue = {}
  for _, command in ipairs(commands) do
    local handler = handlers[command.name]
    if not handler then error("no handler for command '" .. command.name .. "'", 0) end
    handler(command.args)
  end
  if game.tick then game.tick() end
  sim.tick = sim.tick + 1
  local delivered = events
  events = {}
  for _, event in ipairs(delivered) do
    for _, listener in ipairs(listeners[event.name] or {}) do listener(event.data) end
  end
end

-- Entities: IDs are never reused; each component is a sparse set whose order depends only on the operations.

function sim.create()
  local id = next_id
  next_id = id + 1
  alive[id] = true
  return id
end

function sim.alive(id)
  return alive[id] == true
end

local function remove(set, id)
  local index = set.index[id]
  if not index then return end
  local last = set.ids[#set.ids]
  set.ids[index], set.index[last] = last, index
  set.ids[#set.ids] = nil
  set.index[id], set.values[id] = nil, nil
end

function sim.destroy(id)
  alive[id] = nil
  for _, set in pairs(components) do remove(set, id) end
end

-- Sets (or with nil, removes) a component of a living entity.
function sim.set(id, name, value)
  assert(alive[id], "entity " .. tostring(id) .. " does not exist")
  local set = components[name]
  if not set then
    set = { ids = {}, index = {}, values = {} }
    components[name] = set
  end
  if value == nil then return remove(set, id) end
  if not set.index[id] then
    set.ids[#set.ids + 1] = id
    set.index[id] = #set.ids
  end
  set.values[id] = value
end

function sim.get(id, name)
  local set = components[name]
  return set and set.values[id]
end

-- Iterates (id, value) over a snapshot, so entities may be destroyed while iterating.
function sim.each(name)
  local set = components[name]
  local ids = set and table.move(set.ids, 1, #set.ids, 1, {}) or {}
  local i = 0
  return function()
    i = i + 1
    local id = ids[i]
    if id then return id, set.values[id] end
  end
end

-- State kept outside the components (a physics world in C): provider.state() gives plain data, and
-- provider.restore(data) continues from it. Snapshots and the state hash include it under its name.
function sim.attach(name, provider)
  attached[name] = provider
end

local function attached_states() -- nil when nothing is attached, so such states hash as before
  local states
  for name, provider in pairs(attached) do
    states = states or {}
    states[name] = provider.state()
  end
  return states
end

-- Snapshots (saves) ----------------------------------------------------------------

-- Everything needed to continue exactly where the simulation is: the tick, the next entity ID, the living
-- entities, every component with its iteration order, and the commands not yet applied. Plain data.
function sim.snapshot()
  local living = {}
  for id in pairs(alive) do living[#living + 1] = id end
  table.sort(living)
  local sets = {}
  for name, set in pairs(components) do
    sets[name] = { ids = table.move(set.ids, 1, #set.ids, 1, {}), values = copy(set.values, name, -1) }
  end
  -- depths start below 0: the wrapping tables (values by ID, the queue's command records) do not count
  return { tick = sim.tick, next_id = next_id, alive = living, components = sets, queue = copy(queue, "queue", -2),
    attached = attached_states() }
end

-- Continues from a snapshot. Handlers and listeners stay (they are code, not state).
function sim.restore(snap)
  sim.tick, next_id = snap.tick, snap.next_id
  alive, components, queue, events = {}, {}, copy(snap.queue, "queue", -2), {}
  for _, id in ipairs(snap.alive) do alive[id] = true end
  for name, s in pairs(snap.components) do
    local set = { ids = table.move(s.ids, 1, #s.ids, 1, {}), index = {}, values = copy(s.values, name, -1) }
    for i, id in ipairs(set.ids) do set.index[id] = i end
    components[name] = set
  end
  for name, data in pairs(snap.attached or {}) do
    if attached[name] then attached[name].restore(data) end
  end
end

-- State hash ---------------------------------------------------------------------

local function key_order(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta == "number" end
  return a < b
end

-- Canonical encoding: sorted keys, exact number bytes, type tags. Independent of table order and platform.
local function encode(value, out)
  local kind = type(value)
  if kind == "number" then
    out[#out + 1] = math.type(value) == "integer" and "i" .. string.pack("<j", value) or "d" .. string.pack("<d", value)
  elseif kind == "string" then
    out[#out + 1] = "s" .. string.pack("<s4", value)
  elseif kind == "boolean" then
    out[#out + 1] = value and "T" or "F"
  elseif kind == "table" then
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, key_order)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      encode(k, out)
      encode(value[k], out)
    end
    out[#out + 1] = "}"
  else
    error("the simulation state contains a " .. kind, 0)
  end
end

function sim.state()
  local state = { tick = sim.tick, next_id = next_id, components = {}, attached = attached_states() }
  for name, set in pairs(components) do state.components[name] = set.values end
  return state
end

-- A hex string identifying the complete simulation state.
function sim.hash()
  local out = {}
  encode(sim.state(), out)
  return string.format("%016x", fk.hash(table.concat(out)))
end

sim.reset()
return sim
