-- fk.physics (physics spec): worlds, bodies, characters, stepping, saving, and argument checks.
local function fails(fn, text)
  local ok, err = pcall(fn)
  assert(not ok and tostring(err):find(text, 1, true), "expected '" .. text .. "', got " .. tostring(err))
end

return {
  ["terrain carries bodies and characters"] = function()
    local w = fk.physics.world({ gravity = { 0, -9.81, 0 } })
    local heights = {}
    for j = 0, 8 do
      for i = 0, 8 do heights[#heights + 1] = i > 4 and (i - 4) * 0.5 or 0 end
    end
    w:terrain({ origin = { -4, -4 }, cell = 1, heights = heights, friction = 0.9 })
    local h, nx, ny = w:height(2, 0)
    assert(math.abs(h - 1) < 1e-6 and nx < 0 and ny > 0.8)
    assert(w:height(9, 0) == nil, "outside the terrain")
    local ball = w:add({ shape = "sphere", radius = 0.5, mass = 1, position = { -2, 2, 2.5 } })
    for _ = 1, 120 do w:step(1 / 60) end
    assert(math.abs(w:get(ball).position[2] - 0.5) < 0.05, "it rests on the ground")
    local c = w:character({ radius = 0.4, height = 1.8, position = { -3, 0.9, 0 } })
    local p, grounded
    for _ = 1, 120 do p, grounded = w:move(c, { 0.05, -0.05, 0 }, 1 / 60) end
    assert(grounded and p[2] > 1.5, "it walks up the slope")
    assert(not pcall(w.terrain, w, { heights = { 1, 2, 3 } }), "heights must be square")
    assert(not pcall(w.terrain, w, { heights = 5 }))
    w:terrain(nil)
    assert(w:height(0, 0) == nil)
  end,
  ["bodies fall, land and report the touch"] = function()
    local w = fk.physics.world({ gravity = { 0, -10, 0 } })
    w:add({ shape = "box", size = { 20, 1, 20 }, position = { 0, -0.5, 0 } })
    local ball = w:add({ shape = "sphere", radius = 0.5, mass = 2, position = { 0, 3, 0 }, restitution = 0.2, friction = 0.4 })
    local pill = w:add({ shape = "capsule", radius = 0.3, height = 1.2, mass = 1, position = { 3, 2, 0 }, spin = { 0, 0, 1 },
      rotation = { 0, 0, 0, 1 }, velocity = { 0, 0, 0 }, gravity = { 0, -5, 0 } })
    local hits = 0
    for _ = 1, 120 do hits = hits + #w:step(1 / 60, 1) end
    local b = w:get(ball)
    assert(math.abs(b.position[2] - 0.5) < 0.03 and hits >= 2, "landed with a touch")
    assert(w:get(pill).position[2] < 0.5, "the capsule lies down")
    assert(w:count() == 3 and w:remove(pill) and not w:remove(pill) and w:count() == 2)
    w:set(ball, { position = { 0, 5, 0 }, velocity = { 1, 0, 0 }, rotation = { 0, 0, 0, 1 }, spin = { 0, 0, 0 } })
    assert(not w:get(ball).asleep and w:get(ball).position[2] == 5)
    local k = w:add({ shape = "box", size = { 1, 1, 1 }, kinematic = true, position = { 5, 0.5, 5 }, velocity = { 1, 0, 0 } })
    w:step(1 / 60)
    assert(w:get(k).position[1] > 5, "kinematic bodies move by their velocity")
  end,
  ["characters walk and stand"] = function()
    local w = fk.physics.world()
    w:add({ shape = "box", size = { 20, 1, 20 }, position = { 0, -0.5, 0 } })
    local c = w:character({ radius = 0.4, height = 1.8, position = { 0, 0.9, 0 }, step = 0.3, slope = 45, push = 10, gravity = { 0, -9.81, 0 } })
    local p, grounded
    for _ = 1, 30 do p, grounded = w:move(c, { 0.05, -0.05, 0 }, 1 / 60) end
    assert(grounded and math.abs(p[1] - 1.5) < 1e-4 and math.abs(p[2] - 0.9) < 1e-3)
    assert(w:get(c).grounded)
    local plain = w:character({})
    assert(w:get(plain).position[2] == 0)
  end,
  ["a world saves and restores exactly"] = function()
    local function make()
      local w = fk.physics.world()
      w:add({ shape = "box", size = { 20, 1, 20 }, position = { 0, -0.5, 0 } })
      for i = 1, 4 do w:add({ shape = "box", size = { 1, 1, 1 }, mass = 5, position = { i * 0.3, i * 1.1, 0 } }) end
      return w
    end
    local a = make()
    for _ = 1, 30 do a:step(1 / 60) end
    local saved = a:state()
    local b = fk.physics.world()
    b:restore(saved)
    for _ = 1, 60 do
      a:step(1 / 60)
      b:step(1 / 60)
    end
    for i = 2, 5 do
      local pa, pb = a:get(i).position, b:get(i).position
      assert(pa[1] == pb[1] and pa[2] == pb[2] and pa[3] == pb[3], "body " .. i .. " matches")
    end
    assert(#saved.cache > 0 and math.abs(saved.bodies[2].inv_mass - 0.2) < 1e-6 and saved.next_id == 6)
  end,
  ["arguments are checked"] = function()
    local w = fk.physics.world()
    fails(function() w:add({ shape = "cone" }) end, "invalid option 'cone'")
    fails(function() w:add({ shape = "box" }) end, "a box needs a 'size' above 0")
    fails(function() w:add({ shape = "box", size = { 1, 0, 1 } }) end, "a box needs a 'size' above 0")
    fails(function() w:add({ shape = "sphere" }) end, "'radius' must be above 0")
    fails(function() w:add({ shape = "capsule", radius = 1, height = 1 }) end, "at least twice its radius")
    fails(function() w:add({ shape = "sphere", radius = 1, mass = -1 }) end, "'mass' must not be negative")
    fails(function() w:add({ shape = "sphere", radius = 1, position = { 1, 2 } }) end, "'position' must be a table of 3 numbers")
    fails(function() w:add({ shape = "sphere", radius = 1, friction = "x" }) end, "'friction' must be a finite number")
    fails(function() w:character({ radius = 1, height = 1 }) end, "at least twice its radius")
    local ball = w:add({ shape = "sphere", radius = 1 })
    fails(function() w:get(99) end, "there is no body 99")
    fails(function() w:move(ball, { 0, 0, 0 }, 1) end, "is not a character")
    local c = w:character({})
    fails(function() w:move(c, { 0, "x", 0 }, 1) end, "'move' must be a finite number")
    fails(function() w:restore({}) end, "'next_id' must be an integer")
    fails(function() w:restore({ next_id = 0 }) end, "'next_id' is out of range")
    fails(function() w:restore({ next_id = 5 }) end, "'bodies' must be a table")
    fails(function() w:restore({ next_id = 5, bodies = { 1 } }) end, "body 1 must be a table")
    local good = w:state()
    local bad = w:state()
    bad.bodies[1].kind = 9
    fails(function() w:restore(bad) end, "has a bad id, kind or shape")
    bad = w:state()
    bad.bodies[1].p = nil
    fails(function() w:restore(bad) end, "body 1 needs 'p'")
    bad = w:state()
    bad.bodies[2].id = 1
    fails(function() w:restore(bad) end, "ids must rise")
    bad.bodies[2].id = 99
    fails(function() w:restore(bad) end, "ids must rise")
    bad = w:state()
    bad.cache = nil
    fails(function() w:restore(bad) end, "'cache' must be a table")
    bad.cache = { { 1, 2, 3 } }
    fails(function() w:restore(bad) end, "a cache row must have 6 numbers")
    bad.cache = { { 1, 2, -3, 0, 0, 0 } }
    fails(function() w:restore(bad) end, "a cache row must have 6 numbers")
    assert(w:count() == 2, "a failed restore leaves the world as it was")
    w:restore(good)
    assert(w:count() == 2)
  end,
}
