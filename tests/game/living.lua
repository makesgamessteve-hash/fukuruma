-- living-interiors, room-streaming and detailed-cockpits specs: the Walker's detailed cab; inside, its galley,
-- quarters, bath, med bay and engine room, each with its furniture and what it is for (a meal in the galley, a
-- night in the quarters, an overhaul in the engine room); the Continental Explorer's biotope and its harvest. The rooms
-- stream in around the Commander.
local sim = require("fk.sim")

local function press(t, key, frames)
  t.key(key, true); t.frames(1)
  t.key(key, false); t.frames(frames or 1)
end

return scenario {
  seed = 1,
  timeout_s = 180,
  run = function(t)
    local game = require("game")
    local chain = require("chain")
    local interior = require("interior")
    local living = require("living")
    t.frames(5)
    press(t, "F", 2) -- into the Walker
    local w = chain.walking()
    local walker = chain.find(w.doll)
    local layout = interior.layout("walker")
    local seat
    for _, f in ipairs(layout.fixtures) do
      if f[1] == "seat" then seat = f end
    end
    w.x, w.z = seat[2], seat[3] -- shortcut: at the seat without the walk
    t.frames(2)
    press(t, "F", 3)
    t.expect(not chain.walking(), "at the Walker's controls")
    game.helmet.yaw, game.helmet.pitch = 0.5, -0.15
    t.frames(3)
    t.screenshot("living_cockpit")
    press(t, "F", 2)
    -- Each room seen from just inside its door, then used.
    local function visit(kind, room_type, shot)
      local l = interior.layout(kind)
      for _, r in ipairs(l.rooms) do
        if r.type == room_type then
          w = chain.walking()
          w.x, w.z = r.door.x + r.side * 1.6, r.door.z
          game.helmet.yaw, game.helmet.pitch = r.side * math.pi / 2, -0.12
          t.frames(12) -- (the rooms stream in, a few a frame)
          t.screenshot(shot)
          return r
        end
      end
    end
    local s = living.state()
    s.hunger, s.fatigue = 0.9, 0.95
    visit("walker", "galley", "living_galley")
    local function use(fixture)
      for _, f in ipairs(interior.layout(chain.walk_kind(chain.walking())).fixtures) do
        if f[1] == fixture then
          chain.walking().x, chain.walking().z = f[2], f[3]
          t.frames(1)
          local hint = chain.use_hint()
          press(t, "F", 2)
          return hint
        end
      end
    end
    t.expect(use("eat") == "EAT" and s.hunger < 0.01, "a meal in the galley")
    visit("walker", "quarters", "living_quarters")
    t.expect(use("sleep") == "SLEEP" and s.fatigue < 0.01, "a night in the quarters")
    visit("walker", "bath", "living_bath")
    visit("walker", "med bay", "living_med_bay")
    walker.wear = 0.7
    visit("walker", "engine room", "living_engine_room")
    t.expect(use("maintain"):find("OVERHAUL", 1, true) and walker.wear < 0.01, "an overhaul in the engine room")
    -- The Continental Explorer's biotope.
    local ce
    for _, d in ipairs(chain.state().dolls) do
      if d.kind == "continental_explorer" then ce = d end
    end
    chain.state().at, chain.state().walk = ce.id, { doll = ce.id, x = 0, z = 1 }
    ce.crop = 1
    local r = visit("continental_explorer", "biotope", "living_biotope")
    t.expect(r and r.height > interior.HEIGHT, "the biotope is tall")
    t.expect(use("harvest") == "HARVEST" and require("economy").state().items.food == living.HARVEST, "the harvest")
    local loaded = 0
    for _ in pairs(game.room_cache.continental_explorer) do loaded = loaded + 1 end
    t.expect(loaded > 0 and loaded < #interior.layout("continental_explorer").rooms, "only the near rooms are built: " .. loaded)
    print("living state hash " .. sim.hash())
  end,
}
