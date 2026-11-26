-- fk.anim poses, fk/anim.lua blend trees and state machines, fk/spring.lua (animation spec).
local anim = require("fk.anim")
local spring = require("fk.spring")

local function fails(fn, pattern)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(pattern, 1, true), tostring(err))
end

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-4) end

local suit = fk.gfx.model("models/exosuit.glb")
local I = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }

local function foot_z(pose, side) return pose:global("foot_" .. side)[15] end

return {
  ["poses sample, blend and report node positions"] = function()
    local pose = fk.anim.pose(suit)
    local hips = pose:global("hips")
    assert(near(hips[14], 1.9), "rest: hips 1.9 m up")
    assert(near(foot_z(pose, "l"), 0) and near(foot_z(pose, "r"), 0), "rest: feet side by side")
    pose:sample("walk", 0.3) -- a quarter cycle: the left foot is forward
    assert(foot_z(pose, "l") > 0.5 and foot_z(pose, "r") < -0.3, foot_z(pose, "l") .. " " .. foot_z(pose, "r"))
    local other = fk.anim.pose(suit):sample("walk", 0.9) -- three quarters: the right foot is forward
    pose:blend(other, 0.5)
    assert(near(foot_z(pose, "l"), foot_z(pose, "r"), 0.05), "halfway between the two strides")
    pose:copy(other)
    assert(foot_z(pose, "r") > 0.5, "copied")
    pose:rest():sample(1, 0.3) -- clips by number too (idle)
    assert(pose:node("antenna") == 6 and pose:node("tail") == nil, "node numbers")
  end,
  ["weights and additive layers"] = function()
    local pose = fk.anim.pose(suit):sample("walk", 0.3)
    local full = foot_z(pose, "l")
    pose:rest():sample("walk", 0.3, 0.5)
    assert(foot_z(pose, "l") > 0.1 and foot_z(pose, "l") < full, "half weight: part of the stride")
    pose:rest():add("walk", 0.3, 1)
    assert(near(foot_z(pose, "l"), full, 0.02), "added to the rest pose: the clip itself")
  end,
  ["rotate turns a node in its own space"] = function()
    local pose = fk.anim.pose(suit)
    local before = pose:global("antenna")
    pose:rotate("antenna", { 1, 0, 0 }, 0.5)
    local after = pose:global("antenna")
    assert(near(before[13], after[13]) and not near(before[10], after[10]), "same place, tilted")
    fails(function() pose:rotate("antenna", { 0, 0, 0 }, 1) end, "the axis must not be zero")
    fails(function() pose:rotate("antenna", { 1, "x", 0 }, 1) end, "the axis must be 3 finite numbers")
  end,
  ["arguments are checked"] = function()
    local pose = fk.anim.pose(suit)
    fails(function() pose:sample("dance", 0) end, "the model has no clip named 'dance'")
    fails(function() pose:sample(9, 0) end, "clip number 9 is out of range (1 to 3)")
    fails(function() pose:sample("walk", 0, 2) end, "the weight must be from 0 to 1")
    fails(function() pose:sample("walk", 0 / 0) end, "must be a finite number")
    fails(function() pose:global("tail") end, "the model has no node named 'tail'")
    fails(function() fk.anim.pose({}) end, "a model from fk.gfx.model")
    local other = fk.anim.pose(fk.gfx.model("models/showcase_materials.glb"))
    fails(function() pose:blend(other, 0.5) end, "a pose of the same model")
    fails(function() pose:copy(other) end, "a pose of the same model")
    fails(function() fk.gfx.draw(suit, I, { pose = other }) end, "the pose belongs to another model")
    fk.gfx.draw(suit, I, { pose = pose })
    fk.gfx.draw(suit, I, {})
  end,
  ["blend trees keep walk and run in step and fire events"] = function()
    local tree = anim.blend1d(suit, {
      { clip = "idle", at = 0 },
      { clip = "walk", at = 2.6, events = { { at = 0.25, name = "step_left" }, { at = 0.75, name = "step_right" } } },
      { clip = "run", at = 6.3, events = { { at = 0.25, name = "step_left" }, { at = 0.75, name = "step_right" } } },
    }, "speed")
    local a, b, w = tree:weights(4.45)
    assert(a == 2 and b == 3 and near(w, 0.5), "between walk and run")
    a, b, w = tree:weights(-1)
    assert(a == 1 and b == 1 and w == 0, "below the first entry")
    a, b, w = tree:weights(9)
    assert(a == 3 and b == 3 and w == 0, "above the last entry")
    local fired, pose = {}, fk.anim.pose(suit)
    for _ = 1, 60 do tree:update(1 / 60, { speed = 2.6 }, fired) end -- 1 s of a 1.2 s walk cycle
    assert(table.concat(fired, ",") == "step_left,step_right", table.concat(fired, ","))
    tree:apply(pose)
    fired = {}
    for _ = 1, 60 do tree:update(1 / 60, { speed = 0 }, fired) end
    assert(#fired == 0, "standing still: no steps")
    tree:update(0.01, { speed = 4.45 }, fired)
    tree:apply(pose) -- blends walk and run
    fails(function() anim.blend1d(suit, { { clip = "fly", at = 0 } }, "speed") end, "no clip named 'fly'")
    fails(function() anim.blend1d(suit, { { clip = "walk", at = 2 }, { clip = "run", at = 1 } }, "speed") end, "sorted")
  end,
  ["state machines switch with crossfades"] = function()
    local tree = anim.blend1d(suit, { { clip = "idle", at = 0 }, { clip = "walk", at = 2.6 } }, "speed")
    local m = anim.machine({
      model = suit,
      start = "move",
      states = { move = { tree = tree }, salute = { clip = "run", next = "move", fade_out = 0.1 }, spin = { clip = "idle" } },
      transitions = { { from = "move", to = "salute", when = function(p) return p.salute end, fade = 0.2 } },
    })
    local pose = fk.anim.pose(suit)
    m:update(0.1, { speed = 1 })
    m:apply(pose)
    m:update(0.1, { speed = 1, salute = true })
    assert(m.current == "salute" and m.previous == "move", "transition starts a crossfade")
    m:apply(pose)
    m:update(0.3, {})
    assert(m.previous == nil, "the crossfade ended")
    m:update(0.5, {})
    assert(m.current == "move", "a clip with 'next' returns when it ends")
    m:set("spin", 0)
    m:set("spin")
    m:update(5, {})
    m:apply(pose) -- a looping single clip
    fails(function() m:set("fly") end, "no state 'fly'")
    fails(function() anim.machine({ model = suit, start = "x", states = {} }) end, "no start state 'x'")
  end,
  ["springs settle on their target"] = function()
    local s = spring.new(2, 1)
    for _ = 1, 120 do s:update(1, 1 / 60) end
    assert(near(s.value, 1, 1e-3), "critically damped: settled after 1 s")
    local wobbly, peak = spring.new(2, 0.2), 0
    for _ = 1, 60 do peak = math.max(peak, wobbly:update(1, 1 / 60)) end
    assert(peak > 1.3, "under-damped: overshoots")
    local kicked = spring.new(3, 0.5, 0)
    kicked:kick(2)
    assert(kicked:update(0, 0.05) > 0, "a kick moves it")
    local slow = spring.new(8, 1)
    assert(near(slow:update(1, 0.5), 1, 1e-3), "a long frame is split into small steps")
  end,
}
