-- The visor HUD and the survey drone's overlay, drawn in internal-image pixels after the scene.
local hud = {}

local AMBER, DIM = { 1, 0.78, 0.4 }, { 0.75, 0.6, 0.35 }

-- A dark frame along the image's edges: the helmet's rim, or the vignette while turning.
local function frame(w, h, strength, steps)
  for i = 0, steps - 1 do
    local a, inset = strength * (1 - i / steps), i * 4
    local c = { 0, 0, 0, a }
    fk.gfx.rect(inset, inset, w - 2 * inset, 4, c)
    fk.gfx.rect(inset, h - inset - 4, w - 2 * inset, 4, c)
    fk.gfx.rect(inset, inset + 4, 4, h - 2 * inset - 8, c)
    fk.gfx.rect(w - inset - 4, inset + 4, 4, h - 2 * inset - 8, c)
  end
end

-- The compass heading in degrees: 0 along +z, growing clockwise (turning right).
function hud.heading(yaw)
  return math.floor((-math.deg(yaw)) % 360 + 0.5) % 360
end

-- state: { yaw, speed (m/s), scan (0..1, 1: ready), turn_rate (rad/s), vignette (bool) }
function hud.visor(state)
  local w, h = fk.gfx.size()
  frame(w, h, 0.35, 5)
  if state.vignette and state.turn_rate > 1.5 then frame(w, h, math.min(0.5, (state.turn_rate - 1.5) * 0.2), 12) end
  -- the compass: a tick every 15 degrees within 60 of the heading, letters at the cardinal points
  local heading, cx = hud.heading(state.yaw), w // 2
  for deg = -60, 60, 15 do
    local mark = (heading + deg) // 15 * 15
    local x = cx + (mark - heading) * 2
    local letter = ({ [0] = "N", [90] = "E", [180] = "S", [270] = "W" })[mark % 360]
    if letter then fk.gfx.text(x - 4, 6, letter, AMBER)
    else fk.gfx.rect(x, 9, 1, 3, DIM) end
  end
  fk.gfx.rect(cx, 15, 1, 4, AMBER)
  local text = string.format("%03d", heading)
  fk.gfx.text(cx - #text * 4, 20, text, AMBER)
  fk.gfx.text(12, h - 18, string.format("%4.1f M/S", state.speed), AMBER)
  local label = state.scan >= 1 and "SCAN READY" or "SCAN"
  fk.gfx.text(w - 12 - #label * 8, h - 18, label, state.scan >= 1 and AMBER or DIM)
  fk.gfx.rect(w - 92, h - 8, math.floor(80 * state.scan), 2, state.scan >= 1 and AMBER or DIM)
end

-- The survey drone's feed: scanlines, a recording dot and a reminder that the view is for looking only.
function hud.drone(time)
  local w, h = fk.gfx.size()
  for y = 0, h - 1, 3 do fk.gfx.rect(0, y, w, 1, { 0, 0, 0, 0.12 }) end
  frame(w, h, 0.25, 4)
  fk.gfx.text(12, 10, "SURVEY DRONE", AMBER)
  if math.floor(time * 2) % 2 == 0 then fk.gfx.rect(w - 20, 10, 8, 8, { 1, 0.15, 0.1 }) end
  local text = "VIEW ONLY - V TO RETURN"
  fk.gfx.text((w - #text * 8) // 2, h - 18, text, AMBER)
end

return hud
