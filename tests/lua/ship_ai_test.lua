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
