-- living.lua, interior.plan and interior.stream (living-interiors and room-streaming specs): the rooms every doll
-- has, what their fixtures do, needs, wear and crops, and rooms built and let go around the Commander.
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local dolls = require("dolls")
local chain = require("chain")
local interior = require("interior")
local living = require("living")
local survival = require("survival")
local economy = require("economy")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  sim.step(game)
end

local function step(n)
  for _ = 1, n or 1 do sim.step(game) end
end

local function types(kind)
  local out = {}
  for _, r in ipairs(interior.layout(kind).rooms) do
    if r.type then out[r.type] = (out[r.type] or 0) + 1 end
  end
  return out
end

-- Walks the Commander (aboard the Walker, standing on its bridge) to the fixture of kind name and uses it.
local function use_at(name)
  local w = chain.state().walk
  for _, f in ipairs(interior.layout(chain.walk_kind(w)).fixtures) do
    if f[1] == name then
      w.x, w.z = f[2], f[3]
      local hint = chain.use_hint()
      sim.send("use", {})
      step()
      return hint
    end
  end
  error("no " .. name)
end

local function aboard(kind)
  start()
  local d
  for _, o in ipairs(chain.state().dolls) do
    if o.kind == kind then d = o end
  end
  chain.state().at, chain.state().walk = d.id, { doll = d.id, x = 0, z = 1 }
  return d
end

return {
  ["every doll but the Exosuit has what a crew needs; big ones grow food"] = function()
    for _, def in ipairs(dolls.list) do
      local t = types(def.id)
      if def.id ~= "exosuit" then
        for _, need in ipairs({ "galley", "quarters", "bath", "med bay", "engine room", "cargo deck" }) do
          assert(t[need], def.id .. " has a " .. need)
        end
      end
      assert((t.biotope ~= nil) == (def.size_m >= 6000), def.id .. ": a biotope from six kilometres up")
      assert((t["life support"] ~= nil) == (def.size_m >= 1000 and def.id ~= "exosuit"), def.id)
    end
    assert(types("jump_ship").quarters > types("walker").quarters, "more quarters the bigger the doll")
    local l = interior.layout("jump_ship")
    for i = 1, #l.rooms do -- every room builds, with its furniture and lights where it has a type
      local m, g = interior.room_mesh(l, i, function() return false end)
      assert(#m.indices > 0 and #m.positions == #m.colors and #m.indices % 3 == 0, l.rooms[i].name)
      if l.rooms[i].type == "biotope" or l.rooms[i].type == "engine room" then assert(#g.indices > 0, "lights") end
    end
  end,
  ["rooms stream in near the Commander, a few a frame, and go when far"] = function()
    local l = interior.layout("jump_ship")
    local cache, made = {}, 0
    local function make(m) made = made + 1 return m end -- (counts meshes: a room with lights makes two)
    local closed = function() return false end
    local near = interior.stream(cache, l, 0, 0, closed, make)
    assert(#near == interior.PER_FRAME, "a few a frame")
    for _ = 1, 40 do near = interior.stream(cache, l, 0, 0, closed, make) end
    local loaded = 0
    for i, r in ipairs(l.rooms) do
      if cache[i] then loaded = loaded + 1 end
      assert((cache[i] ~= nil) == (interior.distance(r, 0, 0) <= interior.LOAD or r.docked ~= nil or r.name == "corridor"), r.name)
    end
    assert(loaded < #l.rooms and #near == loaded, "only what is near (and the hangars)")
    local before = made
    interior.stream(cache, l, 0, 0, closed, make)
    assert(made == before, "nothing rebuilt standing still")
    local far = l.length - 5 -- down the corridor: the front rooms go
    for _ = 1, 40 do interior.stream(cache, l, 0, far, closed, make) end
    for i, r in ipairs(l.rooms) do
      if interior.distance(r, 0, far) > interior.UNLOAD and not r.docked and r.name ~= "corridor" then assert(not cache[i], r.name) end
    end
    local door -- a door shutting rebuilds its room
    for i, r in ipairs(l.rooms) do
      if r.door and cache[i] then door = i end
    end
    if door then
      before = made
      interior.stream(cache, l, 0, far, function(name) return name == l.rooms[door].name end, make)
      assert(made > before)
    end
  end,
  ["fixtures: eat, sleep, wash, heal, maintain, harvest"] = function()
    local d = aboard("continental_explorer")
    local s = living.state()
    s.hunger, s.fatigue, s.grime = 0.9, 0.9, 0.9
    survival.state().dose, survival.state().integrity = 5, 0.5
    d.wear, d.air, d.crop = 0.8, 0.7, 0.5
    assert(use_at("eat") == "EAT" and s.hunger < 0.01 and d.stores == living.STORES - 1)
    assert(use_at("sleep") == "SLEEP" and s.fatigue < 0.01)
    assert(use_at("wash") == "WASH" and s.grime < 0.01)
    use_at("heal")
    assert(survival.state().dose == 0 and survival.state().integrity == 1)
    local hints = {}
    for _, f in ipairs(interior.layout("continental_explorer").fixtures) do
      if f[1] == "maintain" then
        chain.state().walk.x, chain.state().walk.z = f[2], f[3]
        hints[#hints + 1] = chain.use_hint()
        sim.send("use", {})
        step()
      end
    end
    assert(#hints == 2 and d.wear < 0.01 and d.air < 0.01, "the engine room and life support")
    assert(use_at("harvest"):find("CROP", 1, true) and (economy.state().items.food or 0) == 0, "not ripe yet")
    d.crop = 1
    assert(use_at("harvest") == "HARVEST" and economy.state().items.food == living.HARVEST and d.crop < 0.01)
    d.stores, s.hunger = 0, 0.5
    assert(use_at("eat") == "EAT" and economy.state().items.food == living.HARVEST - 1, "a ration from the biotope")
    economy.state().items.food = 0
    assert(use_at("eat") == "THE GALLEY IS EMPTY")
    assert(use_at("workbench") == "WORKSHOP" and require("dialogue").open())
  end,
  ["needs rise; a worn-out Commander stops mending; worn engines are slower"] = function()
    local d = aboard("walker")
    local s = living.state()
    step(math.floor(60 / sim.dt))
    assert(s.hunger > 0 and s.fatigue > 0 and s.hunger > s.fatigue, "hunger first")
    assert(#living.warnings() == 0)
    s.hunger, s.fatigue, s.grime = 1, 0.85, 0.9
    local w = living.warnings()
    assert(#w == 3 and w[1]:find("STARVING", 1, true) and w[2] == "TIRED")
    survival.state().integrity = 0.5
    step()
    assert(survival.state().integrity == 0.5, "no mending when starving")
    assert(living.speed_factor({ wear = 0.2 }) == 1 and living.speed_factor({ wear = 1 }) == 0.5)
    d.speed = 1
    step()
    assert(d.wear > 0, "moving wears the engines")
    assert(chain.wear_screen(d)[2]:find("ENGINES", 1, true))
  end,
}
