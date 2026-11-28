-- Artifact sites (artifact-sites spec). Each world has the ruin of a dead civilisation, placed from the seed (a named
-- stream): broken pillars around three pylons, an exotic signature the right sensors see from afar. The pylons must be
-- woken in an order the ruin hints at: each pylon shows as many glyphs as its place in the order. Woken in the right
-- order, the ruin gives up its artifact (into the codex); a wrong one resets the puzzle and wakes its guardian, whose
-- pulses hurt the suit near the ruin for a while.
local sim = require("fk.sim")
local chain = require("chain")
local sensors = require("sensors")

local artifacts = {}

artifacts.PYLON_RING = 12   -- metres from the ruin's centre
artifacts.REACH = 3         -- metres to touch a pylon
artifacts.GUARD = { range = 40, every = 2, harm = 0.08, time = 12 } -- metres, seconds, integrity, seconds awake

sensors.HAZARDS.ruin = { signature = "exotic", size = { 30, 30 }, stealth = 0, name = "RUIN" }

-- The ruin of world key: {x, z, order = {pylon indexes in the order to wake them}, pylons = {{x, z}}}.
function artifacts.of(key)
  local rng = fk.rng("artifact-site", key)
  local r, a = 1000 + rng:float() * 3000, rng:float() * 2 * math.pi
  local site = { x = r * fk.math.cos(a), z = r * fk.math.sin(a), order = { 1, 2, 3 }, pylons = {} }
  for i = 3, 2, -1 do -- a shuffle from the stream
    local j = rng:range(1, i)
    site.order[i], site.order[j] = site.order[j], site.order[i]
  end
  for i = 1, 3 do
    local b = (i - 1) / 3 * 2 * math.pi + 0.3
    site.pylons[i] = { x = site.x + artifacts.PYLON_RING * fk.math.cos(b), z = site.z + artifacts.PYLON_RING * fk.math.sin(b) }
  end
  return site
end

-- How many glyphs pylon i shows: its place in the order.
function artifacts.glyphs(site, i)
  for k, p in ipairs(site.order) do
    if p == i then return k end
  end
end

function artifacts.state() return sim.get(artifacts.id, "artifacts") end

-- The puzzle's state on world key: {step (pylons woken), solved, guard (tick until which the guardian is awake)}.
function artifacts.progress(key)
  local s = artifacts.state()
  s.sites[key] = s.sites[key] or { step = 0, solved = false, guard = 0 }
  return s.sites[key]
end

