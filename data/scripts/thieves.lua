-- Thieves and boarding parties (thieves-and-boarding spec). Each world's thieves (factions.lua) raid now and then, at
-- times drawn from the world's seed (a named stream):
--   a theft: a doll left on the ground unattended (nobody in it, the suit far away) is driven off to their hideout. A
--   stolen doll cannot be boarded; its beacon still shows where it is (a marker and a screen line), and the Commander
--   recovers it by reaching it on foot (F);
--   a boarding party: thieves come aboard the doll the Commander is in through its hangar (or its door) and walk its
--   corridor to the cargo deck. Sealed sectors (all doors shut: the seal command) stop them, and after a while they
--   give up; if they reach the cargo deck they loot it and leave.
local sim = require("fk.sim")
local dolls = require("dolls")
local chain = require("chain")
local sensors = require("sensors")
local interior = require("interior")

local thieves = {}

thieves.CHECK = 600            -- ticks between raid checks
thieves.FIRST = { 240, 600 }   -- seconds before the first raid on a world
thieves.EVERY = { 180, 480 }   -- seconds between raids
thieves.UNATTENDED = 300       -- metres between the suit and a doll left alone
thieves.SPEED = 14             -- m/s a stolen doll is driven at
thieves.RECOVER = 40           -- metres to reach a stolen doll on foot
thieves.WALK = 1.4             -- m/s boarders walk
thieves.PATIENCE = 60          -- seconds boarders wait at a shut door

function thieves.state() return sim.get(thieves.id, "thieves") end

-- The thieves' hideout on world key: {x, z}.
function thieves.hideout(key)
  local rng = fk.rng("hideout", key)
  local r, a = 7000 + rng:float() * 3000, rng:float() * 2 * math.pi
  return { x = r * fk.math.cos(a), z = r * fk.math.sin(a) }
end

local function next_raid(key, n, range)
  local rng = fk.rng("raids", key, n)
  return sim.tick + math.floor((range[1] + rng:float() * (range[2] - range[1])) / sim.dt)
end

-- Steals doll d now (it must be on the ground and here); returns whether it did.
function thieves.steal(d)
  if d.stolen or dolls.by_id[d.kind].place ~= "ground" or d.kind == "exosuit" or not chain.here(d) then return false end
  local key = sensors.state().world
  d.stolen, d.auto, d.drive = { to = thieves.hideout(key) }, nil, nil
  sim.emit("theft", { position = { d.x, d.y, d.z }, kind = d.kind, id = d.id, strength = 0.8 })
  return true
end

