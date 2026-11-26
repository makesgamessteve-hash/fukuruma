-- fk/frames.lua (reference-frames spec).
local frames = require("fk.frames")
local sim = require("fk.sim")

local AU = 1.495978707e11
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end
local function near3(a, b, eps) return near(a[1], b[1], eps) and near(a[2], b[2], eps) and near(a[3], b[3], eps) end
local QUARTER_Y = { 0, math.sqrt(0.5), 0, math.sqrt(0.5) } -- a quarter turn about +y: +x becomes -z

local function fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(text, 1, true), "expected an error with '" .. text .. "', got " .. tostring(err))
end

return {
  ["points move between frames through their common ancestor"] = function()
    sim.reset()
    local system = frames.create()
    local planet = frames.create(system, { position = { 1000, 0, 0 }, rotation = QUARTER_Y })
    local ship = frames.create(planet, { position = { 0, 10, 0 } })
    local other = frames.create(system, { position = { 0, 0, 500 } })
    assert(frames.parent(ship) == planet and frames.parent(system) == nil)
    local p = frames.convert(ship, { 1, 0, 0 }, system)
    assert(near3(p, { 1000, 10, -1 }), "rotated by the planet, then moved")
    p = frames.convert(ship, { 1, 0, 0 }, other)
    assert(near3(p, { 1000, 10, -501 }), "across the tree")
    local back = frames.convert(other, p, ship)
    assert(near3(back, { 1, 0, 0 }), "and back")
    assert(near3(frames.convert(ship, { 2, 3, 4 }, ship), { 2, 3, 4 }), "the same frame changes nothing")
    local q = frames.convert_rotation(ship, frames.IDENTITY, system)
    assert(near3(frames.rotate(q, { 1, 0, 0 }), { 0, 0, -1 }, 1e-12), "orientations follow the frames")
    assert(near3(frames.rotate(frames.convert_rotation(system, q, ship), { 1, 0, 0 }), { 1, 0, 0 }, 1e-12))
    fails(function() frames.convert(ship, { 0, 0, 0 }, frames.create()) end, "are in different trees")
    fails(function() frames.parent(sim.create()) end, "is not a frame")
    fails(function() frames.create(sim.create()) end, "the parent is not a frame")
  end,
  ["velocities include the frames' motion and spin"] = function()
    sim.reset()
    local system = frames.create()
    local moving = frames.create(system, { velocity = { 5, 0, 0 } })
    local _, v = frames.convert(moving, { 0, 0, 0 }, system, { 0, 1, 0 })
    assert(near3(v, { 5, 1, 0 }), "the frame's velocity adds")
    local spinning = frames.create(system, { spin = { 0, 1, 0 } }) -- 1 rad/s about +y
    _, v = frames.convert(spinning, { 10, 0, 0 }, system)
    assert(near3(v, { 0, 0, -10 }), "a point at rest on a spinning frame moves")
    local _, rest = frames.convert(system, { 10, 0, 0 }, spinning, { 0, 0, -10 })
    assert(near3(rest, { 0, 0, 0 }), "and is at rest in it")
  end,
  ["a frame transition keeps the world position and velocity"] = function()
    sim.reset()
    local system = frames.create()
    local planet = frames.create(system, { position = { 1e9, 0, 0 }, velocity = { 0, 0, 3e4 }, rotation = QUARTER_Y })
    local ship = sim.create()
    sim.set(ship, "place", { frame = system, p = { 1e9 + 7e6, 0, 0 }, v = { 0, 0, 3e4 + 7500 }, q = frames.IDENTITY })
    frames.reparent(ship, planet)
    local place = sim.get(ship, "place")
    assert(place.frame == planet)
    assert(near3(place.p, { 0, 0, 7e6 }, 1e-6) and near3(place.v, { -7500, 0, 0 }, 1e-9), "orbiting the planet")
    local p, v = frames.convert(planet, place.p, system, place.v)
    assert(near3(p, { 1e9 + 7e6, 0, 0 }, 1e-6) and near3(v, { 0, 0, 3e4 + 7500 }, 1e-9), "the same in the world")
    frames.place(planet, { 2e9, 0, 0 })
    assert(near(frames.convert(planet, place.p, system)[1], 2e9 + 7e6, 1e-6), "the ship moves with its frame")
    local plain = sim.create()
    sim.set(plain, "place", { frame = system, p = { 0, 0, 0 }, v = { 0, 0, 0 } })
    frames.reparent(plain, planet)
    assert(sim.get(plain, "place").q, "an orientation is added")
    fails(function() frames.reparent(sim.create(), planet) end, "the entity has no place")
  end,
  ["the camera sees a thing at 100 AU without jitter"] = function()
    sim.reset()
    local system = frames.create()
    local station = frames.create(system, { position = { 100 * AU, 0, 0 } })
    -- The camera creeps along in 0.1 mm steps next to a cube; its relative position must follow each step.
    local worst = 0
    for i = 0, 100 do
      local viewer = frames.viewer(station, { i * 1e-4, 1.5, -3 })
      local rel = viewer:relative(station, { 0.5, 1, 0 })
      worst = math.max(worst, math.abs(rel[1] - (0.5 - i * 1e-4)), math.abs(rel[2] + 0.5), math.abs(rel[3] - 3))
    end
    assert(worst < 1e-9, "error " .. worst)
    -- Seen from a camera in the system frame, the same cube keeps doubles' precision at 100 AU (about 2 mm).
    local far = frames.viewer(system, { 100 * AU - 3, 0, 0 })
    assert(math.abs(far:relative(station, { 0.5, 0, 0 })[1] - 3.5) < 4e-3)
  end,
  ["scaled space keeps the angular size"] = function()
    local slice, at, s = frames.place_in_slices({ 0, 0, -3 }, 0.5)
    assert(slice == "local" and at[3] == -3 and s == 1)
    slice, at, s = frames.place_in_slices({ 0, 0, -2.5e5 }, 7.2e4)
    assert(slice == "planetary" and s == 1, "a 144 km hull at 250 km")
    slice, at, s = frames.place_in_slices({ 0, 0, -1.5e11 }, 7e8)
    assert(slice == "celestial" and near(at[3], -frames.SCALED_DISTANCE, 1e-3), "a star at 1 AU")
    assert(near(7e8 * s / frames.SCALED_DISTANCE, 7e8 / 1.5e11, 1e-15), "same angular size")
    local viewer = frames.viewer(frames.create(), { 0, 0, 0 })
    local m, sl = viewer:draw_args(viewer.frame, { 0, 0, -2 }, nil, 1, 2)
    assert(sl == "local" and m[1] == 2 and m[15] == -2, "scale and position")
    local matrix = frames.matrix(QUARTER_Y, { 1, 2, 3 }, 1)
    assert(near(matrix[3], -1, 1e-12) and matrix[13] == 1, "rotation and translation columns")
  end,
}
