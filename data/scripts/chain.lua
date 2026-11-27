-- The Fukuruma chain (doll-chain spec): which dolls are out in the world, where, which ones each holds docked, and
-- which one the Commander is in. Simulation: a saved component, changed only by the deploy, recall and board
-- commands. Places are in the range's local frame (metres, y up from the ground at the range); orbits are parked
-- straight above the range.
-- shortcut: orbiting dolls stand still above the range; give them real orbits with the vehicle controllers (M6).
local sim = require("fk.sim")
local dolls = require("dolls")
local hull = require("dolls.hull")

local chain = {}

chain.REACH = 2.5 -- a doll deploys and boards only what stands within this many of its own sizes (or its parent)

-- The chain at the start of a game: the Jump Ship far above, its station in orbit, the Continental Explorer in the
-- sky to the south, the Land Explorer and the Walker on the ground south of the range, the Commander in the
-- Exosuit on the range (the suit of main.lua). {kind, x, y (ground: above the ground; else above the range), z}
chain.START = {
  -- shortcut: the Jump Ship parks 1,200 km up, where 32-bit positions still hold its bridge to centimetres; park it
  -- in a truly high orbit once dolls are drawn relative to the camera.
  { "jump_ship", 0, 1.2e6, 0 },
  { "space_station", 0, 4.0e5, 0 },
  { "continental_explorer", 0, 3500, -14000 },
  { "land_explorer", 0, 0, -3500 },
  { "walker", 0, 0, -150 },
  { "exosuit", 0, 0, 0 },
}

-- The ground's height at (x, z) in the range's local frame (0 with no ground).
function chain.ground(x, z)
  local g = require("universe").ground()
  if not g then return 0 end
  local R, up, e, n = g.radius, g.up, g.east, g.north
  local d = { up[1] * R + e[1] * x + n[1] * z, up[2] * R + e[2] * x + n[2] * z, up[3] * R + e[3] * x + n[3] * z }
  local l = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
  d[1], d[2], d[3] = d[1] / l, d[2] / l, d[3] / l
  local h = g.surface:height(d[1], d[2], d[3])
  return (R + h) * (d[1] * up[1] + d[2] * up[2] + d[3] * up[3]) - (R + g.surface:height(up[1], up[2], up[3]))
end

local function place(kind, x, y, z)
  if dolls.by_id[kind].place == "ground" then return x, chain.ground(x, z) + y, z end
  return x, y, z
end

local function holds(kind) -- what a newly made doll carries docked
  local h = {}
  for k, n in pairs(dolls.by_id[kind].carries) do h[k] = n end
  return h
end

function chain.state() return sim.get(chain.id, "chain") end

function chain.find(id)
  for _, d in ipairs(chain.state().dolls) do
    if d.id == id then return d end
  end
end

-- The doll the Commander is in.
function chain.current() return chain.find(chain.state().at) end

-- The Commander is on foot (in the Exosuit, steering the suit of the range).
function chain.on_foot() return chain.current().kind == "exosuit" end

local function distance(a, b)
  local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function near(a, b)
  return distance(a, b) <= math.max(dolls.by_id[a.kind].size_m, dolls.by_id[b.kind].size_m) * chain.REACH
end

-- Can the Commander go from doll a to doll b? A Drop Ship docks with any doll near it, either way. Otherwise b is a's
-- parent or child: in orbit both (their hangars), or on and over the ground both and near. Between orbit and the
-- ground only a Drop Ship goes.
local function linked(a, b)
  if a.kind == "drop_ship" or b.kind == "drop_ship" then return near(a, b) end
  if b.parent ~= a.id and a.parent ~= b.id then return false end
  local ao, bo = dolls.by_id[a.kind].place == "orbit", dolls.by_id[b.kind].place == "orbit"
  if ao or bo then return ao and bo end
  return near(a, b)
end

chain.TELEPORT = { jump_ship = true, space_station = true } -- the teleport network's nodes

