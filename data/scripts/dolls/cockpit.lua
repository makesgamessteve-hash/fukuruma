-- Cockpits and bridges (cockpits spec): the cabin around a doll's seat, sized for the 3.6 m Exosuit the Commander sits
-- in, from the Walker's cab to the Jump Ship's bridge. A doll's definition gives cockpit = {width, height, depth
-- (metres), posts (window posts), screens (on the console), color, trim}. Built from hull parts (dolls/hull.lua) in
-- metres around the eye: x right, y up, z forward to the windows. The screens glow (a second mesh) and show what the
-- doll knows, drawn where they appear on screen.
local hull = require("dolls.hull")

local cockpit = {}

cockpit.EYE = 2.7 -- metres above the floor: the seated Exosuit's eye
cockpit.LOOK = math.rad(110) -- how far the head turns left or right of the doll's front in the seat

-- The cabin's parts (metres, eye at the origin), its screens, where they are, and its lights (buttons, strips).
function cockpit.parts(c)
  local w, h, d, y0 = c.width, c.height, c.depth, -cockpit.EYE
  local col, trim, glove = c.color or { 0.32, 0.33, 0.36 }, c.trim or { 0.18, 0.18, 0.2 }, { 0.85, 0.85, 0.82 }
  local front, sill, head = math.max(d * 0.35, 3.6), 2.2, 0.6
  local parts = {
    { "box", at = { 0, y0 - 0.05, front - d / 2 }, size = { w, 0.1, d }, color = trim }, -- floor
    { "box", at = { 0, y0 + h, front - d / 2 }, size = { w, 0.1, d }, color = col }, -- ceiling
    -- the back wall, its doorway into the doll's corridor (interior.lua) 3 m wide and 2.4 m high
    { "box", at = { (w / 2 + 1.5) / 2, y0 + h / 2, front - d }, size = { w / 2 - 1.5, h, 0.1 }, color = col, mirror = true },
    { "box", at = { 0, y0 + (h + 2.4) / 2, front - d }, size = { 3, h - 2.4, 0.1 }, color = col },
    { "box", at = { w / 2, y0 + h / 2, front - d / 2 }, size = { 0.1, h, d }, color = col, mirror = true }, -- sides
    { "box", at = { 0, y0 + sill / 2, front }, size = { w, sill, 0.15 }, color = col }, -- below the windows
    { "box", at = { 0, y0 + h - head / 2, front }, size = { w, head, 0.15 }, color = col }, -- above them
    -- the console: a sloped desk with a lip, on a pedestal
    { "taper", at = { 0, y0 + 1.6, front - 1.0 }, size = { math.min(w * 0.7, 6), 0.25, 1.2 }, top = { math.min(w * 0.7, 6) - 0.1, 0.9 },
      shift = { 0, -0.15 }, color = trim },
    { "box", at = { 0, y0 + 0.75, front - 0.9 }, size = { math.min(w * 0.6, 5), 1.5, 0.6 }, color = col },
    { "box", at = { 0, y0 + 1.75, front - 1.62 }, size = { math.min(w * 0.7, 6), 0.06, 0.08 }, color = { 0.5, 0.5, 0.52 } },
    -- the seat: a pedestal, a cushion, a back with a headrest, and armrests
    { "lathe", at = { 0, y0, -0.5 }, axis = "y", stations = { { 0, 0.45 }, { 0.15, 0.4 }, { 0.75, 0.2 } }, sides = 10, cap = true, color = trim },
    { "taper", at = { 0, y0 + 0.9, -0.5 }, size = { 1.6, 0.25, 1.5 }, top = { 1.5, 1.4 }, color = { 0.22, 0.24, 0.28 } },
    { "taper", at = { 0, y0 + 2.1, -1.25 }, size = { 1.6, 2.0, 0.25 }, top = { 1.3, 0.25 }, color = { 0.22, 0.24, 0.28 } },
    { "box", at = { 0, y0 + 3.25, -1.3 }, size = { 0.8, 0.5, 0.3 }, color = { 0.22, 0.24, 0.28 } }, -- (the headrest)
    { "box", at = { 0.9, y0 + 1.25, -0.5 }, size = { 0.2, 0.15, 1.3 }, color = trim, mirror = true },
    { "box", at = { 0.9, y0 + 1.05, -1.0 }, size = { 0.1, 0.3, 0.1 }, color = trim, mirror = true },
    { "box", at = { 0.9, y0 + 1.45, 1.1 }, size = { 0.1, 0.5, 0.1 }, color = trim, mirror = true }, -- the sticks
    { "box", at = { 0.9, y0 + 1.75, 1.1 }, size = { 0.22, 0.16, 0.28 }, color = glove, mirror = true }, -- the hands
    -- side consoles along the walls, the overhead panel, floor grating and wall ribs
    { "taper", at = { w / 2 - 0.45, y0 + 0.55, front - d * 0.45 }, size = { 0.8, 1.1, d * 0.5 }, top = { 0.5, d * 0.5 }, shift = { 0.15, 0 },
      color = trim, mirror = true },
    { "box", at = { 0, y0 + h - 0.12, -0.2 }, size = { 2.2, 0.16, 1.6 }, color = trim },
  }
  for i = 0, 3 do -- ribs up the walls and over the ceiling
    local z = front - 0.6 - (d - 1) * i / 3
    parts[#parts + 1] = { "box", at = { w / 2 - 0.12, y0 + h / 2, z }, size = { 0.16, h, 0.2 }, color = trim, mirror = true }
    parts[#parts + 1] = { "box", at = { 0, y0 + h - 0.08, z }, size = { w, 0.12, 0.2 }, color = trim }
  end
  for i = -2, 2 do -- floor grating
    parts[#parts + 1] = { "box", at = { i * 0.5, y0 + 0.01, front - d / 2 }, size = { 0.05, 0.02, d - 0.4 }, color = { 0.12, 0.12, 0.14 } }
  end
  local lights = {} -- glowing buttons and small screens (drawn with the screens)
  local green, amber, red, cyan = { 0.2, 0.9, 0.4 }, { 1, 0.65, 0.2 }, { 1, 0.25, 0.2 }, { 0.3, 0.8, 1 }
  for i = 0, 5 do -- button rows on the side consoles
    local col = ({ green, amber, cyan, green, red, cyan })[i + 1]
    lights[#lights + 1] = { "box", at = { w / 2 - 0.5, y0 + 1.12, front - d * 0.2 - i * d * 0.08 }, size = { 0.3, 0.03, 0.1 }, color = col, mirror = true }
  end
  for i = -3, 3 do -- switches on the overhead panel and on the desk's lip
    lights[#lights + 1] = { "box", at = { i * 0.28, y0 + h - 0.21, -0.2 }, size = { 0.12, 0.02, 0.2 }, color = i % 2 == 0 and amber or green }
    lights[#lights + 1] = { "box", at = { i * 0.5, y0 + 1.74, front - 0.45 }, size = { 0.2, 0.03, 0.12 }, color = i % 3 == 0 and red or cyan }
  end
  lights[#lights + 1] = { "box", at = { w / 2 - 0.4, y0 + 1.6, front - d * 0.55 }, size = { 0.04, 0.5, 0.7 }, color = { 0.05, 0.25, 0.3 }, mirror = true }
  lights[#lights + 1] = { "box", at = { w / 2 - 0.12, y0 + h - 0.3, -0.5 }, size = { 0.08, 0.08, d * 0.6 }, color = { 0.9, 0.85, 0.7 }, mirror = true } -- (strip lights)
  for i = 1, c.posts do -- window posts, evenly across the front
    parts[#parts + 1] = { "box", at = { -w / 2 + w * i / (c.posts + 1), y0 + (sill + h - head) / 2, front },
      size = { 0.25, h - sill - head, 0.25 }, color = trim }
  end
  local screens, spots, span = {}, {}, math.min(w * 0.7, 6)
  for i = 1, c.screens do -- glowing panels standing on the console's far edge
    local x = span / 2 - span * (i - 0.5) / c.screens -- (+x is on the left, looking forward: the first screen leftmost)
    local at = { x, y0 + 2.2, front - 1.45 }
    local half = span / c.screens * 0.85 / 2
    screens[#screens + 1] = { "box", at = at, size = { half * 2, 0.8, 0.06 }, color = { 0.05, 0.16, 0.2 } }
    spots[#spots + 1] = { at[1], at[2], at[3] + 0.04, half }
  end
  return parts, screens, spots, lights
end

-- Meshes for a doll kind's cockpit, built once ({shell, screens, spots}), or nil for a doll without one.
function cockpit.build(state, def)
  if not def.cockpit then return nil end
  if not state[def.id] then
    local parts, screens, spots, lights = cockpit.parts(def.cockpit)
    for _, l in ipairs(lights) do screens[#screens + 1] = l end -- (the buttons glow with the screens)
    state[def.id] = { shell = fk.gfx.mesh(hull.build(parts, 1)), screens = fk.gfx.mesh(hull.build(screens, 1)), spots = spots }
  end
  return state[def.id]
end

-- Draws the cabin around the eye, turned with the doll (yaw; presentation); indoor: out of the starlight (walked
-- into from the doll's rooms). Returns the built cockpit, or nil.
function cockpit.draw(state, def, eye, yaw, indoor)
  local c = cockpit.build(state, def)
  if not c then return nil end
  local cy, sy = math.cos(yaw or 0), math.sin(yaw or 0)
  local m = { cy, 0, -sy, 0, 0, 1, 0, 0, sy, 0, cy, 0, eye[1], eye[2], eye[3], 1 }
  fk.gfx.draw(c.shell, m, { roughness = 0.6, metalness = 0.3, slice = "local", indoor = indoor })
  fk.gfx.draw(c.screens, m, { roughness = 0.3, emission = { 0.6, 0.6, 0.6 }, emissive_colors = true, slice = "local" })
  return c
end

-- Where a point lands on the screen (pixels), or nil behind the eye. view, projection: column-major 4x4.
function cockpit.project(p, view, projection, w, h)
  local v = {}
  for r = 1, 4 do v[r] = view[r] * p[1] + view[4 + r] * p[2] + view[8 + r] * p[3] + view[12 + r] end
  local c = {}
  for r = 1, 4 do c[r] = projection[r] * v[1] + projection[4 + r] * v[2] + projection[8 + r] * v[3] + projection[12 + r] * v[4] end
  if c[4] <= 0.01 then return nil end
  return (c[1] / c[4] * 0.5 + 0.5) * w, (0.5 - c[2] / c[4] * 0.5) * h
end

-- The screens' lines: what the doll knows (lines: a list of strings per screen, as many as the cockpit has screens).
-- Drawn as text centred on each screen where it appears, cut to the screen's width there (8 pixels a letter), so far
-- or small screens show less (presentation). Returns how many screens were seen.
function cockpit.text(c, eye, lines, view, projection, w, h, color, yaw)
  local seen, cy, sy = 0, math.cos(yaw or 0), math.sin(yaw or 0)
  local function at(x, y, z) return { eye[1] + x * cy + z * sy, eye[2] + y, eye[3] - x * sy + z * cy } end
  for i, spot in ipairs(c and c.spots or {}) do
    local p = at(spot[1], spot[2], spot[3])
    local x, y = cockpit.project(p, view, projection, w, h)
    local left = cockpit.project(at(spot[1] - spot[4], spot[2], spot[3]), view, projection, w, h)
    local right = cockpit.project(at(spot[1] + spot[4], spot[2], spot[3]), view, projection, w, h)
    local text = lines[i]
    if x and left and right and text and x > 0 and x < w and y > 0 and y < h then
      local fits = math.floor(math.abs(right - left) / 8)
      if fits >= 3 then
        seen = seen + 1
        for k, line in ipairs(text) do
          line = line:sub(1, fits)
          fk.gfx.text(math.floor(x - #line * 4), math.floor(y - #text * 5 + (k - 1) * 10), line, color)
        end
      end
    end
  end
  return seen
end

return cockpit
