-- Ecology and creatures (ecology, creature-generation and procedural-animation specs; defensive tools). Each world
-- gets its species from its seed (a named stream) by a body-plan grammar: legs (2, 4 or 6), a body, a neck and head,
-- a tail, colours, a size and a gait; a name from syllables. Herds of grazers and packs of predators live around the
-- range; they are sensor hazards (sensors.lua) so the dolls see them as signatures. Behaviours run at a low tick rate
-- (every THINK ticks):
--   grazers wander about their herd's home and flee from predators;
--   predators roam about their den, hunt grazers, and hunt the Commander once they notice the suit: close by when it
--   walks (passive stealth), farther when it runs, from far away when it pinged; a decoy draws them while it burns;
--   a stun stops them for a while; they bite at arm's length.
-- Creatures are simulation state (fk.math only); their legs swing from the distance walked (presentation).
local sim = require("fk.sim")
local chain = require("chain")
local sensors = require("sensors")

local ecology = {}

ecology.THINK = 6         -- ticks between behaviour steps
ecology.NOTICE = { walk = 22, run = 70, pinged = 320 } -- metres at which a predator notices the suit
ecology.BITE = 2.5        -- metres
ecology.DECOY = { range = 160, life = 20 } -- metres a decoy draws predators from; seconds it burns
ecology.STUN = { range = 15, cone = 0.5, time = 6, cooldown = 5 }
local SYLLABLES = { "ka", "ro", "vi", "tum", "esh", "or", "ba", "lin", "qua", "zet", "mo", "ur", "dra", "fen" }

sensors.HAZARDS.grazer = { signature = "bio", size = { 1, 3 }, stealth = 0.2, name = "GRAZERS" }
sensors.HAZARDS.predator.roam = nil -- (ecology moves the predators)