-- Sets up the component and the commands. suit(): the suit's state {x, y, z}; move_suit(x, y, z): puts the suit
-- (feet) there.
function chain.install(suit, move_suit)
  chain.id = sim.create()
  local list, parent = {}, nil
  for i, s in ipairs(chain.START) do
    local x, y, z = place(s[1], s[2], s[3], s[4])
    local h = holds(s[1])
    local nxt = chain.START[i + 1]
    if nxt then h[nxt[1]] = h[nxt[1]] - 1 end -- the next one down is out
    list[i] = { id = i, kind = s[1], parent = parent, x = x, y = y, z = z, yaw = 0, speed = 0, stride = 0, hold = h }
    parent = i
  end
  sim.set(chain.id, "chain", { dolls = list, at = #list, next = #list + 1 })
  chain.suit, chain.move_suit = suit, move_suit

  sim.on("deploy", function(args) -- a docked doll out of the one the Commander is in, beside it
    local c, s = chain.current(), chain.state()
    local kind = args.kind
    if not (c.hold[kind] and c.hold[kind] > 0) then return end
    local o = dolls.by_id[kind].offset
    local x, y, z = c.x + o[1], (dolls.by_id[kind].place == "orbit" and 0 or c.y) + o[2], c.z + o[3]
    if dolls.by_id[kind].place == "ground" then x, y, z = place(kind, x, o[2], z) end
    c.hold[kind] = c.hold[kind] - 1
    local d = { id = s.next, kind = kind, parent = c.id, x = x, y = y, z = z, yaw = c.yaw or 0, speed = 0, stride = 0,
      hold = holds(kind) }
    s.next = s.next + 1
    s.dolls[#s.dolls + 1] = d
    if kind == "exosuit" then move_suit(x, y, z) end
    sim.emit("deploy", { position = { x, y, z }, kind = kind, id = d.id, strength = 1 })
  end)

  sim.on("recall", function(args) -- a child of the Commander's doll back into its hold (nobody in it, nothing out)
    local c, s = chain.current(), chain.state()
    local d = chain.find(args.id)
    if not d or d.parent ~= c.id then return end
    for _, o in ipairs(s.dolls) do
      if o.parent == d.id then return end
    end
    for i, o in ipairs(s.dolls) do
      if o == d then table.remove(s.dolls, i) break end
    end
    c.hold[d.kind] = (c.hold[d.kind] or 0) + 1
    sim.emit("recall", { position = { d.x, d.y, d.z }, kind = d.kind, id = d.id, strength = 0.8 })
  end)

  sim.on("board", function(args) -- the Commander goes to the controls of a parent or child doll nearby
    local c = chain.current()
    local d = chain.find(args.id)
    if not d or not linked(c, d) then return end
    c.drive = nil -- the doll left behind stops
    chain.state().at = d.id
    sim.emit("board", { position = { d.x, d.y, d.z }, kind = d.kind, id = d.id, strength = 0.6 })
  end)

  sim.on("teleport", function(args) -- between the Jump Ship and the stations, however far apart (teleport network)
    local c, d = chain.current(), chain.find(args.id)
    if not d or d == c or not chain.TELEPORT[c.kind] or not chain.TELEPORT[d.kind] then return end
    chain.state().at = d.id
    sim.emit("teleport", { position = { d.x, d.y, d.z }, kind = d.kind, id = d.id, strength = 1 })
  end)

  sim.on("autopilot", function(args) -- the doll the Commander sits in goes to another doll by itself
    local c, d = chain.current(), chain.find(args.id)
    local ctl = dolls.by_id[c.kind].controller
    if not d or d == c or not ctl or ctl.kind == "fixed" then return end
    c.auto = d.id
    sim.emit("autopilot", { position = { c.x, c.y, c.z }, kind = c.kind, id = d.id, strength = 0.5 })
  end)
  chain.install_drive()
end

-- What the player's buttons aim at (presentation; the commands check again): the parent doll; the nearest child out
-- in the world; the first kind (by name) the current doll holds docked, Drop Ships last.
function chain.up()
  local c = chain.current()
  return c.parent
end

function chain.down()
  local c, best, id = chain.current(), math.huge, nil
  for _, d in ipairs(chain.state().dolls) do
    if d.parent == c.id and distance(c, d) < best then best, id = distance(c, d), d.id end
  end
  return id
end

-- The teleport button's target: from the Jump Ship the first station, from a station the Jump Ship (or nil).
function chain.teleport_target()
  local c = chain.current()
  if not chain.TELEPORT[c.kind] then return nil end
  for _, d in ipairs(chain.state().dolls) do
    if d ~= c and chain.TELEPORT[d.kind] and (c.kind ~= d.kind) then return d.id end
  end
end

-- The autopilot button's target: a Drop Ship high up heads for the nearest Continental Explorer, low down for the
-- nearest doll in orbit; any other doll walks or flies back to its parent.
function chain.autopilot_target()
  local c = chain.current()
  if c.kind ~= "drop_ship" then return c.parent end
  local high = c.y - chain.ground(c.x, c.z) > 50000
  local best, id = math.huge, nil
  for _, d in ipairs(chain.state().dolls) do
    local fits = high and d.kind == "continental_explorer" or not high and dolls.by_id[d.kind].place == "orbit"
    if fits and distance(c, d) < best then best, id = distance(c, d), d.id end
  end
  return id
end

function chain.next_kind()
  local kinds = {}
  for k, n in pairs(chain.current().hold) do
    if n > 0 then kinds[#kinds + 1] = k end
  end
  table.sort(kinds, function(a, b)
    if (a == "drop_ship") ~= (b == "drop_ship") then return b == "drop_ship" end
    return a < b
  end)
  return kinds[1]
end

local function label(kind) return dolls.by_id[kind].name:upper() end

local function metres(m)
  if m >= 10000 then return string.format("%.0f KM", m / 1000) end
  if m >= 1000 then return string.format("%.1f KM", m / 1000) end
  return string.format("%.0f M", m)
end

-- What the screens of the doll the Commander is in show (presentation): one list of lines per screen.
function chain.screens()
  local c, s = chain.current(), chain.state()
  local hold, out = { "IN THE HOLD" }, { "OUT" }
  local kinds = {}
  for k, n in pairs(c.hold) do
    if n > 0 then kinds[#kinds + 1] = k end
  end
  table.sort(kinds)
  for _, k in ipairs(kinds) do hold[#hold + 1] = label(k) .. " " .. c.hold[k] end
  if #hold == 1 then hold[2] = "EMPTY" end
  for _, d in ipairs(s.dolls) do
    if d.parent == c.id or d.id == c.parent then out[#out + 1] = label(d.kind) .. " " .. metres(distance(c, d)) end
  end
  if #out == 1 then out[2] = "NONE" end
  local target = c.auto and chain.find(c.auto)
  local list = { { label(c.kind), "AT THE CONTROLS" }, hold, out,
    { "ALTITUDE", metres(math.max(0, c.y - chain.ground(c.x, c.z))) }, { "B UP  N DOWN", "T DEPLOY  R RECALL" },
    target and { "AUTOPILOT", label(target.kind) .. " " .. metres(distance(c, target)) } or { "AUTOPILOT", "O: OFF" },
    { "TELEPORT", chain.TELEPORT[c.kind] and "P: READY" or "NO NODE" } }
  for i = #list + 1, 8 do list[i] = { "SYSTEMS", "NOMINAL" } end
  return list
end

-- Steering (vehicle controllers): throttle and turn (-1..1) and lift (-1..1, flying dolls) for the doll the
-- Commander sits in. Each doll's controller (its definition's controller field) moves it every tick:
--   legged {speed, accel, turn, stride}: walks on the ground; a stomp event every stride (metres)
--   flight {speed, accel, turn, climb, min_altitude}: flies, no lower than min_altitude above the ground
--   fixed: holds its place (orbits; their own controllers come with the teleport network and autopilot)
function chain.install_drive()
  sim.on("drive", function(args)
    local c = chain.current()
    if c.kind == "exosuit" then return end
    local function clamp(v) return math.max(-1, math.min(1, tonumber(v) or 0)) end
    c.drive = { throttle = clamp(args.throttle), turn = clamp(args.turn), lift = clamp(args.lift) }
    if c.drive.throttle ~= 0 or c.drive.turn ~= 0 or c.drive.lift ~= 0 then c.auto = nil end -- the hands take over
  end)
end

-- Autopilot: the drive that takes doll d towards doll t (turning by the side the target lies on; no angles, so only
-- arithmetic), or nil once it is there (within half its reach), which ends the autopilot.
local function autopilot(d, t, ctl)
  local dx, dy, dz = t.x - d.x, t.y - d.y, t.z - d.z
  local flat = math.sqrt(dx * dx + dz * dz)
  if math.sqrt(flat * flat + dy * dy) <= math.max(dolls.by_id[d.kind].size_m, dolls.by_id[t.kind].size_m) * chain.REACH * 0.5 then
    return nil
  end
  local fx, fz = fk.math.sin(d.yaw), fk.math.cos(d.yaw)
  local ahead = flat > 1e-6 and (fx * dx + fz * dz) / flat or 1
  local left = flat > 1e-6 and (fz * dx - fx * dz) / flat or 0 -- the side a larger yaw turns to
  local turn = ahead < 0 and (left >= 0 and 1 or -1) or math.max(-1, math.min(1, left * 4))
  local lift = ctl.kind == "flight" and math.max(-1, math.min(1, dy / math.max(500, flat * 0.2))) or 0
  return { throttle = ahead < 0.3 and 0.3 or 1, turn = turn, lift = lift }
end

-- How fast a doll may go: flying dolls faster the higher they are (thin air; a Drop Ship from orbit), up to 8 km/s.
local function top_speed(d, ctl)
  if ctl.kind ~= "flight" then return ctl.speed end
  return math.min(8000, ctl.speed * (1 + math.max(0, d.y - chain.ground(d.x, d.z)) / 5000))
end

local function steer(d, dt)
  local ctl = dolls.by_id[d.kind].controller
  if not ctl or ctl.kind == "fixed" then return end
  d.yaw, d.speed, d.stride = d.yaw or 0, d.speed or 0, d.stride or 0 -- (games saved before the controllers)
  local drive = d.drive or { throttle = 0, turn = 0, lift = 0 }
  if d.auto then
    local t = chain.find(d.auto)
    drive = t and autopilot(d, t, ctl) or { throttle = 0, turn = 0, lift = 0 }
    if not t or drive.throttle == 0 then
      d.auto = nil
      if t then sim.emit("arrived", { position = { d.x, d.y, d.z }, kind = d.kind, id = t.id, strength = 0.5 }) end
    end
  end
  local top = top_speed(d, ctl)
  local want, step = drive.throttle * top, ctl.accel * dt * top / ctl.speed
  d.speed = d.speed + math.max(-step, math.min(step, want - d.speed))
  d.yaw = d.yaw + drive.turn * ctl.turn * dt * math.min(1, 0.3 + math.abs(d.speed) / ctl.speed)
  local dx, dz = fk.math.sin(d.yaw) * d.speed * dt, fk.math.cos(d.yaw) * d.speed * dt
  d.x, d.z = d.x + dx, d.z + dz
  local ground = chain.ground(d.x, d.z)
  if ctl.kind == "legged" then
    d.y = ground
    d.stride = d.stride + math.sqrt(dx * dx + dz * dz)
    if d.stride >= ctl.stride then -- a foot comes down: the ground shakes, the cabin jolts
      d.stride = d.stride - ctl.stride
      sim.emit("stomp", { position = { d.x, d.y, d.z }, kind = d.kind,
        strength = math.min(1, dolls.by_id[d.kind].size_m / 600 + 0.35) })
    end
  else
    d.y = math.max(ground + ctl.min_altitude, d.y + drive.lift * ctl.climb * dt * top / ctl.speed) -- (faster up high too)
  end
end

-- Each tick: the doll the Commander steers moves; the Exosuit's place follows the suit; on another world (world_key), the dolls on the ground stand on its
-- ground.
-- shortcut: the whole chain goes along with a jump; stations staying behind in their systems come with the teleport
-- network (M6).
function chain.tick(world_key)
  local s, state = chain.suit(), chain.state()
  local current = chain.current()
  steer(current, sim.dt)
  for _, d in ipairs(state.dolls) do -- dolls on autopilot go on without the Commander
    if d ~= current and d.auto then steer(d, sim.dt) end
  end
  local moved = state.world ~= world_key
  state.world = world_key
  for _, d in ipairs(state.dolls) do
    if d.kind == "exosuit" then d.x, d.y, d.z = s.x, s.y, s.z
    elseif moved and dolls.by_id[d.kind].place == "ground" then d.y = chain.ground(d.x, d.z) end
  end
end

-- How far the seat bobs with a legged doll's stride (presentation; metres up), 0 for others.
function chain.bob(d)
  local ctl = dolls.by_id[d.kind].controller
  if not ctl or ctl.kind ~= "legged" or math.abs(d.speed or 0) < 0.01 then return 0 end
  return math.min(1.2, dolls.by_id[d.kind].size_m * 0.004) * math.abs(fk.math.sin((d.stride or 0) / ctl.stride * math.pi))
end

-- Where the Commander's eye is when seated in doll d (its seat; the Exosuit's is drawn by main.lua).
function chain.seat(d)
  local def = dolls.by_id[d.kind]
  local sx, sz, c, s = def.seat[1] * def.size_m, def.seat[3] * def.size_m, fk.math.cos(d.yaw or 0), fk.math.sin(d.yaw or 0)
  return { d.x + sx * c + sz * s, d.y + def.seat[2] * def.size_m, d.z - sx * s + sz * c }
end

-- The doll's turn about the vertical (radians; 0 faces +z) as a column-major matrix at its place.
function chain.matrix(d, y_offset)
  local c, s = math.cos(d.yaw or 0), math.sin(d.yaw or 0)
  return { c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, d.x, d.y + (y_offset or 0), d.z, 1 }
end

-- Draws every doll out in the world but the Exosuit (presentation): hulls built once per kind, in the depth slice
-- their distance from the eye needs.
function chain.draw(state, eye)
  state.meshes = state.meshes or {}
  local n = 0
  for _, d in ipairs(chain.state().dolls) do
    if d.kind ~= "exosuit" then
      local def = dolls.by_id[d.kind]
      state.meshes[d.kind] = state.meshes[d.kind] or fk.gfx.mesh(hull.build(def.hull, def.size_m))
      local dx, dy, dz = d.x - eye[1], d.y - eye[2], d.z - eye[3]
      local far = math.sqrt(dx * dx + dy * dy + dz * dz)
      local slice = far < 2e4 and "local" or far < 2e7 and "planetary" or "celestial"
      fk.gfx.draw(state.meshes[d.kind], chain.matrix(d, -0.05),
        { roughness = def.roughness or 0.6, metalness = def.metalness or 0, slice = slice })
      n = n + 1
    end
  end
  return n
end

return chain
