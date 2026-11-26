-- fk.ui (ui spec): menu navigation with keyboard, gamepad, mouse and touch. Raw input is faked.
local ui = require("fk.ui")

local real = fk.input
local fake
local function install()
  fake = { keys = {}, buttons = {}, axes = {}, mouse = { 0, 0 }, click = false, touches = {}, device = "keyboard" }
  fk.input = {
    key = function(k) return fake.keys[k] == true end,
    button = function(b) return fake.buttons[b] == true end,
    axis = function(a) return fake.axes[a] or 0 end,
    mouse = function() return fake.mouse[1], fake.mouse[2], 0, 0 end,
    mouse_button = function() return fake.click end,
    touches = function() return fake.touches end,
    device = function() return fake.device end,
  }
end

local function rows(log)
  return {
    { label = "A", values = { "one", "two", "three" }, index = log.index or 1, change = function(i) log.index = i end },
    { label = "B", press = function() log.pressed = (log.pressed or 0) + 1 end },
    { label = "C", values = { "x", "y" }, index = 1, change = function(i) log.c = i end },
  }
end

local function frame(log, title)
  return ui.menu(title or "TEST", rows(log))
end

local function tap(log, key)
  fake.keys[key] = true; local r = frame(log)
  fake.keys[key] = nil; frame(log)
  return r
end

local tests = {
  ["focus moves and wraps"] = function()
    local log = {}
    ui.reset()
    tap(log, "Down"); assert(ui.focus() == 2)
    tap(log, "Down"); tap(log, "Down"); assert(ui.focus() == 1, "wraps to the first row")
    tap(log, "Up"); assert(ui.focus() == 3, "wraps to the last row")
    tap(log, "W"); assert(ui.focus() == 2)
  end,
  ["left and right change options"] = function()
    local log = {}
    ui.reset()
    tap(log, "Right"); assert(log.index == 2)
    tap(log, "Left"); assert(log.index == 1)
    tap(log, "A"); assert(log.index == 3, "wraps backwards")
    fake.buttons.dpright = true; frame(log); fake.buttons.dpright = nil; frame(log)
    assert(log.index == 1)
  end,
  ["confirm presses buttons and back leaves"] = function()
    local log = {}
    ui.reset()
    tap(log, "Down")
    tap(log, "Return")
    assert(log.pressed == 1)
    fake.buttons.a = true; frame(log); fake.buttons.a = nil; frame(log)
    assert(log.pressed == 2)
    assert(tap(log, "Escape") == "back")
  end,
  ["held keys repeat; keys held on opening do not count"] = function()
    local log = {}
    fake.keys.Down = true
    ui.reset()
    frame(log)
    assert(ui.focus() == 1, "Down was already held when the menu opened")
    for _ = 1, 26 do frame(log) end
    assert(ui.focus() == 2, "repeat after 20 frames")
    fake.keys.Down = nil; frame(log)
    fake.axes.lefty = 0.9; frame(log); fake.axes.lefty = 0; frame(log)
    assert(ui.focus() == 3, "the stick navigates too")
  end,
  ["mouse hovers and clicks"] = function()
    local log = {}
    ui.reset()
    fake.device = "mouse"
    local x, width, first = ui.layout(3)
    local w, h = fk.gfx.size()
    fake.mouse = { (x + 10) / w, (first + ui.ROW + 4) / h } -- over row 2
    frame(log)
    assert(ui.focus() == 2)
    fake.click = true; frame(log); fake.click = false; frame(log)
    assert(log.pressed == 1)
    fake.mouse = { (x + width * 0.6) / w, (first + 4) / h } -- left half of row 1's value
    fake.click = true; frame(log); fake.click = false; frame(log)
    assert(log.index == 3, "the left half steps back")
  end,
  ["touch taps"] = function()
    local log = {}
    ui.reset()
    local x, width, first = ui.layout(3)
    local w, h = fk.gfx.size()
    fake.touches = { { id = 1, x = (x + width * 0.95) / w, y = (first + 24 + 4) / h } } -- right of row 3's value
    frame(log)
    assert(log.c == 2 and ui.focus() == 3)
    frame(log) -- the same touch held: no second tap
    assert(log.c == 2)
    fake.touches = { { id = 2, x = 0.01, y = 0.01 } } -- outside the menu
    frame(log)
    fake.touches = {}
    frame(log)
    assert(ui.focus() == 3)
  end,
}

local wrapped = {}
for name, fn in pairs(tests) do
  wrapped[name] = function()
    install()
    local ok, err = pcall(fn)
    fk.input = real
    if not ok then error(err, 0) end
  end
end
return wrapped
