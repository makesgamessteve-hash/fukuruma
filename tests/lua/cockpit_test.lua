-- dolls/cockpit.lua (cockpits spec): the cabins around the seats, their screens, and how far the head turns.
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local dolls = require("dolls")
local cockpit = require("dolls.cockpit")
local chain = require("chain")
local mat4 = require("mat4")

return {
  ["every doll but the Exosuit has a cabin with its screens"] = function()
    for _, d in ipairs(dolls.list) do
      if d.id == "exosuit" then assert(cockpit.build({}, d) == nil, "steered on foot")
      else
        local parts, screens, spots = cockpit.parts(d.cockpit)
        assert(#parts > 10 and #screens == d.cockpit.screens and #spots == #screens, d.id)
        local built = cockpit.build({}, d)
        assert(built.shell and built.screens and #built.spots == d.cockpit.screens, d.id)
      end
    end
  end,
  ["far from the range, positions are drawn about a floating origin"] = function()
    assert(not pcall(fk.gfx.origin, 0 / 0, 0, 0) and not pcall(fk.gfx.origin, 1, math.huge, 0))
    fk.gfx.origin(4096, 3.0e7, 0)
    local c = cockpit.build({}, dolls.by_id.jump_ship)
    fk.gfx.draw(c.shell, { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 4100, 3.0e7, 2, 1 })
    fk.gfx.light({ position = { 4100, 3.0e7, 0 }, color = { 1, 1, 1 }, intensity = 1, radius = 5 })
    fk.gfx.camera(mat4.identity(), mat4.perspective(1, 1, 0.1, 100))
    assert(not pcall(fk.gfx.draw, c.shell, { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0 / 0, 0, 0, 1 }), "not finite")
    fk.gfx.origin(0, 0, 0)
  end,
  ["screens show what the doll knows, where they appear and as much as fits"] = function()
    sim.reset()
    actions.reset()
    game.init()
    sim.step(game)
    sim.send("board", { id = chain.up() })
    sim.step(game)
    local lines = chain.screens()
    assert(lines[1][1] == "EXPLORATION WALKER" and lines[2][2] == "EMPTY" and lines[3][2]:find("LAND EXPLORER", 1, true))
    assert(#lines == 8 and lines[8][1] == "SENSORS", "the sensor screen (sensors.lua)")
    local c = cockpit.build({}, dolls.by_id.walker)
    local eye = { 0, 0, 0 }
    local projection = mat4.perspective(math.rad(70), 16 / 9, 0.1, 1000)
    local ahead = { -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1 } -- looking along +z
    assert(cockpit.text(c, eye, lines, ahead, projection, 480, 270, { 1, 1, 1 }) == 3, "all three screens in view")
    assert(cockpit.text(c, eye, lines, mat4.identity(), projection, 480, 270, { 1, 1, 1 }) == 0, "behind: none")
    assert(cockpit.text(c, eye, lines, ahead, projection, 24, 14, { 1, 1, 1 }) == 0, "too small to read")
    assert(cockpit.text(nil, eye, lines, ahead, projection, 480, 270, { 1, 1, 1 }) == 0)
    assert(cockpit.project({ 0, 0, -5 }, ahead, projection, 480, 270) == nil, "behind the eye")
    -- in the seat the head turns only so far from the doll's front
    game.helmet.yaw = 3
    game.input()
    assert(math.abs(game.helmet.yaw) <= cockpit.LOOK + 1e-9)
  end,
}
