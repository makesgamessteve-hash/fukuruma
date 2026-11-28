-- interior.lua and chain.lua's walking (vessel-interiors spec): layouts, walking, doors and the use command.
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local dolls = require("dolls")
local chain = require("chain")
local interior = require("interior")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  sim.step(game)
end

local function step(n)
  for _ = 1, n or 1 do sim.step(game) end
end

local function find(kind)
  for _, d in ipairs(chain.state().dolls) do
    if d.kind == kind then return d end
  end
end

local function fixture(layout, name, kind)
  for _, f in ipairs(layout.fixtures) do
    if f[1] == name and (not kind or f.kind == kind) then return f end
  end
end

local function use()
  sim.send("use", {})
  step()
end

local open = function() return true end

return {
  ["every doll has rooms: a corridor, its bridge seat, side rooms and a hangar per carried kind"] = function()
    for _, def in ipairs(dolls.list) do
      local l = interior.layout(def.id)
      assert(interior.layout(def.id) == l, "built once")
      assert(fixture(l, "seat") and fixture(l, "exit"), def.id)
      assert(interior.free(l, l.spawn[1], l.spawn[2], open), def.id .. ": the spawn is free")
      assert(interior.free(l, fixture(l, "seat")[2], fixture(l, "seat")[3], open), def.id .. ": the seat is free")
      for k in pairs(def.carries) do
        if k ~= "exosuit" then
          local r = fixture(l, "ramp", k)
          assert(r and interior.free(l, r[2], r[3], open), def.id .. ": a free ramp to " .. k)
        end
      end
      assert((fixture(l, "suit") ~= nil) == (def.carries.exosuit ~= nil), def.id .. ": a suit bay where the suit is carried")
      local mesh = interior.mesh(l, function() return true end)
      assert(#mesh.indices > 0 and #mesh.positions == #mesh.colors and #mesh.indices % 6 == 0)
    end
    assert(fixture(interior.layout("jump_ship"), "clone"), "the Jump Ship's clone bay")
  end,
  ["walking slides along walls and stops at shut doors"] = function()
    local l = interior.layout("walker")
    local w = { x = 0, z = 1 }
    interior.move(l, w, 5, 0, open)
    assert(w.x == 0 and w.z == 1, "a wall stops a step that would leave the corridor")
    interior.move(l, w, 5, 0.5, open)
    assert(w.x == 0 and w.z == 1.5, "the step slides along the wall")
    local suit = fixture(l, "suit")
    w = { x = 1.1, z = suit[3] }
    interior.move(l, w, 0.5, 0, function() return false end)
    assert(w.x == 1.1, "a shut door stops it")
    interior.move(l, w, 0.5, 0, open)
    assert(w.x == 1.6, "into the open doorway")
    local near = interior.near(l, 1.6, suit[3], false)
    assert(near[1] == "door" and near.name == "suit bay")
    assert(interior.near(l, 0, 1, false) == nil, "the exit is only in a docked doll")
    assert(interior.near(l, 0, 1, true)[1] == "exit")
  end,
  ["the Commander goes in through the suit bay, walks, uses a door and takes the controls"] = function()
    start()
    assert(chain.use_hint() == "ENTER THE EXPLORATION WALKER")
    local walker = find("walker")
    use()
    local w = chain.walking()
    assert(w and w.doll == walker.id and chain.current() == walker and walker.hold.exosuit == 1, "in, the suit in the hold")
    assert(not chain.on_foot() and find("exosuit") == nil)
    sim.send("move", { x = -2.6, z = 0, fx = -1, fz = 0 })
    step(30)
    assert(w.x < 5.2 and w.wx < 0, "walking as a human")
    sim.send("move", { x = 0, z = 0, fx = -1, fz = 0 })
    step()
    local l = interior.layout("walker")
    local bay = fixture(l, "suit")
    w.x, w.z = 1.6, bay[3] -- in the doorway
    assert(chain.use_hint() == "CLOSE THE SUIT BAY DOOR")
    use()
    assert(chain.door_open("walker")("suit bay"), "a door does not shut on the Commander")
    w.x = 2.3
    use()
    assert(not chain.door_open("walker")("suit bay") and chain.use_hint() == "OPEN THE SUIT BAY DOOR")
    local snap = sim.snapshot()
    use()
    assert(chain.door_open("walker")("suit bay"))
    sim.restore(snap)
    assert(not chain.door_open("walker")("suit bay"), "the doors are saved")
    walker = find("walker")
    w = chain.walking()
    local seat = fixture(l, "seat")
    w.x, w.z = seat[2], seat[3]
    assert(chain.use_hint() == "TAKE THE CONTROLS")
    local f = chain.interior_frame(walker)
    local p = chain.frame_point(f, l.seat[1], require("dolls.cockpit").EYE, l.seat[2])
    local s = chain.seat(walker)
    assert(math.abs(p[1] - s[1]) < 1e-6 and math.abs(p[2] - s[2]) < 1e-6 and math.abs(p[3] - s[3]) < 1e-6,
      "the bridge seat is the doll's seat")
    assert(chain.frame_matrix(f)[13] == f.x)
    use()
    assert(chain.walking() == nil and chain.current() == walker and chain.use_hint() == "STAND UP")
    use()
    assert(chain.walking(), "up again")
    w = chain.walking()
    w.x, w.z = bay[2], bay[3]
    assert(chain.use_hint() == "SUIT UP AND GO OUT")
    use()
    assert(chain.on_foot() and chain.current().kind == "exosuit" and (walker.hold.exosuit or 0) == 0, "out in the suit")
    chain.state().walk = { doll = walker.id, x = 0, z = 0.5 }
    assert(chain.use_hint() == nil, "nothing in reach")
    use()
    assert(chain.walking().x == 0, "and the hand does nothing")
  end,
  ["up a ramp into a docked doll, down again, and out at its controls"] = function()
    start()
    local ship = find("jump_ship")
    chain.state().at = ship.id
    use()
    local w = chain.walking()
    local l = interior.layout("jump_ship")
    local ramp = fixture(l, "ramp", "drop_ship")
    w.x, w.z = ramp[2], ramp[3]
    assert(chain.use_hint() == "BOARD THE DROP SHIP")
    use()
    w = chain.walking()
    assert(w.docked == "drop_ship" and chain.walk_kind() == "drop_ship", "inside the docked Drop Ship")
    local f, g = chain.interior_frame(ship, "drop_ship"), chain.interior_frame(ship)
    assert(f.x ~= g.x or f.z ~= g.z, "its rooms stand in the hangar")
    assert(chain.use_hint() == "DOWN THE RAMP")
    use()
    w = chain.walking()
    assert(w.docked == nil and math.abs(w.z - (ramp[3] + 1.5)) < 1e-9, "back down in the hangar")
    use()
    w = chain.walking()
    local seat = fixture(interior.layout("drop_ship"), "seat")
    w.x, w.z = seat[2], seat[3]
    assert(chain.use_hint() == "LAUNCH THE DROP SHIP")
    local held = ship.hold.drop_ship
    use()
    assert(chain.walking() == nil and chain.current().kind == "drop_ship" and ship.hold.drop_ship == held - 1,
      "launched, at its controls")
    ship.hold.space_station = 0
    chain.state().at, chain.state().walk = ship.id, { doll = ship.id, x = fixture(l, "ramp", "space_station")[2],
      z = fixture(l, "ramp", "space_station")[3] }
    assert(chain.use_hint() == nil, "an empty hangar has nothing to board")
  end,
}
