-- sensors.lua (sensor-system spec): signatures, suites, passive and active scans, ageing contacts, hazard stops.
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local dolls = require("dolls")
local chain = require("chain")
local sensors = require("sensors")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  sim.step(game)
end

local function step(n)
  for _ = 1, n or 1 do sim.step(game) end
end

return {
  ["every doll has a suite, and each world its own hazards from its seed"] = function()
    for _, def in ipairs(dolls.list) do
      assert(def.sensors and def.sensors.range > 0 and def.sensors.resolution > 0, def.id)
    end
    start()
    local list = sensors.hazards()
    assert(#list == sensors.COUNT, "made on the first tick")
    for _, h in ipairs(list) do
      local r = math.sqrt(h.hx * h.hx + h.hz * h.hz)
      assert(sensors.HAZARDS[h.kind] and r >= sensors.CLEAR - 1e-6 and r <= sensors.HAZARD_RANGE + 1e-6)
    end
    local first = list[1]
    start()
    assert(sensors.hazards()[1].hx == first.hx and sensors.hazards()[1].kind == first.kind, "the same every time")
    sensors.tick("another/world")
    assert(sensors.hazards() ~= list and #sensors.hazards() == sensors.COUNT, "another world, other hazards")
  end,
  ["what a suite sees: kind, size, range, stealth, and a ping"] = function()
    local walker, suit = dolls.by_id.walker.sensors, dolls.by_id.exosuit.sensors
    local gas = { kind = "gas_pocket", size = 0.2 }
    assert(not sensors.sees(walker, gas, 10, false) and not sensors.sees(walker, gas, 10, true), "not a kind it covers")
    assert(sensors.sees(suit, gas, 100, false) and not sensors.sees(suit, gas, 200, false) and sensors.sees(suit, gas, 290, true))
    local small = { kind = "predator", size = 0.4 }
    assert(not sensors.sees(walker, small, 10, false) and sensors.sees(walker, small, 10, true), "a ping resolves half as small")
    local hole = { kind = "sinkhole", size = 30 }
    assert(not sensors.sees(walker, hole, 1500, false) and sensors.sees(walker, hole, 1100, false), "stealth shortens it")
  end,
  ["contacts age; pings wake hostiles; roamers roam"] = function()
    start()
    local suit = chain.current()
    local p = sensors.place("predator", suit.x + 200, suit.z, 3) -- (it roams 60 m about there)
    local gas = sensors.place("gas_pocket", suit.x + 20, suit.z, 0.1)
    step(sensors.PASSIVE)
    local list = sensors.contacts(suit.x, suit.z)
    assert(list[1].id == gas.id and not list[1].stale, "the gas, fresh and nearest")
    assert(sensors.label(list[1]):find("GAS POCKET 20 M", 1, true))
    for _, c in ipairs(list) do assert(c.id ~= p.id, "the predator is out of passive range") end
    sim.send("scan", {})
    step()
    assert(p.alerted and sensors.state().contacts["h" .. p.id], "the ping saw it, and it heard")
    local x = p.x
    step(60)
    assert(p.x ~= x, "it moves")
    sensors.state().contacts["h" .. gas.id].tick = sim.tick - (sensors.STALE + 5) / sim.dt
    local c
    for _, o in ipairs(sensors.contacts(suit.x, suit.z)) do
      if o.id == gas.id then c = o end
    end
    assert(c.stale and sensors.label(c):find("S AGO", 1, true), "old data shows its age")
    assert(sensors.screen(suit)[2]:find("1 OLD", 1, true))
    local far = { kind = "vent", dist = 2500, age = 0 }
    assert(sensors.label(far) == "HOT VENT 2.5 KM")
  end,
  ["the autopilot stops for a known hazard in its way"] = function()
    start()
    local walker
    for _, d in ipairs(chain.state().dolls) do
      if d.kind == "walker" then walker = d end
    end
    walker.yaw = 0
    local h = sensors.place("sinkhole", walker.x, walker.z + 150, 40)
    assert(sensors.ahead(walker) == nil, "not yet seen")
    sensors.scan(walker, false)
    assert(sensors.ahead(walker).id == h.id)
    walker.yaw = math.pi
    assert(sensors.ahead(walker) == nil, "behind it")
    walker.yaw = 0
    sim.send("board", { id = walker.id })
    step()
    sim.send("autopilot", { id = walker.parent })
    step(2)
    assert(walker.auto == nil, "stopped at once")
    assert(chain.screens()[8][1] == "SENSORS")
  end,
}
