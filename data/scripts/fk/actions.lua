-- Named game actions from keyboard, mouse, gamepad and touch input (input spec).
-- The game defines actions once and calls update() once per frame, in its input() function.
local actions = {}

actions.DEAD_ZONE = 0.2
actions.STICK_RANGE = 0.12 -- touch-stick travel, in screen heights

local defs, held, was_held, values, stick, buttons, look, look_dx, look_dy

function actions.reset()
  defs, held, was_held, values, stick, buttons, look, look_dx, look_dy = {}, {}, {}, {}, nil, {}, nil, 0, 0
end

-- An axis: { kind = "axis", negative = { keys }, positive = { keys }, gamepad = "leftx", touch = "stick_x" | "stick_y" }
-- A button: { kind = "button", keys = { keys }, gamepad = { buttons }, touch = "touch button name" }
function actions.define(name, def)
  assert(def.kind == "axis" or def.kind == "button", "an action's kind must be 'axis' or 'button'")
  defs[name] = def
end

-- Replaces fields of an action's bindings, e.g. bind("turn", { negative = { "J" }, positive = { "L" } }).
function actions.bind(name, changes)
  local def = assert(defs[name], "unknown action '" .. tostring(name) .. "'")
  for k, v in pairs(changes) do def[k] = v end
end

-- A circular touch button centred at (x, y) (0..1 of the screen) with a radius in screen heights.
function actions.touch_button(name, x, y, radius)
  buttons[name] = { x = x, y = y, r = radius }
end

-- The touch buttons in use now (a list of names; nil: all): the others are neither drawn nor pressed. Each doll has
-- its own layout (touch-controls spec).
local layout
function actions.touch_layout(names)
  layout = nil
  if names then
    layout = {}
    for _, n in ipairs(names) do layout[n] = true end
  end
end

local function aspect()
  local w, h = fk.gfx.size()
  return w / h
end

local function any_key(keys)
  for _, key in ipairs(keys or {}) do
    if fk.input.key(key) then return true end
  end
  return false
end

local function in_button(touch, b)
  local dx, dy = (touch.x - b.x) * aspect(), touch.y - b.y
  return dx * dx + dy * dy <= b.r * b.r
end

local function touch_held(name)
  local b = buttons[name]
  if not b or (layout and not layout[name]) then return false end
  for _, touch in ipairs(fk.input.touches()) do
    if in_button(touch, b) then return true end
  end
  return false
end

-- The stick follows the finger that first landed on the left half of the screen.
local function update_stick(touches)
  if stick then
    for _, touch in ipairs(touches) do
      if touch.id == stick.id then
        stick.x, stick.y = touch.x, touch.y
        return
      end
    end
    stick = nil
  end
  for _, touch in ipairs(touches) do
    if touch.x < 0.5 then
      stick = { id = touch.id, ox = touch.x, oy = touch.y, x = touch.x, y = touch.y }
      return
    end
  end
end

local function on_button(touch)
  for _, b in pairs(buttons) do
    if in_button(touch, b) then return true end
  end
  return false
end

-- The look finger: the first one that lands on the right half of the screen and not on a button. Its movement
-- since the last frame turns the view.
local function update_look(touches)
  look_dx, look_dy = 0, 0
  if look then
    for _, touch in ipairs(touches) do
      if touch.id == look.id then
        look_dx, look_dy = touch.x - look.x, touch.y - look.y
        look.x, look.y = touch.x, touch.y
        return
      end
    end
    look = nil
  end
  for _, touch in ipairs(touches) do
    if touch.x >= 0.5 and not on_button(touch) then
      look = { id = touch.id, x = touch.x, y = touch.y }
      return
    end
  end
end

-- How far the look finger moved this frame, as fractions of the screen's width and height.
function actions.touch_look()
  return look_dx, look_dy
end

local function clamp(v)
  return math.max(-1, math.min(1, v))
end

local function stick_axis(which)
  if not stick then return 0 end
  if which == "stick_x" then return clamp((stick.x - stick.ox) * aspect() / actions.STICK_RANGE) end
  return clamp((stick.y - stick.oy) / actions.STICK_RANGE)
end

local function gamepad_axis(name)
  if not name then return 0 end
  local v = fk.input.axis(name)
  if math.abs(v) <= actions.DEAD_ZONE then return 0 end
  local sign = v > 0 and 1 or -1
  return (v - sign * actions.DEAD_ZONE) / (1 - actions.DEAD_ZONE)
end

function actions.update()
  update_stick(fk.input.touches())
  update_look(fk.input.touches())
  was_held, held = held, {}
  for name, def in pairs(defs) do
    if def.kind == "axis" then
      local best = 0
      local keys = (any_key(def.positive) and 1 or 0) - (any_key(def.negative) and 1 or 0)
      for _, v in ipairs({ keys, gamepad_axis(def.gamepad), def.touch and stick_axis(def.touch) or 0 }) do
        if math.abs(v) > math.abs(best) then best = v end
      end
      values[name] = best
    else
      local down = any_key(def.keys) or (def.touch ~= nil and touch_held(def.touch))
      for _, button in ipairs(def.gamepad or {}) do down = down or fk.input.button(button) end
      held[name] = down
    end
  end
end

function actions.value(name)
  return values[name] or 0
end

function actions.held(name)
  return held[name] == true
end

function actions.pressed(name)
  return held[name] == true and not was_held[name]
end

-- What to draw for the touch controls, or nil when the latest input did not come from touch.
function actions.touch_controls()
  if fk.input.device() ~= "touch" then return nil end
  local range, a = actions.STICK_RANGE, aspect()
  local ox, oy = 0.15, 0.75 -- where the stick rests until a thumb lands
  if stick then ox, oy = stick.ox, stick.oy end
  local controls = {
    stick = { x = ox, y = oy, r = range,
      knob_x = ox + stick_axis("stick_x") * range / a, knob_y = oy + stick_axis("stick_y") * range },
    buttons = {},
  }
  for name, b in pairs(buttons) do
    if not layout or layout[name] then
      controls.buttons[#controls.buttons + 1] = { name = name, x = b.x, y = b.y, r = b.r, held = touch_held(name) }
    end
  end
  table.sort(controls.buttons, function(p, q) return p.name < q.name end)
  return controls
end

actions.reset()
return actions