-- A boarding party comes aboard doll d; returns it.
function thieves.board(d)
  local layout = interior.layout(d.kind)
  local cargo, door
  for _, r in ipairs(layout.rooms) do
    if r.name == "cargo deck" then cargo = r end
  end
  door = cargo.door
  local start = { 0, 0.5 } -- in through the hangar's passage, or the door at the corridor's end
  for _, f in ipairs(layout.fixtures) do
    if f[1] == "tram" and f.stop == "corridor" then start = { 0, -1 } end
  end
  local party = { doll = d.id, members = 3, x = start[1], z = start[2], waited = 0,
    path = { { 0, door.z }, { door.x, door.z }, { (cargo.x0 + cargo.x1) / 2, door.z } }, step = 1 }
  thieves.state().parties[#thieves.state().parties + 1] = party
  sim.emit("boarders", { position = { d.x, d.y, d.z }, kind = d.kind, id = d.id, strength = 0.9 })
  return party
end

-- Seals the sectors of the doll the Commander is in: every door shut.
function thieves.seal()
  local s, d = chain.state(), chain.current()
  if d.kind == "exosuit" then return end
  s.doors = s.doors or {}
  for _, r in ipairs(interior.layout(d.kind).rooms) do
    if r.door then s.doors[d.kind .. "/" .. r.name] = true end
  end
  sim.emit("sealed", { position = { d.x, d.y, d.z }, kind = d.kind, strength = 0.5 })
end

local function stolen_near()
  if chain.current().kind ~= "exosuit" or chain.state().walk then return nil end
  local p = chain.suit()
  for _, d in ipairs(chain.state().dolls) do
    local dx, dz = d.x - p.x, d.z - p.z
    if d.stolen and chain.here(d) and dx * dx + dz * dz < thieves.RECOVER * thieves.RECOVER then return d end
  end
end

function thieves.install()
  thieves.id = sim.create()
  sim.set(thieves.id, "thieves", { parties = {}, raid_at = nil, raids = 0, world = nil })
  sim.on("seal", function() thieves.seal() end)
  chain.hands[#chain.hands + 1] = {
    hint = function()
      local d = stolen_near()
      return d and ("RECOVER THE " .. dolls.by_id[d.kind].name:upper()) or nil
    end,
    act = function()
      local d = stolen_near()
      if not d then return end
      d.stolen = nil -- the thieves run; the doll is the Commander's again
      sim.emit("recovered", { position = { d.x, d.y, d.z }, kind = d.kind, id = d.id, strength = 0.8 })
    end,
  }
end

-- A raid now: boarders if the Commander is aboard a doll with hangars, else a theft of a doll left alone.
local function raid(key, s)
  local current, p = chain.current(), chain.suit()
  local rng = fk.rng("raid-kind", key, s.raids)
  local big = current.kind ~= "exosuit" and interior.layout(current.kind).length > 60
  if big and rng:chance(0.5) then return thieves.board(current) end
  for _, d in ipairs(chain.state().dolls) do
    local dx, dz = d.x - p.x, d.z - p.z
    if d ~= current and dx * dx + dz * dz > thieves.UNATTENDED * thieves.UNATTENDED and thieves.steal(d) then return d end
  end
end

-- Each tick: raids when they are due; stolen dolls are driven off; boarders walk.
function thieves.tick(world_key)
  local s = thieves.state()
  if s.world ~= world_key then s.world, s.raid_at = world_key, next_raid(world_key, s.raids, thieves.FIRST) end
  if sim.tick % thieves.CHECK == 0 and sim.tick >= s.raid_at then
    raid(world_key, s)
    s.raids = s.raids + 1
    s.raid_at = next_raid(world_key, s.raids, thieves.EVERY)
  end
  local dt = sim.dt
  for _, d in ipairs(chain.state().dolls) do
    if d.stolen and chain.here(d) then
      local dx, dz = d.stolen.to.x - d.x, d.stolen.to.z - d.z
      local left = math.sqrt(dx * dx + dz * dz)
      if left > 1 then
        local step = math.min(left, thieves.SPEED * dt)
        d.x, d.z = d.x + dx / left * step, d.z + dz / left * step
        d.y = chain.ground(d.x, d.z)
        d.yaw = fk.math.atan2(dx, dz)
      end
    end
  end
  local keep = {}
  for _, party in ipairs(s.parties) do
    local d = chain.find(party.doll)
    local open = chain.door_open(d.kind)
    local target = party.path[party.step]
    local dx, dz = target[1] - party.x, target[2] - party.z
    local left = math.sqrt(dx * dx + dz * dz)
    local blocked = party.step == 2 and not open("cargo deck") -- (the leg through the cargo deck's door)
    if blocked then
      party.waited = party.waited + dt
      if party.waited >= thieves.PATIENCE then
        sim.emit("repelled", { position = { d.x, d.y, d.z }, kind = d.kind, strength = 0.6 })
        party = nil
      end
    elseif left <= thieves.WALK * dt then
      party.x, party.z = target[1], target[2]
      party.step = party.step + 1
      if party.step > #party.path then
        d.looted = (d.looted or 0) + 1
        sim.emit("looted", { position = { d.x, d.y, d.z }, kind = d.kind, strength = 0.8 })
        party = nil
      end
    else
      party.x, party.z = party.x + dx / left * thieves.WALK * dt, party.z + dz / left * thieves.WALK * dt
    end
    if party then keep[#keep + 1] = party end
  end
  s.parties = keep
end

-- The cockpit screen line and the markers' text for stolen dolls (presentation).
function thieves.stolen_list(x, z)
  local out = {}
  for _, d in ipairs(chain.state().dolls) do
    if d.stolen and chain.here(d) then
      local dx, dz = d.x - x, d.z - z
      out[#out + 1] = { doll = d, dist = math.sqrt(dx * dx + dz * dz) }
    end
  end
  return out
end

-- Draws the boarders in the doll the Commander walks in (presentation).
function thieves.draw(state, frame_of)
  local walk = chain.walking()
  if not walk then return 0 end
  local hull, mat4 = require("dolls.hull"), require("mat4")
  state.mesh = state.mesh or fk.gfx.mesh(hull.build({
    { "box", at = { 0, 0.9, 0 }, size = { 0.5, 1.8, 0.35 }, color = { 0.25, 0.08, 0.08 } },
    { "box", at = { 0, 1.55, 0.18 }, size = { 0.35, 0.12, 0.05 }, color = { 1, 0.2, 0.1 } } }, 1))
  local n = 0
  for _, party in ipairs(thieves.state().parties) do
    if party.doll == walk.doll and not walk.docked then
      local frame = frame_of(chain.find(party.doll))
      for m = 1, party.members do
        local p = chain.frame_point(frame, party.x + (m - 2) * 0.7, 0, party.z - (m - 1) * 0.8)
        fk.gfx.draw(state.mesh, mat4.multiply(mat4.translation(p[1], p[2], p[3]), mat4.rotation_y(frame.yaw)),
          { roughness = 0.7, indoor = true, emission = { 0.4, 0.05, 0.05 } })
        n = n + 1
      end
    end
  end
  return n
end

return thieves
