-- Interiors (vessel-interiors spec): every doll's inside, made for people, where the Commander walks as a human.
-- A layout per doll kind, the same every time: a corridor spine with the bridge at its front (the doll's controls),
-- side rooms along it (quarters, a drone bay, the cargo deck, the suit bay where the Exosuit goes on, the clone bay),
-- and behind it a
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

local ROOM = { w = 9, d = 9 } -- side rooms (a biotope takes three slots and is wider)
local layouts = {}

local function rect(t, x0, z0, x1, z1, name, door)
  t[#t + 1] = { x0 = math.min(x0, x1), z0 = math.min(z0, z1), x1 = math.max(x0, x1), z1 = math.max(z0, z1), name = name,
    door = door }
  return t[#t]
end

-- The rooms a doll kind has, in order along its corridor: {name, type, slots, width}. Everything a crew needs (a
-- galley, quarters, a bath, a med bay, the engine room to keep it running, a cargo deck) in every doll but the Exosuit;
-- more quarters the bigger it is; a workshop, a lab, life support and a drone bay from a kilometre up; a biotope where
-- food grows from six kilometres up.
function interior.plan(kind)
  local def = dolls.by_id[kind]
  local out = {}
  local function room(t, name, slots, width) out[#out + 1] = { name = name or t, type = t, slots = slots or 1, width = width or ROOM.w } end
  if def.carries.exosuit then room("suit bay") end
  if kind == "jump_ship" then room("clone bay") end
  if kind ~= "exosuit" then
    room("galley")
    local n = 1 + math.floor(math.log(def.size_m / 72, 10) * 1.5)
    for q = 1, math.max(1, n) do room("quarters", n > 1 and ("quarters " .. q) or "quarters") end
    room("bath") room("med bay") room("engine room")
    if def.size_m >= 1000 then room("workshop") room("lab") room("life support") room("drone bay") end
  end
  room("cargo deck") -- (what boarding parties are after: thieves.lua)
  if def.size_m >= 6000 then room("biotope", nil, 3, 30) end
  return out
end

-- The layout of a doll kind: {free = {rects}, doors = {rects}, fixtures = {{kind, x, z, ...}}, rooms = {{name, x0,
-- z0, x1, z1, type}}, spawn = {x, z}}. Fixtures: seat (the controls), ramp (into a docked doll of kind), exit (out of a
-- docked doll), tram (a stop of the tram along the hangars: from the corridor to each hangar's ramp in turn and back),
-- and each room's own (interior/rooms.lua: suit, clone, eat, sleep, wash, heal, maintain, workbench, lab, harvest).
function interior.layout(kind)
  if layouts[kind] then return layouts[kind] end
  local def = dolls.by_id[kind]
  local free, doors, fixtures, rooms = {}, {}, {}, {}
  local catalog = require("interior.rooms").types
  local plan = interior.plan(kind)
  local cursor = { [1] = 0, [-1] = 0 } -- how far along the corridor each side is filled
  local placed = {}
  for _, r in ipairs(plan) do -- each room on the side filled less far, right first
    local side = cursor[1] <= cursor[-1] and 1 or -1
    local depth = r.slots * 12 - 3
    placed[#placed + 1] = { r = r, side = side, zc = cursor[side] + 1.5 + depth / 2, depth = depth }
    cursor[side] = cursor[side] + depth + 3
  end
  local spine = math.max(cursor[1], cursor[-1]) + 6
  rect(free, -1.2, 0, 1.2, spine) -- the corridor
  local corridor = { name = "corridor", x0 = -1.5, z0 = 0, x1 = 1.5, z1 = spine, open = { x0 = {}, x1 = {}, z1 = { { -1.5, 1.5 } } },
    roofless = false }
  rooms[#rooms + 1] = corridor
  for _, pl in ipairs(placed) do -- side rooms through their doors
    local r, side, zc, depth = pl.r, pl.side, pl.zc, pl.depth
    local name = r.name
    local inner, outer = side * 1.9, side * (1.9 + r.width)
    rect(free, inner + side * 0.1, zc - depth / 2 + 0.3, outer - side * 0.3, zc + depth / 2 - 0.3, name)
    doors[#doors + 1] = rect({}, side * 1.0, zc - 0.5, side * 2.2, zc + 0.5, name, true)
    rooms[#rooms + 1] = { name = name, type = r.type, x0 = math.min(inner, outer), z0 = zc - depth / 2, x1 = math.max(inner, outer),
      z1 = zc + depth / 2, door = { x = side * 1.7, z = zc, side = side }, side = side,
      height = catalog[r.type] and catalog[r.type].height,
      open = { [side > 0 and "x0" or "x1"] = { { zc - 0.6, zc + 0.6, door = name } } } }
    local wall = side > 0 and corridor.open.x1 or corridor.open.x0 -- the corridor's own doorway there
    wall[#wall + 1] = { zc - 0.6, zc + 0.6 }
    rooms[#rooms + 1] = { name = "doorway", x0 = math.min(side * 1.5, side * 1.9), z0 = zc - 0.6, x1 = math.max(side * 1.5, side * 1.9),
      z1 = zc + 0.6, open = { x0 = { { zc - 0.6, zc + 0.6 } }, x1 = { { zc - 0.6, zc + 0.6 } } }, low = true }
    local t = catalog[r.type]
    if t and t.fixture then -- where the room's use is: by its far wall, across from the door
      fixtures[#fixtures + 1] = { t.fixture, side * (1.9 + r.width / 2), zc, room = name }
    end
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
    local near = z - 3 - s / 2 + dolls.by_id[k].size_m / 2 + 4 -- at the near end of the docked doll (drawn at the centre)
    fixtures[#fixtures + 1] = { "ramp", 0, near, kind = k }
    fixtures[#fixtures + 1] = { "tram", -4, near, stop = dolls.by_id[k].name .. " hangar" } -- (out of the ramp's reach)
    z = z - 3 - s
  end
  if #kinds > 0 then table.insert(fixtures, #fixtures - #kinds * 2 + 1, { "tram", 0, 0.4, stop = "corridor" }) end
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

-- The tram stop after stop f (fixtures in order, wrapping round).
function interior.next_stop(layout, f)
  local stops, at = {}, 1
  for _, s in ipairs(layout.fixtures) do
    if s[1] == "tram" then
      stops[#stops + 1] = s
      if s == f then at = #stops end
    end
  end
  return stops[at % #stops + 1]
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

-- The walls, floor and ceiling of room r into mesh (presentation): each wall with its openings (doorways with a lintel;
-- joins between rooms as tall as the smaller room), and a door panel in each shut doorway (closed(name)).
local function walls(mesh, r, closed)
  local function quad(a, b, c, d, color)
    local base = #mesh.positions // 3
    for _, p in ipairs({ a, b, c, d }) do
      for k = 1, 3 do mesh.positions[#mesh.positions + 1], mesh.colors[#mesh.colors + 1] = p[k], color[k] end
    end
    for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do mesh.indices[#mesh.indices + 1] = base + i end
  end
  local H, LINTEL = interior.HEIGHT, 2.4
  local floor, wall, ceiling, door = { 0.32, 0.33, 0.36 }, { 0.62, 0.64, 0.68 }, { 0.5, 0.52, 0.56 }, { 0.85, 0.55, 0.2 }
  if r.type == "biotope" then floor, wall, ceiling = { 0.36, 0.3, 0.22 }, { 0.55, 0.62, 0.58 }, { 0.8, 0.85, 0.9 } end
  if r.type == "bath" then floor, wall = { 0.75, 0.78, 0.8 }, { 0.82, 0.86, 0.88 } end
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
  local h = r.docked and math.max(H, (r.x1 - r.x0) * 0.6) or H -- hangars are as tall as what they hold
  if r.low then h = LINTEL end
  if r.height then h = r.height end
  if not r.wall_only then
    quad({ r.x0, 0, r.z0 }, { r.x1, 0, r.z0 }, { r.x1, 0, r.z1 }, { r.x0, 0, r.z1 }, floor)
    quad({ r.x0, h, r.z1 }, { r.x1, h, r.z1 }, { r.x1, h, r.z0 }, { r.x0, h, r.z0 }, ceiling)
  end
  for _, name in ipairs({ "x0", "x1", "z0", "z1" }) do -- (in a fixed order: the same mesh every time)
    local w = ({ x0 = { "x", r.x0, r.z0, r.z1 }, x1 = { "x", r.x1, r.z0, r.z1 }, z0 = { "z", r.z0, r.x0, r.x1, 1 },
      z1 = { "z", r.z1, r.x0, r.x1, -1 } })[name]
    if not (r.wall_only and r.wall_only ~= name) then
      local axis, v, u0, u1 = w[1], w[2], w[3], w[4]
      local facing = axis == "x" and (name == "x0" and 1 or -1) or w[5]
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
    end
  end
end

-- The whole layout as one mesh table (walls, floors, ceilings and doors, no furniture).
function interior.mesh(layout, closed)
  local mesh = { positions = {}, colors = {}, indices = {} }
  for _, r in ipairs(layout.rooms) do walls(mesh, r, closed) end
  return mesh
end

-- Room i of the layout as two mesh tables: its walls with its furniture, and its lights (glowing parts), built in the
-- doll's frame (presentation). The furniture (interior/rooms.lua) is placed in the room's own frame: +x away from the
-- corridor (mirrored for rooms on the left), z along it.
function interior.room_mesh(layout, i, closed)
  local r = layout.rooms[i]
  local mesh, glow = { positions = {}, colors = {}, indices = {} }, { positions = {}, colors = {}, indices = {} }
  walls(mesh, r, closed)
  local t = r.type and require("interior.rooms").types[r.type]
  if not t then return mesh, glow end
  local hull = require("dolls.hull")
  local w, d = r.x1 - r.x0, r.z1 - r.z0
  local cx, cz, side = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2, r.side or 1
  local parts = t.parts(w, d)
  for _, pair in ipairs({ { mesh, nil }, { glow, "glow" } }) do
    local out, m = pair[1], hull.build(parts, 1, pair[2])
    local base = #out.positions // 3
    for v = 0, #m.positions // 3 - 1 do
      local n = #out.positions
      out.positions[n + 1], out.positions[n + 2], out.positions[n + 3] = cx + side * m.positions[v * 3 + 1], m.positions[v * 3 + 2],
        cz + m.positions[v * 3 + 3]
      out.colors[n + 1], out.colors[n + 2], out.colors[n + 3] = m.colors[v * 3 + 1], m.colors[v * 3 + 2], m.colors[v * 3 + 3]
    end
    for t3 = 0, #m.indices // 3 - 1 do -- (mirrored rooms turn their triangles round)
      local a, b, c = m.indices[t3 * 3 + 1], m.indices[t3 * 3 + 2], m.indices[t3 * 3 + 3]
      if side < 0 then b, c = c, b end
      out.indices[#out.indices + 1], out.indices[#out.indices + 2], out.indices[#out.indices + 3] = base + a, base + b, base + c
    end
  end
  return mesh, glow
end

-- How far (x, z) is from room r (0 inside it).
function interior.distance(r, x, z)
  local dx = math.max(r.x0 - x, 0, x - r.x1)
  local dz = math.max(r.z0 - z, 0, z - r.z1)
  return math.sqrt(dx * dx + dz * dz)
end

interior.LOAD = 40      -- metres: rooms nearer than this are built and drawn
interior.UNLOAD = 70    -- metres: rooms farther than this are let go (their meshes freed)
interior.PER_FRAME = 2  -- rooms built at most each frame, so walking never stutters

-- Streams the rooms of a layout around (x, z) (presentation): cache = {[i] = {mesh, glow, key}} for this doll;
-- make(mesh_table) turns a mesh table into something to draw (fk.gfx.mesh). Builds the near rooms (a few a frame; a
-- door's state is part of a room's key, so a door opening rebuilds its room), lets the far ones go, and returns the
-- rooms to draw now {entry, ...}. Hangars are always kept: they are big and plain, and seen from afar.
function interior.stream(cache, layout, x, z, closed, make)
  local built, out = 0, {}
  for i, r in ipairs(layout.rooms) do
    local dist = interior.distance(r, x, z)
    local key = r.name .. (r.door and closed(r.name) and "|shut" or "")
    for _, g in ipairs(r.open and r.open.x0 or {}) do if g.door and closed(g.door) then key = key .. "|" .. g.door end end
    for _, g in ipairs(r.open and r.open.x1 or {}) do if g.door and closed(g.door) then key = key .. "|" .. g.door end end
    local e = cache[i]
    if dist <= interior.LOAD or r.docked or r.name == "corridor" then
      if (not e or e.key ~= key) and built < interior.PER_FRAME then
        local m, g = interior.room_mesh(layout, i, closed)
        e = { mesh = make(m), glow = #g.indices > 0 and make(g) or nil, key = key }
        cache[i] = e
        built = built + 1
      end
      if e then out[#out + 1] = e end
    elseif e and dist > interior.UNLOAD then
      cache[i] = nil -- (garbage collection frees its mesh)
    end
  end
  return out
end

return interior
