-- Draws the touch controls from fk.actions.touch_controls() as unlit overlay circles on the finished image.
-- shortcut: plain overlay meshes; replaced by UI widgets with the in-game UI (add-graphics-settings).
local mat4 = require("mat4")

local view = {}

local function circle(color, segments)
  local mesh = { positions = { 0, 0, 0 }, colors = { color[1], color[2], color[3] }, indices = {} }
  for i = 0, segments - 1 do
    local a = i / segments * 2 * math.pi
    local n = #mesh.positions
    mesh.positions[n + 1], mesh.positions[n + 2], mesh.positions[n + 3] = math.cos(a), math.sin(a), 0
    mesh.colors[n + 1], mesh.colors[n + 2], mesh.colors[n + 3] = color[1], color[2], color[3]
    local v = i + 2
    mesh.indices[#mesh.indices + 1], mesh.indices[#mesh.indices + 2], mesh.indices[#mesh.indices + 3] =
      1, v, (i + 1) % segments + 2
  end
  return fk.gfx.mesh(mesh)
end

function view.init()
  view.base = circle({ 0.18, 0.2, 0.26 }, 32)
  view.knob = circle({ 0.55, 0.6, 0.7 }, 24)
  view.button = circle({ 0.55, 0.32, 0.1 }, 32)
  view.button_held = circle({ 0.95, 0.6, 0.25 }, 32)
end

-- Maps image coordinates (0..1, y down) to clip space.
local function place(x, y, rx, ry)
  local screen = { 2, 0, 0, 0, 0, -2, 0, 0, 0, 0, 0, 0, -1, 1, 0, 1 }
  return mat4.multiply(screen, { rx, 0, 0, 0, 0, ry, 0, 0, 0, 0, 1, 0, x, y, 0, 1 })
end

-- Labels drawn on the buttons (the action's name in capitals when it has none here).
view.LABELS = { sprint = "RUN", scan = "SCAN", menu = "MENU", view = "VIEW" }

function view.draw(controls)
  if not controls then return end
  local w, h = fk.gfx.size()
  local a = w / h
  local s = controls.stick
  fk.gfx.overlay(view.base, place(s.x, s.y, s.r / a, s.r))
  fk.gfx.overlay(view.knob, place(s.knob_x, s.knob_y, 0.4 * s.r / a, 0.4 * s.r))
  for _, b in ipairs(controls.buttons) do
    fk.gfx.overlay(b.held and view.button_held or view.button, place(b.x, b.y, b.r / a, b.r))
    local label = view.LABELS[b.name] or b.name:upper()
    fk.gfx.text(math.floor(b.x * w - #label * 4 + 0.5), math.floor(b.y * h - 4 + 0.5), label, { 1, 0.95, 0.85 })
  end
end

return view
