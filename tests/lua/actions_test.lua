-- fk.actions (input spec). Raw input is read through fk.input, which these tests replace with a fake.
local actions = require("fk.actions")

local real = fk.input
local fake = { keys = {}, axes = {}, buttons = {}, touches = {}, device = "keyboard" }
local function install()
  fake.keys, fake.axes, fake.buttons, fake.touches, fake.device = {}, {}, {}, {}, "keyboard"
  fk.input = {
    key = function(k) return fake.keys[k] == true end,
    axis = function(a) return fake.axes[a] or 0 end,
    button = function(b) return fake.buttons[b] == true end,
    touches = function() return fake.touches end,
    device = function() return fake.device end,
  }
  actions.reset()
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

local W, H = fk.gfx.size() -- 480 x 270 without a window

local tests = {
  ["keys make an axis"] = function()
    actions.define("turn", { kind = "axis", negative = { "A" }, positive = { "D" } })
    actions.update()
    assert(actions.value("turn") == 0)
    fake.keys.D = true; actions.update()
    assert(actions.value("turn") == 1)
    fake.keys.A = true; actions.update()
    assert(actions.value("turn") == 0, "both directions cancel")
    fake.keys.D = nil; actions.update()
    assert(actions.value("turn") == -1)
  end,
  ["gamepad axes have a dead zone"] = function()
    actions.define("turn", { kind = "axis", gamepad = "leftx" })
    fake.axes.leftx = 0.1; actions.update()
    assert(actions.value("turn") == 0)
    fake.axes.leftx = 0.6; actions.update()
    assert(near(actions.value("turn"), 0.5))
    fake.axes.leftx = -1; actions.update()
    assert(near(actions.value("turn"), -1))
  end,
  ["the largest input wins"] = function()
    actions.define("turn", { kind = "axis", positive = { "D" }, gamepad = "leftx" })
    fake.keys.D, fake.axes.leftx = true, -0.6
    actions.update()
    assert(actions.value("turn") == 1)
  end,
  ["buttons report a press only in the first frame"] = function()
    actions.define("boost", { kind = "button", keys = { "Space" }, gamepad = { "a" } })
    fake.keys.Space = true
    actions.update(); assert(actions.pressed("boost") and actions.held("boost"))
    actions.update(); assert(not actions.pressed("boost") and actions.held("boost"))
    actions.update(); assert(not actions.pressed("boost") and actions.held("boost"))
    fake.keys.Space = nil; fake.buttons.a = true
    actions.update(); assert(actions.held("boost"))
    fake.buttons.a = nil
    actions.update(); assert(not actions.held("boost") and not actions.pressed("boost"))
    assert(actions.value("unknown") == 0 and not actions.held("unknown"))
  end,
  ["remapping takes effect in the next update"] = function()
    actions.define("turn", { kind = "axis", negative = { "A" }, positive = { "D" } })
    actions.bind("turn", { negative = { "J" }, positive = { "L" } })
    fake.keys.D = true; actions.update()
    assert(actions.value("turn") == 0)
    fake.keys.L = true; actions.update()
    assert(actions.value("turn") == 1)
    assert(not pcall(actions.bind, "nope", {}))
    assert(not pcall(actions.define, "bad", { kind = "wheel" }))
  end,
  ["the touch stick is anchored where the thumb lands"] = function()
    actions.define("turn", { kind = "axis", touch = "stick_x" })
    actions.define("lift", { kind = "axis", touch = "stick_y" })
    fake.device = "touch"
    fake.touches = { { id = 7, x = 0.9, y = 0.5 }, { id = 3, x = 0.2, y = 0.7 } } -- right half is ignored
    actions.update()
    assert(actions.value("turn") == 0)
    fake.touches[2] = { id = 3, x = 0.2 + actions.STICK_RANGE * H / W, y = 0.7 + actions.STICK_RANGE * 2 }
    actions.update()
    assert(near(actions.value("turn"), 1) and actions.value("lift") == 1, "displacement is clamped")
    local c = actions.touch_controls()
    assert(near(c.stick.x, 0.2) and near(c.stick.knob_x, 0.2 + actions.STICK_RANGE * H / W))
    fake.touches = {}
    actions.update()
    assert(actions.value("turn") == 0)
    assert(near(actions.touch_controls().stick.x, 0.15), "the stick rests at its default place")
  end,
  ["touch buttons"] = function()
    actions.define("boost", { kind = "button", touch = "boost" })
    actions.define("orphan", { kind = "button", touch = "missing" })
    actions.touch_button("boost", 0.85, 0.7, 0.1)
    fake.device = "touch"
    fake.touches = { { id = 1, x = 0.86, y = 0.71 } }
    actions.update()
    assert(actions.held("boost") and not actions.held("orphan"))
    local c = actions.touch_controls()
    assert(#c.buttons == 1 and c.buttons[1].name == "boost" and c.buttons[1].held)
    fake.touches = { { id = 1, x = 0.5, y = 0.1 } }
    actions.update()
    assert(not actions.held("boost"))
  end,
  ["touch controls only in touch mode"] = function()
    assert(actions.touch_controls() == nil)
  end,
}

-- Every test gets a fresh fake and fresh actions; the real fk.input is restored afterwards.
local wrapped = {}
for name, fn in pairs(tests) do
  wrapped[name] = function()
    install()
    local ok, err = pcall(fn)
    fk.input = real
    actions.reset()
    if not ok then error(err, 0) end
  end
end
return wrapped
