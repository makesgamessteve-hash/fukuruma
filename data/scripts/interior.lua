-- Interiors (vessel-interiors spec): every doll's inside, made for people, where the Commander walks as a human.
-- A layout per doll kind, the same every time: a corridor spine with the bridge at its front (the doll's controls),
-- side rooms along it (quarters, a drone bay, the suit bay where the Exosuit goes on, the clone bay), and behind it a
-- hangar for each kind of doll the hold carries, with that doll docked at full scale and a ramp up into it.
-- Coordinates: the doll's own frame, metres, floor at y = 0, +z towards the bridge. The free space is a list of
-- rectangles the Commander's centre may be in (walls already set back by the body's radius; neighbours overlap where
-- they connect); a door is such a rectangle too, free only while it is open.
local dolls = require("dolls")

local interior = {}

interior.HEIGHT = 3.2 -- metres from floor to ceiling
interior.EYE = 1.65   -- the Commander's eye above the floor
interior.REACH = 1.8  -- metres: what the Commander can use
interior.RADIUS = 0.3 -- the body's radius: walls stand this far beyond the free space

local ROOM = { w = 9, d = 9 } -- side rooms
local layouts = {}

local function rect(t, x0, z0, x1, z1, name, door)
  t[#t + 1] = { x0 = math.min(x0, x1), z0 = math.min(z0, z1), x1 = math.max(x0, x1), z1 = math.max(z0, z1), name = name,
    door = door }
  return t[#t]
end

-- The layout of a doll kind: {free = {rects}, doors = {rects}, fixtures = {{kind, x, z, ...}}, rooms = {{name, x0,
-- z0, x1, z1}}, spawn = {x, z}}. Fixtures: seat (the controls), ramp (into a docked doll of kind), exit (out of a
-- docked doll), suit (the suit bay), clone (the clone bay).
function interior.layout(kind)
  if layouts[kind] then return layouts[kind] end
  local def = dolls.by_id[kind]
  local free, doors, fixtures, rooms = {}, {}, {}, {}
  local sides = {}
  if def.carries.exosuit then sides[#sides + 1] = "suit bay" end
  if kind == "jump_ship" then sides[#sides + 1] = "clone bay" end
  sides[#sides + 1] = "quarters"
  if def.size_m >= 1000 then sides[#sides + 1] = "drone bay" end
  local spine = 6 + 12 * math.ceil(#sides / 2)
  rect(free, -1.2, 0, 1.2, spine) -- the corridor
  local corridor = { name = "corridor", x0 = -1.5, z0 = 0, x1 = 1.5, z1 = spine, open = { x0 = {}, x1 = {}, z1 = { { -1.5, 1.5 } } },
    roofless = false }
  rooms[#rooms + 1] = corridor
  for i, name in ipairs(sides) do -- side rooms, left and right in turn, each through a door
    local side = i % 2 == 1 and 1 or -1
    local zc = 6 + 12 * ((i - 1) // 2)
    local inner, outer = side * 1.9, side * (1.9 + ROOM.w)
    rect(free, inner + side * 0.1, zc - ROOM.d / 2 + 0.3, outer - side * 0.3, zc + ROOM.d / 2 - 0.3, name)
    doors[#doors + 1] = rect({}, side * 1.0, zc - 0.5, side * 2.2, zc + 0.5, name, true)
    rooms[#rooms + 1] = { name = name, x0 = math.min(inner, outer), z0 = zc - ROOM.d / 2, x1 = math.max(inner, outer),
      z1 = zc + ROOM.d / 2, door = { x = side * 1.7, z = zc, side = side },
      open = { [side > 0 and "x0" or "x1"] = { { zc - 0.6, zc + 0.6, door = name } } } }
    local wall = side > 0 and corridor.open.x1 or corridor.open.x0 -- the corridor's own doorway there
    wall[#wall + 1] = { zc - 0.6, zc + 0.6 }
    rooms[#rooms + 1] = { name = "doorway", x0 = math.min(side * 1.5, side * 1.9), z0 = zc - 0.6, x1 = math.max(side * 1.5, side * 1.9),
      z1 = zc + 0.6, open = { x0 = { { zc - 0.6, zc + 0.6 } }, x1 = { { zc - 0.6, zc + 0.6 } } }, low = true }
    if name == "suit bay" then fixtures[#fixtures + 1] = { "suit", (inner + outer) / 2, zc } end
    if name == "clone bay" then fixtures[#fixtures + 1] = { "clone", (inner + outer) / 2, zc } end
  end
  -- the bridge at the front: the doll's cockpit (dolls/cockpit.lua draws it), its back open to the corridor; the seat
  -- where cockpit.EYE sits over the floor, so the cabin seen from the seat and walked into are the same place
  local c = def.cockpit or { width = 6, depth = 6 }
  local front = math.max(c.depth * 0.35, 3.6)
  local seat_z = spine + c.depth - front
  rect(free, -c.width / 2 + 0.3, spine - 0.5, c.width / 2 - 0.3, seat_z + front - 1.9)
  fixtures[#fixtures + 1] = { "seat", 1.2, seat_z - 0.5 } -- beside the seat
  local kinds = {}
  for k in pairs(def.carries) do
    if k ~= "exosuit" then kinds[#kinds + 1] = k end
  end
  table.sort(kinds, function(a, b) return dolls.by_id[a].size_m < dolls.by_id[b].size_m end) -- the nearest smallest
  local z = 0
  for _, k in ipairs(kinds) do -- hangars behind the corridor, each as big as its docked doll
    local s = math.max(30, dolls.by_id[k].size_m * 1.3)
    rect(free, -1.2, z - 3.5, 1.2, z + 0.5) -- the hangar door's passage
    rect(free, -s / 2 + 0.3, z - 3 - s + 0.3, s / 2 - 0.3, z - 3.3, "hangar " .. k)
    rooms[#rooms + 1] = { name = "passage", x0 = -1.5, z0 = z - 3, x1 = 1.5, z1 = z, open = { z0 = { { -1.5, 1.5 } },
      z1 = { { -1.5, 1.5 } } } }
    rooms[#rooms + 1] = { name = "hangar " .. k, x0 = -s / 2, z0 = z - 3 - s, x1 = s / 2, z1 = z - 3, docked = k,
      open = { z1 = { { -1.5, 1.5 } } } }
    if z == 0 then corridor.open.z0 = { { -1.5, 1.5 } } end
    fixtures[#fixtures + 1] = { "ramp", 0, z - 8, kind = k }
    z = z - 3 - s
  end
  fixtures[#fixtures + 1] = { "exit", 0, 1 } -- (only in a docked doll: down its ramp into the parent's hangar)
  local layout = { free = free, doors = doors, fixtures = fixtures, rooms = rooms, spawn = { 0, 2 },
    seat = { 0, seat_z }, length = seat_z + front - z }
  layouts[kind] = layout
  return layout
end

local function inside(r, x, z) return x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 end

-- Is (x, z) free in the layout, with the doors open as open(name) says?
function interior.free(layout, x, z, open)
  for _, r in ipairs(layout.free) do
    if inside(r, x, z) then return true end
  end
  for _, d in ipairs(layout.doors) do
    if open(d.name) and inside(d, x, z) then return true end
  end
  return false
end

-- Moves walker w ({x, z}) by (dx, dz) in the layout, sliding along walls: each axis on its own when the whole step
-- would leave the free space.
function interior.move(layout, w, dx, dz, open)
  if interior.free(layout, w.x + dx, w.z + dz, open) then w.x, w.z = w.x + dx, w.z + dz return end
  if interior.free(layout, w.x + dx, w.z, open) then w.x = w.x + dx end
  if interior.free(layout, w.x, w.z + dz, open) then w.z = w.z + dz end
end

-- The fixture or door within reach of (x, z), the nearest: {kind, ...} or {"door", name = ...}, or nil.
function interior.near(layout, x, z, docked)
  local best, found = interior.REACH * interior.REACH, nil
  local function try(f, fx, fz)
    local d = (fx - x) * (fx - x) + (fz - z) * (fz - z)
    if d <= best then best, found = d, f end
  end
  for _, f in ipairs(layout.fixtures) do
    if f[1] ~= "exit" or docked then try(f, f[2], f[3]) end
  end
  for _, r in ipairs(layout.rooms) do
    if r.door then try({ "door", name = r.name }, r.door.x, r.door.z) end
  end
  return found
end

-- The layout's walls, floors and ceilings as a mesh table (presentation): each wall with its openings (doorways with
-- a lintel; joins between rooms as tall as the smaller room), and a door panel in each shut doorway (closed(name)).
function interior.mesh(layout, closed)
  local mesh = { positions = {}, colors = {}, indices = {} }
  local function quad(a, b, c, d, color)
    local base = #mesh.positions // 3
    for _, p in ipairs({ a, b, c, d }) do
      for k = 1, 3 do mesh.positions[#mesh.positions + 1], mesh.colors[#mesh.colors + 1] = p[k], color[k] end
    end
    for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do mesh.indices[#mesh.indices + 1] = base + i end
  end
  local H, LINTEL = interior.HEIGHT, 2.4
  local floor, wall, ceiling, door = { 0.32, 0.33, 0.36 }, { 0.62, 0.64, 0.68 }, { 0.5, 0.52, 0.56 }, { 0.85, 0.55, 0.2 }
  -- one wall: along u from a to b at fixed v; facing tells which way it faces (into the room)
  local function panel(axis, v, u0, u1, y0, y1, facing, color)
    if u1 - u0 < 1e-6 then return end
    if axis == "x" then -- a wall at x = v, spanning z
      if facing > 0 then quad({ v, y0, u1 }, { v, y0, u0 }, { v, y1, u0 }, { v, y1, u1 }, color)
      else quad({ v, y0, u0 }, { v, y0, u1 }, { v, y1, u1 }, { v, y1, u0 }, color) end
    else -- a wall at z = v, spanning x
      if facing > 0 then quad({ u0, y0, v }, { u1, y0, v }, { u1, y1, v }, { u0, y1, v }, color)
      else quad({ u1, y0, v }, { u0, y0, v }, { u0, y1, v }, { u1, y1, v }, color) end
    end
  end
  for _, r in ipairs(layout.rooms) do
    local h = r.docked and math.max(H, (r.x1 - r.x0) * 0.6) or H -- hangars are as tall as what they hold
    if r.low then h = LINTEL end
    if r.height then h = r.height end
    if not r.wall_only then
      quad({ r.x0, 0, r.z0 }, { r.x1, 0, r.z0 }, { r.x1, 0, r.z1 }, { r.x0, 0, r.z1 }, floor)
      quad({ r.x0, h, r.z1 }, { r.x1, h, r.z1 }, { r.x1, h, r.z0 }, { r.x0, h, r.z0 }, ceiling)
    end
    local sides = { x0 = { "x", r.x0, r.z0, r.z1, 1 }, x1 = { "x", r.x1, r.z0, r.z1, -1 },
      z0 = { "z", r.z0, r.x0, r.x1, -1 }, z1 = { "z", r.z1, r.x0, r.x1, 1 } }
    for name, w in pairs(sides) do
      if r.wall_only and r.wall_only ~= name then goto next end
      local axis, v, u0, u1, facing = w[1], w[2], w[3], w[4], w[5]
      if axis == "z" then facing = -facing end
      if axis == "x" then facing = name == "x0" and 1 or -1 end
      local gaps = r.open and r.open[name] or {}
      table.sort(gaps, function(p, q) return p[1] < q[1] end)
      local at = u0
      for _, g in ipairs(gaps) do
        panel(axis, v, at, g[1], 0, h, facing, wall)
        panel(axis, v, g[1], g[2], math.min(LINTEL, h), h, facing, wall) -- above the opening
        if g.door and closed(g.door) then panel(axis, v, g[1], g[2], 0, LINTEL, facing, door) end
        at = g[2]
      end
      panel(axis, v, at, u1, 0, h, facing, wall)
      ::next::
    end
  end
  return mesh
end

return interior
