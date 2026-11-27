-- Immediate-mode menus drawn with fk.gfx.rect and fk.gfx.text, usable with keyboard, gamepad, mouse and touch.
-- Call ui.reset() when a menu opens and ui.menu(...) once per frame while it is open.
local ui = {}

ui.ROW = 11 -- row height in internal pixels (8x8 font plus spacing); 23 rows fit the 270-pixel image
ui.WIDTH = 300

-- Menus read the devices directly, so they work whatever the game's own bindings are.
local CONTROLS = {
  up = function() return fk.input.key("Up") or fk.input.key("W") or fk.input.button("dpup") or fk.input.axis("lefty") < -0.5 end,
  down = function() return fk.input.key("Down") or fk.input.key("S") or fk.input.button("dpdown") or fk.input.axis("lefty") > 0.5 end,
  left = function() return fk.input.key("Left") or fk.input.key("A") or fk.input.button("dpleft") or fk.input.axis("leftx") < -0.5 end,
  right = function() return fk.input.key("Right") or fk.input.key("D") or fk.input.button("dpright") or fk.input.axis("leftx") > 0.5 end,
  confirm = function() return fk.input.key("Return") or fk.input.key("Space") or fk.input.button("a") end,
  back = function() return fk.input.key("Escape") or fk.input.button("b") end,
  click = function() return fk.input.mouse_button(1) end,
}
local DIRECTIONS = { "up", "down", "left", "right" }

local held, pressed, focus, repeat_frames, touches_seen = {}, {}, 1, 0, {}

-- Inputs that are already held when a menu opens do not count as presses.
function ui.reset()
  for name, read in pairs(CONTROLS) do held[name] = read() end
  pressed, focus, repeat_frames, touches_seen = {}, 1, 0, {}
  for _, touch in ipairs(fk.input.touches()) do touches_seen[touch.id] = true end
end

local function poll()
  for name, read in pairs(CONTROLS) do
    local now = read()
    pressed[name] = now and not held[name]
    held[name] = now
  end
  local any = held.up or held.down or held.left or held.right
  repeat_frames = any and repeat_frames + 1 or 0
  if repeat_frames > 20 and (repeat_frames - 20) % 6 == 0 then -- held directions repeat
    for _, d in ipairs(DIRECTIONS) do pressed[d] = pressed[d] or held[d] end
  end
end

-- Steps an option row by -1 or +1 (wrapping), or presses a button row.
local function activate(row, step)
  ui.sound("ui_confirm")
  if row.values then
    row.change((row.index - 1 + step) % #row.values + 1)
  elseif row.press then
    row.press()
  end
end

-- Polls the controls for screens that are not menus (the maps): the presses of this frame by name (up, down, left,
-- right, confirm, back, click). Call once per frame.
function ui.input()
  poll()
  return pressed
end

function ui.focus()
  return focus
end

-- Called with "ui_move" when the focus moves and "ui_confirm" when a row is used; menus set it to play sounds.
function ui.sound(_) end

-- Where a menu with n rows is drawn: left x, width, the y of the first row (internal-image pixels).
function ui.layout(n)
  local w, h = fk.gfx.size()
  local width = math.min(ui.WIDTH, w - 16)
  local top = math.max(8, (h - (n + 2) * ui.ROW) // 2)
  return (w - width) // 2, width, top + 2 * ui.ROW, top
end

-- rows: { label = "...", values = { "A", "B" }, index = 1, change = function(i) end } (options)
--    or { label = "...", press = function() end } (buttons).
-- dy (optional): moves the drawn panel down by this many pixels (opening animations).
-- Returns "back" when the player asks to leave the menu.
function ui.menu(title, rows, dy)
  poll()
  local w, h = fk.gfx.size()
  local x, width, first_row_y, top = ui.layout(#rows)
  local shift = math.floor((dy or 0) + 0.5)
  focus = math.min(focus, #rows)
  local was = focus

  local function row_at(px, py)
    local r = math.floor((py - first_row_y + 2) / ui.ROW) + 1
    if px >= x - 4 and px < x + width + 4 and r >= 1 and r <= #rows then return r end
  end

  -- Pointer: the mouse focuses what it hovers and clicks; a new touch taps.
  local mx, my = fk.input.mouse()
  local point
  if fk.input.device() == "mouse" then
    focus = row_at(mx * w, my * h) or focus
    if pressed.click then point = { mx * w, my * h } end
  end
  local current = {}
  for _, touch in ipairs(fk.input.touches()) do
    current[touch.id] = true
    if not touches_seen[touch.id] then point = { touch.x * w, touch.y * h } end
  end
  touches_seen = current

  if pressed.up then focus = (focus - 2) % #rows + 1 end
  if pressed.down then focus = focus % #rows + 1 end
  local row = rows[focus]
  if pressed.left and row.values then activate(row, -1) end
  if pressed.right and row.values then activate(row, 1) end
  if pressed.confirm then activate(row, 1) end
  if point then
    local r = row_at(point[1], point[2])
    if r then
      focus = r
      local value_left = x + width * 0.55 -- tapping the left half of a value steps back
      activate(rows[r], (rows[r].values and point[1] >= value_left and point[1] < value_left + width * 0.225) and -1 or 1)
    end
  end

  if focus ~= was then ui.sound("ui_move") end
  fk.gfx.rect(x - 8, top - 6 + shift, width + 16, (#rows + 2) * ui.ROW + 10, { 0.02, 0.03, 0.07, 0.85 })
  fk.gfx.text(x, top + shift, title, { 1, 0.75, 0.4 })
  for i, r in ipairs(rows) do
    local y = first_row_y + (i - 1) * ui.ROW + shift
    local color = i == focus and { 1, 1, 1 } or { 0.7, 0.74, 0.82 }
    if i == focus then fk.gfx.rect(x - 4, y - 2, width + 8, ui.ROW, { 1, 0.6, 0.2, 0.3 }) end
    fk.gfx.text(x, y, r.label, color)
    if r.values then
      local value = "< " .. r.values[r.index] .. " >"
      fk.gfx.text(x + width - #value * 8, y, value, color)
    end
  end
  if pressed.back then return "back" end
end

return ui
