-- The Fukuruma chain (doll-chain spec): which dolls are out in the world, where, which ones each holds docked, and
-- which one the Commander is in. Simulation: a saved component, changed only by the deploy, recall and board
-- commands. Places are in the range's local frame (metres, y up from the ground at the range); orbits are parked
-- straight above the range.
local sim = require("fk.sim")
local dolls = require("dolls")
local hull = require("dolls.hull")

local chain = {}

chain.REACH = 2.5 -- a doll deploys and boards only what stands within this many of its own sizes (or its parent)

-- The chain at the start of a game: the Jump Ship far above, its station in orbit, the Continental Explorer in the
-- sky to the south, the Land Explorer and the Walker on the ground south of the range, the Commander in the
-- Exosuit on the range (the suit of main.lua). {kind, x, y (ground: above the ground; else above the range), z}
chain.START = {
  { "jump_ship", 0, 3.0e7, 0 }, -- high orbit (drawn with the floating origin: fk.gfx.origin)
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
function chain.on_foot() return chain.current().kind == "exosuit" and not chain.state().walk end

local function distance(a, b)
  local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Is doll d in the star system the range is in? Only the Jump Ship leaves a system; what it deployed stays there.
local function here(d)
  return d.system == nil or d.system == require("universe").state().seed
end
chain.here = here

local function near(a, b)
  return distance(a, b) <= math.max(dolls.by_id[a.kind].size_m, dolls.by_id[b.kind].size_m) * chain.REACH
end

-- Can the Commander go from doll a to doll b? A Drop Ship docks with any doll near it, either way. Otherwise b is a's
-- parent or child: in orbit both (their hangars), or on and over the ground both and near. Between orbit and the
-- ground only a Drop Ship goes.
local function linked(a, b)
  if not here(a) or not here(b) then return false end
  if a.stolen or b.stolen then return false end -- (thieves.lua: in other hands until recovered)
  if a.kind == "drop_ship" or b.kind == "drop_ship" then return near(a, b) end
  if b.parent ~= a.id and a.parent ~= b.id then return false end
  local ao, bo = dolls.by_id[a.kind].place == "orbit", dolls.by_id[b.kind].place == "orbit"
  if ao or bo then return ao and bo end
  return near(a, b)
end

chain.TELEPORT = { jump_ship = true, space_station = true } -- the teleport network's nodes

-- The physics world's columns for the legs of the dolls standing on the ground (not the Exosuit, which is the
-- suit's own body): made when a doll is out, moved with it, removed when it is recalled. Their IDs are part of the
-- doll's saved state, like the bodies themselves are part of the physics world's.
local function solid(d)
  local def = dolls.by_id[d.kind]
  if d.kind == "exosuit" or def.place ~= "ground" or not chain.world then return end
  if not here(d) then -- left behind in another system: not in this world's physics
    for _, id in ipairs(d.bodies or {}) do chain.world:remove(id) end
    d.bodies = nil
    return
  end
  local feet = hull.feet(def.hull, def.size_m)
  local c, s = fk.math.cos(d.yaw or 0), fk.math.sin(d.yaw or 0)
  d.bodies = d.bodies or {}
  for i, f in ipairs(feet) do
    local x, z = d.x + f[1] * c + f[2] * s, d.z - f[1] * s + f[2] * c
    local at = { x, d.y + f[4] / 2, z }
    if d.bodies[i] then chain.world:set(d.bodies[i], { position = at })
    else d.bodies[i] = chain.world:add({ shape = "box", size = { f[3], f[4], f[3] }, position = at, kinematic = true }) end
  end
end

local function unsolid(d)
  for _, id in ipairs(d.bodies or {}) do chain.world:remove(id) end
  d.bodies = nil
end

-- Sets up the component and the commands. suit(): the suit's state {x, y, z}; move_suit(x, y, z): puts the suit
-- (feet) there; world (optional): the physics world the legged dolls stand in.
function chain.install(suit, move_suit, world)
  chain.world, chain.hands = world, {}
  chain.id = sim.create()
  local list, parent = {}, nil
  for i, s in ipairs(chain.START) do
    local x, y, z = place(s[1], s[2], s[3], s[4])
    local h = holds(s[1])
    local nxt = chain.START[i + 1]
    if nxt then h[nxt[1]] = h[nxt[1]] - 1 end -- the next one down is out
    list[i] = { id = i, kind = s[1], parent = parent, x = x, y = y, z = z, yaw = 0, speed = 0, stride = 0, hold = h,
      system = require("universe").state().seed }
    parent = i
  end
  -- the Drop Ship that brought the Continental Explorer down waits beside it, its hold empty (from the station's)
  local ce, station = list[3], list[2]
  station.hold.drop_ship = (station.hold.drop_ship or 0) - 1
  local drop = holds("drop_ship")
  drop.continental_explorer = 0
  list[#list + 1] = { id = #list + 1, kind = "drop_ship", parent = station.id, x = ce.x + 16000, y = ce.y, z = ce.z, yaw = 0,
    speed = 0, stride = 0, hold = drop, system = ce.system }
  sim.set(chain.id, "chain", { dolls = list, at = #list - 1, next = #list + 1 })
  chain.suit, chain.move_suit = suit, move_suit

  -- a docked doll of kind out of doll c, beside it; returns it (or nil when c holds none)
  local function deploy(c, kind)
    local s = chain.state()
    if not (c.hold[kind] and c.hold[kind] > 0) then return nil end
    local o = dolls.by_id[kind].offset
    local x, y, z = c.x + o[1], (dolls.by_id[kind].place == "orbit" and 0 or c.y) + o[2], c.z + o[3]
    if dolls.by_id[kind].place == "ground" then x, y, z = place(kind, x, o[2], z) end
    c.hold[kind] = c.hold[kind] - 1
    local d = { id = s.next, kind = kind, parent = c.id, x = x, y = y, z = z, yaw = c.yaw or 0, speed = 0, stride = 0,
      hold = holds(kind), system = c.system }
    s.next = s.next + 1
    s.dolls[#s.dolls + 1] = d
    if kind == "exosuit" then move_suit(x, y, z) end
    sim.emit("deploy", { position = { x, y, z }, kind = kind, id = d.id, strength = 1 })
    return d
  end
  chain.deploy_from = deploy

  sim.on("deploy", function(args) -- a docked doll out of the one the Commander is in, beside it
    deploy(chain.current(), args.kind)
  end)

  sim.on("use", function() chain.use() end) -- the Commander's hand: interior.lua's fixtures and doors

  sim.on("recall", function(args) -- a child of the Commander's doll back into its hold (nobody in it, nothing out)
    local c, s = chain.current(), chain.state()
    local d = chain.find(args.id)
    local carried = c.kind == "drop_ship" and d and dolls.by_id.drop_ship.carries[d.kind] and near(c, d) and here(d)
    if not d or (d.parent ~= c.id and not carried) then return end -- (a Drop Ship takes in a doll it can carry, near it)
    for _, o in ipairs(s.dolls) do
      if o.parent == d.id then return end
    end
    for i, o in ipairs(s.dolls) do
      if o == d then table.remove(s.dolls, i) break end
    end
    unsolid(d)
    c.hold[d.kind] = (c.hold[d.kind] or 0) + 1
    sim.emit("recall", { position = { d.x, d.y, d.z }, kind = d.kind, id = d.id, strength = 0.8 })
  end)

  sim.on("board", function(args) -- the Commander goes to the controls of a parent or child doll nearby
    local c = chain.current()
    local d = chain.find(args.id)
    if not d or not linked(c, d) then return end
    c.drive = nil -- the doll left behind stops
    chain.state().at, chain.state().walk = d.id, nil -- (at its controls)
    sim.emit("board", { position = { d.x, d.y, d.z }, kind = d.kind, id = d.id, strength = 0.6 })
  end)

  sim.on("teleport", function(args) -- between the Jump Ship and the stations, however far apart (teleport network)
    local c, d = chain.current(), chain.find(args.id)
    if not d or d == c or not chain.TELEPORT[c.kind] or not chain.TELEPORT[d.kind] then return end
    chain.state().at, chain.state().walk = d.id, nil
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
  local p = chain.current().parent
  return p and here(chain.find(p)) and p or nil
end

function chain.down()
  local c, best, id = chain.current(), math.huge, nil
  for _, d in ipairs(chain.state().dolls) do
    if d.parent == c.id and here(d) and distance(c, d) < best then best, id = distance(c, d), d.id end
  end
  return id
end

-- Is the suit out in this system (an Exosuit deployed here)? Otherwise it is neither simulated nor drawn.
function chain.suit_out()
  for _, d in ipairs(chain.state().dolls) do
    if d.kind == "exosuit" and here(d) then return true end
  end
  return false
end

-- The teleport button's target: from the Jump Ship the first station, from a station the Jump Ship (or nil).
function chain.teleport_target()
  local c = chain.current()
  if not chain.TELEPORT[c.kind] then return nil end
  for _, d in ipairs(chain.state().dolls) do
    if d ~= c and here(d) and chain.TELEPORT[d.kind] and (c.kind ~= d.kind) then return d.id end
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
    local fits = here(d) and (high and d.kind == "continental_explorer" or not high and dolls.by_id[d.kind].place == "orbit")
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
    if here(d) and (d.parent == c.id or d.id == c.parent) then out[#out + 1] = label(d.kind) .. " " .. metres(distance(c, d)) end
  end
  if #out == 1 then out[2] = "NONE" end
  local target = c.auto and chain.find(c.auto)
  local list = { { label(c.kind), "AT THE CONTROLS" }, hold, out,
    { "ALTITUDE", metres(math.max(0, c.y - chain.ground(c.x, c.z))) }, { "B UP  N DOWN", "T DEPLOY  R RECALL" },
    target and { "AUTOPILOT", label(target.kind) .. " " .. metres(distance(c, target)) } or { "AUTOPILOT", "O: OFF" },
    { "TELEPORT", chain.TELEPORT[c.kind] and "P: READY" or "NO NODE" } }
  if chain.sensor_screen then list[#list + 1] = chain.sensor_screen(c) end -- (sensors.lua)
  if chain.wear_screen then list[#list + 1] = chain.wear_screen(c) end -- (living.lua)
  for i = #list + 1, 8 do list[i] = { "SYSTEMS", "NOMINAL" } end
  return list
end

-- Steering (vehicle controllers): throttle and turn (-1..1) and lift (-1..1, flying dolls) for the doll the
-- Commander sits in. Each doll's controller (its definition's controller field) moves it every tick:
--   legged {speed, accel, turn, stride}: walks on the ground; a stomp event every stride (metres)
--   flight {speed, accel, turn, climb, min_altitude}: flies, no lower than min_altitude above the ground
--   orbit: goes round the world at its height (stations, the Jump Ship); fixed: holds its place
function chain.install_drive()
  sim.on("drive", function(args)
    local c = chain.current()
    if c.kind == "exosuit" then return end
    local function clamp(v) return math.max(-1, math.min(1, tonumber(v) or 0)) end
    c.drive = { throttle = clamp(args.throttle), turn = clamp(args.turn), lift = clamp(args.lift) }
    if c.drive.throttle ~= 0 or c.drive.turn ~= 0 or c.drive.lift ~= 0 then c.auto = nil end -- the hands take over
  end)
end

-- Doll d's distance from the world's centre, and the ground's (its surface straight below d), in metres. Flying
-- dolls keep their height this way, so they can follow the world's curve all the way round (to a station on the far
-- side); near the range it is the same as the height above chain.ground.
local function radial(d)
  local g = require("universe").ground()
  if not g then return d.y, 0 end
  local R = -g.centre[2]
  local x, y, z = d.x, d.y + R, d.z
  local r = math.sqrt(x * x + y * y + z * z)
  if r < 1e-6 then return 0, R end
  local up, e, n = g.up, g.east, g.north
  local dir = { (e[1] * x + up[1] * y + n[1] * z) / r, (e[2] * x + up[2] * y + n[2] * z) / r, (e[3] * x + up[3] * y + n[3] * z) / r }
  return r, R + g.surface:height(dir[1], dir[2], dir[3]) - g.surface:height(up[1], up[2], up[3])
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
  local climb = dy -- towards a doll in orbit: up or down to its distance from the world's centre, not its local height
  if dolls.by_id[t.kind].place == "orbit" then climb = radial(t) - radial(d) end
  local lift = ctl.kind == "flight" and math.max(-1, math.min(1, climb / math.max(500, flat * 0.2))) or 0
  return { throttle = ahead < 0.3 and 0.3 or 1, turn = turn, lift = lift }
end

-- How fast a doll may go: flying dolls faster the higher they are (thin air; a Drop Ship from orbit), up to 15 km/s
-- (an orbiting station goes round at about 7.7 km/s).
-- Worn engines go slower (living.lua: chain.speed_factor).
local function top_speed(d, ctl)
  local worn = chain.speed_factor and chain.speed_factor(d) or 1
  if ctl.kind ~= "flight" then return ctl.speed * worn end
  local r, ground = radial(d)
  return math.min(15000, ctl.speed * (1 + math.max(0, r - ground) / 1000)) * worn
end

-- An orbiting doll goes round the world on a circle through the plane over the range (x up from its centre),
-- starting overhead, at the speed its height needs: sqrt(GM / r^3), GM from the world's gravity and radius.
local function orbit(d, dt)
  local g = require("universe").ground()
  if not g then return end
  local R = -g.centre[2] -- the world's centre lies straight below the range
  d.altitude = d.altitude or d.y
  local r = R + d.altitude
  local gravity = chain.world and -chain.world:gravity()[2] or 9.81
  d.theta = (d.theta or 0) + math.sqrt(gravity * R * R / (r * r * r)) * dt
  d.x, d.y, d.z = r * fk.math.sin(d.theta), -R + r * fk.math.cos(d.theta), 0
end

-- A flying doll's autopilot: a transfer around the world's centre in the plane over the range. Its distance from the
-- centre goes towards the target's and its angle turns towards the target's, both at its top speed (no angles are
-- computed: the target's direction is taken once within a step's turn, else the doll turns a step its way); its
-- sideways offset (z) closes in too. Up to orbit, round to a station on the far side, and back down alike.
local function transfer(d, t, ctl, dt)
  local R = -require("universe").ground().centre[2]
  local ax, ay, bx, by = d.x, d.y + R, t.x, t.y + R
  local ra, rb = math.sqrt(ax * ax + ay * ay), math.sqrt(bx * bx + by * by)
  local top = top_speed(d, ctl)
  local step = top * dt
  local r = ra + math.max(-step, math.min(step, rb - ra))
  local cos, sin = (ax * bx + ay * by) / (ra * rb), (ax * by - ay * bx) / (ra * rb)
  local turn = step / ra
  local ux, uy
  if cos >= fk.math.cos(turn) then ux, uy = bx / rb, by / rb
  else
    local c, s = fk.math.cos(turn), fk.math.sin(turn) * (sin >= 0 and 1 or -1)
    ux, uy = (ax * c - ay * s) / ra, (ax * s + ay * c) / ra
  end
  d.x, d.y = ux * r, uy * r - R
  d.z = d.z + math.max(-step, math.min(step, t.z - d.z))
  d.speed = top
  local rr, floor = radial(d) -- never below its floor
  floor = floor + ctl.min_altitude
  if rr < floor then
    local k = floor / rr
    d.x, d.y, d.z = d.x * k, (d.y + R) * k - R, d.z * k
  end
end

local function steer(d, dt)
  local ctl = dolls.by_id[d.kind].controller
  if ctl and ctl.kind == "orbit" then return orbit(d, dt) end
  if ctl and ctl.kind == "flight" and d.auto and require("universe").ground() then -- flying on autopilot: a transfer
    local t = chain.find(d.auto)
    if t and autopilot(d, t, ctl) then return transfer(d, t, ctl, dt) end
  end
  if not ctl or ctl.kind == "fixed" then return end
  d.yaw, d.speed, d.stride = d.yaw or 0, d.speed or 0, d.stride or 0 -- (games saved before the controllers)
  local drive = d.drive or { throttle = 0, turn = 0, lift = 0 }
  local hazard = d.auto and chain.hazard_ahead and chain.hazard_ahead(d) -- (sensors.lua: a detected hazard in the way)
  if hazard then -- the autopilot stops short of it, and hands back to the Commander
    d.auto = nil
    sim.emit("hazard_stop", { position = { d.x, d.y, d.z }, kind = d.kind, hazard = hazard.kind, strength = 0.7 })
  end
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
    d.y = d.y + drive.lift * ctl.climb * dt * top / ctl.speed -- (faster up high too)
    local r, floor = radial(d)
    floor = floor + ctl.min_altitude
    if r < floor then -- no lower than the floor over the ground below it, measured from the world's centre
      local R = -require("universe").ground().centre[2]
      local k = floor / r
      d.x, d.y, d.z = d.x * k, (d.y + R) * k - R, d.z * k
    end
  end
end

-- On foot inside the dolls (vessel-interiors spec). state.walk = {doll (the doll whose hold or rooms), docked (the
-- kind docked in its hangar the Commander is inside, or nil), x, z (interior frame), wx, wz (wanted velocity)} while
-- the Commander walks as a human; nil when seated or in the Exosuit. Doors: state.doors[kind .. "/" .. room] = true
-- while shut (saved: the doors' deltas).
local interior = require("interior")

chain.WALK = 0.55 -- the human's speed against the suit's move command (a 1.4 m/s walk)

function chain.walking() return chain.state().walk end

local function door_open(kind)
  local doors = chain.state().doors or {}
  return function(name) return not doors[kind .. "/" .. name] end
end
chain.door_open = door_open

-- The walk's layout kind: the docked doll's, else the doll's own.
function chain.walk_kind(w)
  w = w or chain.state().walk
  return w and (w.docked or chain.find(w.doll).kind)
end

-- The move command while walking: the wanted velocity in the doll's frame (main.lua's helmet turns from its front).
function chain.walk_input(x, z)
  local w = chain.state().walk
  if w then w.wx, w.wz = x * chain.WALK, z * chain.WALK end
end

chain.TRAM = 12 -- seconds a tram ride takes at most (speed: at least 40 m/s)

local function walk_tick(dt)
  local w = chain.state().walk
  if w and w.ride then -- on the tram: carried to the stop, the walk held
    local dx, dz = w.ride[1] - w.x, w.ride[2] - w.z
    local left = math.sqrt(dx * dx + dz * dz)
    local step = math.max(40, w.ride[3] / chain.TRAM) * dt
    if left <= step then w.x, w.z, w.ride = w.ride[1], w.ride[2] + 1.5, nil -- (off the tram, beside its stop)
    else w.x, w.z = w.x + dx / left * step, w.z + dz / left * step end
    return
  end
  if not w or not w.wx then return end
  local kind = chain.walk_kind(w)
  interior.move(interior.layout(kind), w, w.wx * dt, w.wz * dt, door_open(kind))
end

local function fixture(layout, name, kind)
  for _, f in ipairs(layout.fixtures) do
    if f[1] == name and (not kind or f.kind == kind) then return f end
  end
end

-- Where a doll's interior stands: {x, y, z (its floor's origin in the range's frame), yaw}. Its bridge seat is where
-- the doll's seat is (cockpit.EYE above the floor), so the cabin seen from the seat and walked into are the same
-- place. A docked doll's interior stands at its ramp in its parent's hangar.
function chain.interior_frame(d, docked)
  local cockpit = require("dolls.cockpit")
  local seat, layout = chain.seat(d), interior.layout(d.kind)
  local c, s = fk.math.cos(d.yaw or 0), fk.math.sin(d.yaw or 0)
  local sz = layout.seat[2]
  local frame = { x = seat[1] - sz * s, y = seat[2] - cockpit.EYE, z = seat[3] - sz * c, yaw = d.yaw or 0 }
  if docked then
    local ramp, spawn = fixture(layout, "ramp", docked), interior.layout(docked).spawn
    local x, z = ramp[2] - spawn[1], ramp[3] + 2 - spawn[2]
    frame.x, frame.z = frame.x + x * c + z * s, frame.z - x * s + z * c
  end
  return frame
end

-- A point of an interior frame in the range's frame, and the frame as a column-major matrix.
function chain.frame_point(f, x, y, z)
  local c, s = fk.math.cos(f.yaw), fk.math.sin(f.yaw)
  return { f.x + x * c + z * s, f.y + y, f.z - x * s + z * c }
end

function chain.frame_matrix(f)
  local c, s = math.cos(f.yaw), math.sin(f.yaw)
  return { c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, f.x, f.y, f.z, 1 }
end

-- What the use command would do now (presentation: the hint on the visor), or nil.
-- What else the hand can do on foot (other modules: talking, pylons, recovering a stolen doll): {hint = function()
-- -> text or nil, act = function()}, asked in order before entering the doll.
chain.hands = {}
-- What the rooms' fixtures do (living.lua): {[kind] = {hint = function(doll, fixture) -> text or nil, act = function(doll, fixture)}}.
chain.fixtures = {}

local function hand()
  if chain.current().kind ~= "exosuit" or chain.state().walk then return nil end
  for _, h in ipairs(chain.hands) do
    local text = h.hint()
    if text then return h, text end
  end
end

function chain.use_hint()
  local s = chain.state()
  local w, c = s.walk, chain.current()
  local _, extra = hand()
  if extra then return extra end
  if not w then
    if c.kind == "exosuit" then
      local p = c.parent and chain.find(c.parent)
      return p and linked(c, p) and here(p) and ("ENTER THE " .. label(p.kind)) or nil
    end
    return "STAND UP"
  end
  local kind = chain.walk_kind(w)
  local f = interior.near(interior.layout(kind), w.x, w.z, w.docked ~= nil)
  if not f then return nil end
  local d = chain.find(w.doll)
  if f[1] == "door" then return (door_open(kind)(f.name) and "CLOSE" or "OPEN") .. " THE " .. f.name:upper() .. " DOOR"
  elseif f[1] == "seat" then return w.docked and ("LAUNCH THE " .. label(w.docked)) or "TAKE THE CONTROLS"
  elseif f[1] == "ramp" then return (d.hold[f.kind] or 0) > 0 and ("BOARD THE " .. label(f.kind)) or nil
  elseif f[1] == "exit" then return "DOWN THE RAMP"
  elseif f[1] == "suit" then return (d.hold.exosuit or 0) > 0 and "SUIT UP AND GO OUT" or nil
  elseif f[1] == "tram" then return w.ride and "ON THE TRAM" or ("TRAM TO THE " .. interior.next_stop(interior.layout(kind), f).stop:upper())
  elseif chain.fixtures[f[1]] and not w.docked then return chain.fixtures[f[1]].hint(d, f) -- (living.lua: the rooms' fixtures)
  end
end

-- The use command: what the Commander's hand does where the Commander is.
function chain.use()
  local s = chain.state()
  local w, c = s.walk, chain.current()
  local h = hand()
  if h then return h.act() end
  if not w then
    if c.kind == "exosuit" then -- out of the suit into its doll, through the suit bay (the suit goes into the hold)
      local p = c.parent and chain.find(c.parent)
      if not p or not linked(c, p) or not here(p) then return end
      for i, o in ipairs(s.dolls) do
        if o == c then table.remove(s.dolls, i) break end
      end
      p.hold.exosuit = (p.hold.exosuit or 0) + 1
      local f = fixture(interior.layout(p.kind), "suit") or { 0, 0, 2 }
      s.at, s.walk = p.id, { doll = p.id, x = f[2] - (f[2] > 0 and 1.2 or -1.2), z = f[3] } -- (towards the door)
      sim.emit("board", { position = { p.x, p.y, p.z }, kind = p.kind, id = p.id, strength = 0.6 })
    else -- up from the seat, onto the bridge
      local f = fixture(interior.layout(c.kind), "seat")
      s.walk = { doll = c.id, x = f[2], z = f[3] }
    end
    return
  end
  local kind = chain.walk_kind(w)
  local layout = interior.layout(kind)
  local f = interior.near(layout, w.x, w.z, w.docked ~= nil)
  if not f then return end
  local d = chain.find(w.doll)
  if f[1] == "door" then
    s.doors = s.doors or {}
    local key = kind .. "/" .. f.name
    for _, r in ipairs(layout.doors) do -- a door does not shut on the Commander standing in it
      if r.name == f.name and not s.doors[key] and w.x >= r.x0 and w.x <= r.x1 and w.z >= r.z0 and w.z <= r.z1 then return end
    end
    s.doors[key] = not s.doors[key] or nil
    sim.emit("door", { position = { d.x, d.y, d.z }, strength = 0.3 })
  elseif f[1] == "seat" then
    if w.docked then -- at a docked doll's controls: it launches out of the hold, with the Commander at its controls
      local new = chain.deploy_from(d, w.docked)
      if not new then return end
      s.at, s.walk = new.id, nil
    else
      s.walk = nil -- at the controls
    end
  elseif f[1] == "ramp" and (d.hold[f.kind] or 0) > 0 and not w.docked then
    local spawn = interior.layout(f.kind).spawn
    s.walk = { doll = d.id, docked = f.kind, x = spawn[1], z = spawn[2] }
  elseif f[1] == "exit" and w.docked then
    local ramp = fixture(interior.layout(d.kind), "ramp", w.docked)
    s.walk = { doll = d.id, x = ramp[2], z = ramp[3] + 1.5 }
  elseif f[1] == "tram" and not w.ride then -- on to the next stop (interior-transit: the hangars are kilometres long)
    local to = interior.next_stop(layout, f)
    w.ride = { to[2], to[3], math.sqrt((to[2] - w.x) * (to[2] - w.x) + (to[3] - w.z) * (to[3] - w.z)) }
    sim.emit("tram", { position = { d.x, d.y, d.z }, strength = 0.4 })
  elseif f[1] == "suit" and not w.docked then -- the Exosuit goes on: out beside the doll, on foot
    local exo = chain.deploy_from(d, "exosuit")
    if exo then s.at, s.walk = exo.id, nil end
  elseif chain.fixtures[f[1]] and not w.docked then chain.fixtures[f[1]].act(d, f)
  end
end

-- Each tick: the doll the Commander steers moves; the Exosuit's place follows the suit; on another world (world_key), the dolls on the ground stand on its
-- ground.
-- shortcut: the whole chain goes along with a jump; stations staying behind in their systems come with the teleport
-- network (M6).
function chain.tick(world_key)
  local s, state = chain.suit(), chain.state()
  local current = chain.current()
  walk_tick(sim.dt)
  local moved_on = state.world ~= world_key and state.world ~= nil
  if moved_on and current.kind == "jump_ship" then current.system = require("universe").state().seed end -- it jumped
  steer(current, sim.dt)
  for _, d in ipairs(state.dolls) do -- dolls on autopilot go on without the Commander; orbits go round anyway
    local ctl = dolls.by_id[d.kind].controller
    if d ~= current and here(d) and (d.auto or ctl and ctl.kind == "orbit") then steer(d, sim.dt) end
  end
  local moved = state.world ~= world_key
  state.world = world_key
  for _, d in ipairs(state.dolls) do
    if d.kind == "exosuit" and here(d) then d.x, d.y, d.z = s.x, s.y, s.z
    elseif moved and here(d) and dolls.by_id[d.kind].place == "ground" then d.y = chain.ground(d.x, d.z) end
    solid(d)
  end
end

-- How far the seat bobs with a legged doll's stride (presentation; metres up), 0 for others.
function chain.bob(d)
  local ctl = dolls.by_id[d.kind].controller
  if not ctl or ctl.kind ~= "legged" or math.abs(d.speed or 0) < 0.01 then return 0 end
  return math.min(1.2, dolls.by_id[d.kind].size_m * 0.004) * math.abs(fk.math.sin((d.stride or 0) / ctl.stride * math.pi))
end

-- The seat's sway (presentation): the cabin rolls into turns (flying dolls bank harder) and pitches as the doll speeds
-- up or brakes, eased so it lags the doll a little. state: kept between frames. Returns roll, pitch (radians).
function chain.sway(state, d, dt)
  local ctl = dolls.by_id[d.kind].controller
  local yaw_rate, accel = 0, 0
  if state.id == d.id and dt > 0 then yaw_rate, accel = (d.yaw - state.yaw) / dt, (d.speed - state.speed) / dt end
  state.id, state.yaw, state.speed = d.id, d.yaw or 0, d.speed or 0
  if not ctl or ctl.kind == "fixed" then yaw_rate, accel = 0, 0 end
  local bank = ctl and ctl.kind == "flight" and 2.5 or 0.6
  local roll = math.max(-0.35, math.min(0.35, yaw_rate * bank))
  local pitch = ctl and ctl.speed and math.max(-0.12, math.min(0.12, -accel / ctl.speed * 4)) or 0
  local k = math.min(1, dt * 3)
  state.roll = (state.roll or 0) + (roll - (state.roll or 0)) * k
  state.pitch = (state.pitch or 0) + (pitch - (state.pitch or 0)) * k
  return state.roll, state.pitch
end

-- How loud a doll's engines run (presentation, 0..1): flying dolls by their speed, others none.
function chain.engine(d)
  local ctl = dolls.by_id[d.kind].controller
  if not ctl or ctl.kind ~= "flight" then return 0 end
  return math.min(1, 0.25 + 0.75 * math.abs(d.speed or 0) / ctl.speed)
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

chain.EMERGE = 3 -- seconds a newly deployed doll takes to ease out of its parent (presentation)

-- Where doll d is drawn at presentation time now: easing out of its parent for chain.EMERGE seconds after it first
-- appears (a deploy), else where it is.
local function shown(state, d, now)
  local e = state.emerging[d.id]
  if not e then
    local p = state.started and d.parent and chain.find(d.parent)
    e = { from = p and { p.x, p.y, p.z } or false, at = now }
    state.emerging[d.id] = e
  end
  local k = e.from and math.min(1, (now - e.at) / chain.EMERGE) or 1
  if k >= 1 then return d end
  k = k * k * (3 - 2 * k)
  return { x = e.from[1] + (d.x - e.from[1]) * k, y = e.from[2] + (d.y - e.from[2]) * k,
    z = e.from[3] + (d.z - e.from[3]) * k, yaw = d.yaw }
end

-- Draws every doll out in the world but the Exosuit (presentation): hulls built once per kind, in the depth slice
-- their distance from the eye needs; a newly deployed one eases out of its parent (now: presentation time).
function chain.draw(state, eye, now)
  state.meshes, state.emerging, now = state.meshes or {}, state.emerging or {}, now or 0
  local n, walk, nearest = 0, chain.state().walk, math.huge
  for _, real in ipairs(chain.state().dolls) do
    local d = shown(state, real, now)
    if real.kind ~= "exosuit" and here(real) and not (walk and walk.doll == real.id) then -- (inside it: its rooms instead)
      local def = dolls.by_id[real.kind]
      state.meshes[real.kind] = state.meshes[real.kind] or fk.gfx.mesh(hull.build(def.hull, def.size_m))
      state.lights = state.lights or {}
      if state.lights[real.kind] == nil then -- its lights (windows, engines, beacons): a second mesh, glowing
        local m = hull.build(def.hull, def.size_m, "glow")
        state.lights[real.kind] = #m.indices > 0 and fk.gfx.mesh(m) or false
      end
      local dx, dy, dz = d.x - eye[1], d.y - eye[2], d.z - eye[3]
      local far = math.sqrt(dx * dx + dy * dy + dz * dz)
      -- the local slice reaches 400 m: a doll goes there only if all of it is nearer
      local slice = far + def.size_m * 0.75 < 400 and "local" or far < 2e7 and "planetary" or "celestial"
      if slice == "planetary" then nearest = math.min(nearest, far - def.size_m * 0.75) end
      local m = chain.matrix(d, -0.05)
      fk.gfx.draw(state.meshes[real.kind], m, { roughness = def.roughness or 0.6, metalness = def.metalness or 0, slice = slice })
      if state.lights[real.kind] then
        fk.gfx.draw(state.lights[real.kind], m, { roughness = 0.3, emission = { 2.5, 2.5, 2.5 }, emissive_colors = true, slice = slice })
      end
      n = n + 1
    end
  end
  if nearest < math.huge then -- the planetary slice starts where the ground is (terrain.lua): pulled in to the nearest doll in it
    local frames = require("fk.frames")
    fk.gfx.slices({ planetary = { math.max(frames.LOCAL_FAR, nearest * 0.5), frames.PLANETARY[2] } })
  end
  state.started = true -- dolls that appear from now on were deployed
  return n
end

return chain
