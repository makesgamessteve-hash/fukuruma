-- ship_ai.lua and the chain's deploy easing (doll-chain presentation).
local ship_ai = require("ship_ai")
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local chain = require("chain")

return {
  ["the ship AI names what the chain does"] = function()
    local kind = function(id) return id == 7 and "space_station" or nil end
    assert(ship_ai.line("deploy", { kind = "walker" }, kind) == "EXPLORATION WALKER DEPLOYED.")
    assert(ship_ai.line("recall", { kind = "exosuit" }, kind):find("RECOVERED", 1, true))
    assert(ship_ai.line("board", { kind = "walker" }, kind):find("WELCOME ABOARD", 1, true))
    assert(ship_ai.line("teleport", { kind = "jump_ship" }, kind) == "TELEPORT COMPLETE. JUMP SHIP.")
    assert(ship_ai.line("autopilot", { id = 7 }, kind) == "AUTOPILOT ENGAGED: SPACE STATION.")
    assert(ship_ai.line("arrived", { id = 99 }, kind) == "AUTOPILOT: ARRIVED AT THE TARGET.")
    assert(ship_ai.line("deploy", { kind = "nope" }, kind) == "UNKNOWN DEPLOYED.")
    assert(ship_ai.line("scan", {}, kind) == nil)
    local state = { text = "HELLO", ["until"] = 5 }
    assert(ship_ai.draw(state, 4, 480, 270) and not ship_ai.draw(state, 6, 480, 270) and not ship_ai.draw({}, 0, 480, 270))
  end,
  ["the cabin sways with the doll, and flying dolls' engines are heard"] = function()
    local state, d = {}, { id = 1, kind = "continental_explorer", yaw = 0, speed = 0 }
    assert(chain.sway(state, d, 1 / 60) == 0, "the first frame: still")
    d.yaw, d.speed = 0.01, 2
    local roll, pitch
    for _ = 1, 60 do roll, pitch = chain.sway(state, d, 1 / 60) d.yaw = d.yaw + 0.01 end
    assert(roll > 0.1 and pitch < 0, "banks into the turn, leans back as it speeds up: " .. roll .. ", " .. pitch)
    assert(chain.engine(d) > 0.25 and chain.engine({ kind = "walker" }) == 0 and chain.engine({ kind = "jump_ship" }) == 0)
    local station = { id = 2, kind = "space_station", yaw = 0, speed = 0 }
    chain.sway(state, station, 1 / 60)
    station.yaw = 1
    assert(math.abs(select(1, chain.sway(state, station, 1 / 60))) < roll, "a station does not sway")
  end,
  ["a deployed doll eases out of its parent"] = function()
    sim.reset()
    actions.reset()
    game.init()
    sim.step(game)
    local state = {}
    chain.draw(state, { 0, 2, 0 }, 0)
    sim.send("board", { id = chain.up() })
    sim.step(game)
    sim.send("board", { id = chain.up() })
    sim.step(game)
    sim.send("deploy", { kind = "walker" })
    sim.step(game)
    local new = chain.state().dolls[#chain.state().dolls]
    chain.draw(state, { 0, 2, 0 }, 10)
    assert(state.emerging[new.id].from, "it starts at its parent")
    chain.draw(state, { 0, 2, 0 }, 10 + chain.EMERGE)
    assert(chain.draw(state, { 0, 2, 0 }, 11) > 0)
  end,
}