function artifacts.populate(key, list, next_id)
  local site = artifacts.of(key)
  list[#list + 1] = { id = next_id(), kind = "ruin", x = site.x, z = site.z, hx = site.x, hz = site.z, size = 30, phase = 0 }
end

local function pylon_near()
  local key = sensors.state().world
  if not key or chain.current().kind ~= "exosuit" then return nil end
  local p, site = chain.suit(), artifacts.of(key)
  for i, py in ipairs(site.pylons) do
    local dx, dz = py.x - p.x, py.z - p.z
    if dx * dx + dz * dz < artifacts.REACH * artifacts.REACH then return i, site, key end
  end
end

-- Wakes pylon i of the ruin on world key.
function artifacts.wake(i, site, key)
  local pr = artifacts.progress(key)
  if pr.solved then return end
  local at = { site.pylons[i].x, chain.ground(site.pylons[i].x, site.pylons[i].z) + 2, site.pylons[i].z }
  if site.order[pr.step + 1] == i then
    pr.step = pr.step + 1
    sim.emit("pylon", { position = at, strength = 0.5 })
    if pr.step == #site.order then
      pr.solved = true
      sim.emit("artifact", { position = { site.x, chain.ground(site.x, site.z) + 2, site.z }, strength = 1 })
    end
  else
    pr.step, pr.guard = 0, sim.tick + artifacts.GUARD.time / sim.dt
    sim.emit("guardian", { position = { site.x, chain.ground(site.x, site.z) + 6, site.z }, strength = 1 })
  end
end

function artifacts.install()
  artifacts.id = sim.create()
  sim.set(artifacts.id, "artifacts", { sites = {} })
  local present = false
  for _, f in ipairs(sensors.world_hooks) do present = present or f == artifacts.populate end
  if not present then sensors.world_hooks[#sensors.world_hooks + 1] = artifacts.populate end
  local hint = function()
    local i, _, key = pylon_near()
    if not i or artifacts.progress(key).solved then return nil end
    return "TOUCH THE PYLON"
  end
  chain.hands[#chain.hands + 1] = { hint = hint, act = function()
    local i, site, key = pylon_near()
    if i then artifacts.wake(i, site, key) end
  end }
end

-- Each tick: an awake guardian pulses at the suit near its ruin.
function artifacts.tick(hurt)
  local key = sensors.state().world
  if not key then return end
  local pr = artifacts.progress(key)
  if pr.guard <= sim.tick or (pr.guard - sim.tick) % math.floor(artifacts.GUARD.every / sim.dt) ~= 0 then return end
  local site, p = artifacts.of(key), chain.suit()
  local dx, dz = site.x - p.x, site.z - p.z
  if chain.on_foot() and dx * dx + dz * dz < artifacts.GUARD.range * artifacts.GUARD.range then
    hurt(artifacts.GUARD.harm)
    sim.emit("guardian", { position = { site.x, chain.ground(site.x, site.z) + 6, site.z }, strength = 0.7 })
  end
end

-- Draws the ruin near eye: pillars, the pylons with their glyphs (lit once woken), the guardian's eye (presentation).
function artifacts.draw(state, eye, now)
  local key = sensors.state().world
  if not key then return 0 end
  local site = artifacts.of(key)
  local dx, dz = site.x - eye[1], site.z - eye[3]
  if dx * dx + dz * dz > 2000 * 2000 then return 0 end
  local hull, mat4 = require("dolls.hull"), require("mat4")
  local stone, dark = { 0.42, 0.44, 0.48 }, { 0.2, 0.21, 0.24 }
  if state.key ~= key then
    local parts = {}
    for i = 1, 10 do
      local a = i / 10 * 2 * math.pi
      local h = 3 + (i * 37 % 7)
      parts[#parts + 1] = { "box", at = { 24 * math.cos(a), h / 2, 24 * math.sin(a) }, size = { 2, h, 2 }, color = stone }
    end
    parts[#parts + 1] = { "box", at = { 0, 0.25, 0 }, size = { 30, 0.5, 30 }, color = dark }
    state.key, state.ruin = key, fk.gfx.mesh(hull.build(parts, 1))
    state.pylon = fk.gfx.mesh(hull.build({ { "box", at = { 0, 2, 0 }, size = { 1.2, 4, 1.2 }, color = dark } }, 1))
    state.glyph = fk.gfx.mesh(hull.build({ { "box", at = { 0, 0, 0 }, size = { 0.5, 0.25, 0.1 }, color = { 0.3, 0.9, 1 } } }, 1))
  end
  local y = chain.ground(site.x, site.z)
  fk.gfx.draw(state.ruin, mat4.translation(site.x, y - 0.2, site.z), { roughness = 0.9 })
  local pr = artifacts.progress(key)
  for i, py in ipairs(site.pylons) do
    local py_y = chain.ground(py.x, py.z)
    fk.gfx.draw(state.pylon, mat4.translation(py.x, py_y, py.z), { roughness = 0.6, metalness = 0.5 })
    local lit = pr.solved or artifacts.glyphs(site, i) <= pr.step
    for g = 1, artifacts.glyphs(site, i) do
      fk.gfx.draw(state.glyph, mat4.translation(py.x, py_y + 1 + g * 0.6, py.z + 0.62),
        { emission = lit and { 3, 6, 8 } or { 0.3, 0.6, 0.8 }, emissive_colors = true })
    end
  end
  if pr.guard > sim.tick then
    fk.gfx.light({ position = { site.x, y + 6, site.z }, color = { 1, 0.2, 0.15 }, intensity = 60 * (0.7 + 0.3 * math.sin(now * 8)), radius = 45 })
  end
  return 1
end

return artifacts