-- The species of world key: {grazer, predator}, each {name, legs, length, height, color, speed, stride}.
function ecology.species(key)
  local rng, out = fk.rng("species", key), {}
  for _, role in ipairs({ "grazer", "predator" }) do
    local name = ""
    for _ = 1, rng:range(2, 3) do name = name .. SYLLABLES[rng:range(1, #SYLLABLES)] end
    local length = role == "grazer" and 1.2 + rng:float() * 2 or 1.5 + rng:float() * 2.5
    local legs = ({ 2, 4, 4, 6 })[rng:range(1, 4)]
    out[role] = { role = role, name = name:upper(), legs = legs, length = length, height = length * (0.5 + rng:float() * 0.4),
      color = { 0.2 + rng:float() * 0.7, 0.2 + rng:float() * 0.6, 0.15 + rng:float() * 0.5 }, tail = rng:float() * 0.8,
      neck = rng:float() * 0.6, speed = (role == "grazer" and 2 or 3) + rng:float() * 2, stride = length * 0.8 }
  end
  return out
end

-- Adds world key's herds and packs to its hazards (sensors.on_world).
function ecology.populate(key, list, next_id)
  local rng, species = fk.rng("herds", key), ecology.species(key)
  local function add(role, hx, hz, i)
    local sp = species[role]
    local a = rng:float() * 2 * math.pi
    local h = { id = next_id(), kind = role, x = hx + 12 * fk.math.cos(a), z = hz + 12 * fk.math.sin(a), hx = hx, hz = hz,
      size = sp.length, phase = rng:float() * 2 * math.pi, stride = 0, member = i }
    list[#list + 1] = h
  end
  for _, group in ipairs({ { "grazer", 3, 5 }, { "predator", 2, 3 } }) do
    for _ = 1, group[2] do
      local r, a = 300 + rng:float() * 2200, rng:float() * 2 * math.pi
      local hx, hz = r * fk.math.cos(a), r * fk.math.sin(a)
      for i = 1, group[3] do add(group[1], hx, hz, i) end
    end
  end
end

function ecology.state() return sim.get(ecology.id, "ecology") end

function ecology.install()
  ecology.id = sim.create()
  sim.set(ecology.id, "ecology", { decoys = {}, stun_at = 0 })
  sensors.on_world = ecology.populate
  sim.on("flare", function() -- a decoy, thrown ahead from the suit or fired from the doll's seat
    local d, p = chain.current(), chain.suit()
    if chain.walking() then return end
    local fx, fz = fk.math.sin(d.yaw or 0), fk.math.cos(d.yaw or 0)
    local reach = 60
    local x, z = d.x, d.z
    if chain.on_foot() then fx, fz, reach, x, z = p.lx or 0, p.lz or 1, 25, p.x, p.z end
    local decoy = { x = x + fx * reach, z = z + fz * reach, until_tick = sim.tick + ecology.DECOY.life / sim.dt }
    local s = ecology.state()
    s.decoys[#s.decoys + 1] = decoy
    sim.emit("flare", { position = { decoy.x, chain.ground(decoy.x, decoy.z), decoy.z }, strength = 0.8 })
  end)
  sim.on("stun", function() -- the suit's stun pulse: what is close in front stops for a while
    local s, p = ecology.state(), chain.suit()
    if not chain.on_foot() or sim.tick < s.stun_at then return end
    s.stun_at = sim.tick + ecology.STUN.cooldown / sim.dt
    local fx, fz = p.lx or 0, p.lz or 1
    for _, h in ipairs(sensors.hazards()) do
      if ecology.role(h) then
        local dx, dz = h.x - p.x, h.z - p.z
        local dist = math.sqrt(dx * dx + dz * dz)
        if dist < ecology.STUN.range and (dist < 1 or (dx * fx + dz * fz) / dist > ecology.STUN.cone) then
          h.stunned = sim.tick + ecology.STUN.time / sim.dt
        end
      end
    end
    sim.emit("stun", { position = { p.x, p.y + 1.5, p.z }, strength = 0.7 })
  end)
end

-- A hazard's part in the ecology: "grazer", "predator" (every predator, the lone ones of the hazard table too), or nil.
function ecology.role(h) return (h.kind == "grazer" or h.kind == "predator") and h.kind or nil end

local function toward(h, x, z, speed, dt)
  local dx, dz = x - h.x, z - h.z
  local d = math.sqrt(dx * dx + dz * dz)
  if d < 1e-6 then return 0 end
  local step = math.min(d, speed * dt)
  h.x, h.z = h.x + dx / d * step, h.z + dz / d * step
  h.hx_dir, h.hz_dir = dx / d, dz / d -- (the heading as a direction: no atan in the simulation)
  h.stride = (h.stride or 0) + step
  return d
end

-- Behaviours (every THINK ticks). Returns nothing; bites hurt the suit through survival.hurt.
function ecology.tick(hurt)
  if sim.tick % ecology.THINK ~= 0 then return end
  local s, dt, t = ecology.state(), sim.dt * ecology.THINK, sim.tick * sim.dt
  local keep = {}
  for _, dcy in ipairs(s.decoys) do
    if dcy.until_tick > sim.tick then keep[#keep + 1] = dcy end
  end
  s.decoys = keep
  local key = sensors.state().world
  local species = key and ecology.species_cached(key)
  if not species then return end
  local p, outside = chain.suit(), chain.on_foot()
  local running = outside and (p.wx or 0) * (p.wx or 0) + (p.wz or 0) * (p.wz or 0) > 16
  local list = sensors.hazards()
  for _, h in ipairs(list) do
    local sp = ecology.role(h) and species[h.kind]
    if sp and not (h.stunned and h.stunned > sim.tick) then
      if h.kind == "grazer" then
        local threat
        for _, o in ipairs(list) do
          local dx, dz = o.x - h.x, o.z - h.z
          if o.kind == "predator" and dx * dx + dz * dz < 900 then threat = o end
        end
        if threat then toward(h, 2 * h.x - threat.x, 2 * h.z - threat.z, sp.speed * 1.5, dt) -- away from it
        else
          local a = h.phase + t * 0.03
          toward(h, h.hx + 15 * fk.math.cos(a) + 3 * (h.member or 0), h.hz + 15 * fk.math.sin(a), sp.speed * 0.3, dt)
        end
      else
        local decoy
        for _, dcy in ipairs(s.decoys) do
          local dx, dz = dcy.x - h.x, dcy.z - h.z
          if dx * dx + dz * dz < ecology.DECOY.range * ecology.DECOY.range then decoy = dcy end
        end
        local dx, dz = p.x - h.x, p.z - h.z
        local dist = math.sqrt(dx * dx + dz * dz)
        local notice = h.alerted and ecology.NOTICE.pinged or running and ecology.NOTICE.run or ecology.NOTICE.walk
        if decoy then
          h.hunting = nil
          toward(h, decoy.x, decoy.z, sp.speed * 1.6, dt)
        elseif outside and (h.hunting or dist < notice) then
          if not h.hunting then sim.emit("noticed", { position = { h.x, chain.ground(h.x, h.z), h.z }, id = h.id, strength = 0.6 }) end
          h.hunting = true
          if toward(h, p.x, p.z, sp.speed * 1.6, dt) <= ecology.BITE and sim.tick >= (h.bite_at or 0) then
            h.bite_at = sim.tick + 1 / sim.dt
            hurt(0.12)
            sim.emit("bite", { position = { p.x, p.y + 1.2, p.z }, strength = 0.9 })
          end
        else
          h.hunting = nil
          local a = h.phase + t * 0.05
          toward(h, h.hx + 40 * fk.math.cos(a), h.hz + 40 * fk.math.sin(a), sp.speed * 0.4, dt)
        end
      end
    end
  end
end

local cache = {}
function ecology.species_cached(key)
  cache[key] = cache[key] or ecology.species(key)
  return cache[key]
end

-- Draws the creatures near eye (presentation): a body, a head on a neck, a tail, and legs that swing with the
-- distance walked (a gait per leg count: pairs in turn), the body bobbing with the steps.
function ecology.draw(state, eye, now)
  local key = sensors.state().world
  if not key then return 0 end
  local species, mat4, hull = ecology.species_cached(key), require("mat4"), require("dolls.hull")
  state.meshes = state.meshes or {}
  local n = 0
  for _, h in ipairs(sensors.hazards()) do
    local sp = ecology.role(h) and species[h.kind]
    local dx, dz = h.x - eye[1], h.z - eye[3]
    if sp and dx * dx + dz * dz < 300 * 300 then
      local id = key .. h.kind
      if not state.meshes[id] then
        local L, H, c = sp.length, sp.height, sp.color
        local dark = { c[1] * 0.5, c[2] * 0.5, c[3] * 0.5 }
        state.meshes[id] = {
          body = fk.gfx.mesh(hull.build({
            { "box", at = { 0, 0, 0 }, size = { L * 0.35, H * 0.35, L }, color = c },
            { "box", at = { 0, H * (0.15 + sp.neck * 0.3), L * 0.55 }, size = { L * 0.2, H * 0.22, L * 0.3 }, color = c },
            { "box", at = { 0.07 * L, H * (0.2 + sp.neck * 0.3), L * 0.7 }, size = { L * 0.04, L * 0.04, L * 0.02 },
              color = h.kind == "predator" and { 1, 0.2, 0.1 } or { 0.1, 0.1, 0.1 }, mirror = true },
            { "box", at = { 0, H * 0.05, -L * (0.5 + sp.tail * 0.4) }, size = { L * 0.08, L * 0.08, L * sp.tail }, color = dark },
          }, 1)),
          leg = fk.gfx.mesh(hull.build({ { "box", at = { 0, -H * 0.3, 0 }, size = { L * 0.09, H * 0.6, L * 0.09 }, color = dark } }, 1)),
        }
      end
      local m = state.meshes[id]
      local ground = chain.ground(h.x, h.z)
      local phase = (h.stride or 0) / sp.stride * 2 * math.pi
      local hip = sp.height * 0.6
      local yaw = h.hx_dir and math.atan(h.hx_dir, h.hz_dir) or h.phase -- (presentation)
      local base = mat4.multiply(mat4.translation(h.x, ground + hip + math.abs(math.sin(phase)) * sp.height * 0.04, h.z),
        mat4.rotation_y(yaw))
      local stunned = h.stunned and h.stunned > sim.tick
      if stunned then base = mat4.multiply(base, mat4.rotation_z(0.6)) end -- (keeled over)
      fk.gfx.draw(m.body, base, { roughness = 0.8 })
      local pairs_n = sp.legs // 2
      for i = 0, sp.legs - 1 do
        local side, row = i % 2 == 0 and 1 or -1, i // 2
        local z = pairs_n > 1 and sp.length * (0.35 - 0.7 * row / (pairs_n - 1)) or 0
        local swing = stunned and 0 or math.sin(phase + (row + (side > 0 and 0 or 1)) * math.pi) * 0.5
        local leg = mat4.multiply(base, mat4.multiply(mat4.translation(side * sp.length * 0.17, 0, z), mat4.rotation_x(swing)))
        fk.gfx.draw(m.leg, leg, { roughness = 0.8 })
      end
      n = n + 1
    end
  end
  for _, dcy in ipairs(ecology.state().decoys) do -- the decoys: a burning flare
    fk.gfx.light({ position = { dcy.x, chain.ground(dcy.x, dcy.z) + 1, dcy.z }, color = { 1, 0.35, 0.15 },
      intensity = 40 * (0.8 + 0.2 * math.sin(now * 30)), radius = 40 })
  end
  return n
end

return ecology
