-- The rooms of the dolls (vessel-interiors spec): what a room of each type is for and what stands in it. A room's
-- furniture is a list of hull parts (dolls/hull.lua) in metres, in the room's own frame: x across the room (0 at its
-- centre, +x away from the corridor; the door is at x = -w/2, z = 0), y up from the floor, z along the corridor.
-- Furniture keeps the doorway and a walkway along the room's middle clear. fixture: what the Commander's hand does
-- there ({kind, x, z} in the same frame). Mods add room types with rooms.register.
local rooms = { types = {} }

local STEEL, DARK, WHITE, WOOD = { 0.55, 0.57, 0.6 }, { 0.22, 0.23, 0.26 }, { 0.86, 0.87, 0.88 }, { 0.48, 0.34, 0.22 }
local FABRIC, GREEN, LEAF, SOIL = { 0.28, 0.36, 0.5 }, { 0.25, 0.5, 0.22 }, { 0.3, 0.62, 0.26 }, { 0.3, 0.22, 0.15 }
local LAMP, SCREEN, WARN, GROW = { 1, 0.92, 0.75 }, { 0.3, 0.75, 1 }, { 1, 0.5, 0.15 }, { 1, 0.75, 0.9 }

function rooms.register(name, def) rooms.types[name] = def end

local function chair(x, z, facing)
  return { "box", at = { x, 0.45, z }, size = { 0.5, 0.08, 0.5 }, color = FABRIC },
    { "box", at = { x - facing * 0.22, 0.75, z }, size = { 0.06, 0.6, 0.5 }, color = FABRIC },
    { "box", at = { x, 0.22, z }, size = { 0.08, 0.44, 0.08 }, color = DARK }
end

local function add(list, ...)
  for _, p in ipairs({ ... }) do list[#list + 1] = p end
  return list
end

rooms.register("galley", { fixture = "eat", parts = function(w, d)
  local p = {
    { "box", at = { w / 2 - 0.45, 0.45, 0 }, size = { 0.9, 0.9, d - 1.2 }, color = STEEL }, -- counters along the far wall
    { "box", at = { w / 2 - 0.45, 0.92, 0 }, size = { 0.94, 0.05, d - 1.1 }, color = WHITE },
    { "box", at = { w / 2 - 0.3, 1.9, 0 }, size = { 0.6, 0.7, d - 1.2 }, color = STEEL }, -- cupboards
    { "box", at = { w / 2 - 0.45, 0.955, -d / 4 }, size = { 0.5, 0.02, 0.6 }, color = WARN, glow = true }, -- the hob
    { "box", at = { w / 2 - 0.4, 1.0, d / 2 - 0.9 }, size = { 0.8, 2.0, 0.9 }, color = WHITE }, -- the fridge
    { "box", at = { 0.3, 0.74, 0 }, size = { 1.2, 0.06, 2.6 }, color = WOOD }, -- the table
    { "box", at = { 0.3, 0.37, 0 }, size = { 0.12, 0.74, 2.2 }, color = DARK },
  }
  for _, z in ipairs({ -0.8, 0.8 }) do add(p, chair(-0.6, z, -1)) add(p, chair(1.2, z, 1)) end
  add(p, { "box", at = { 0.3, 3.0, 0 }, size = { 0.4, 0.06, 1.6 }, color = LAMP, glow = true })
  return p
end })

rooms.register("quarters", { fixture = "sleep", parts = function(w, d)
  local p = {}
  for _, z in ipairs({ -d / 4, d / 4 }) do
    add(p, { "box", at = { w / 2 - 1.1, 0.25, z }, size = { 2.1, 0.5, 1.0 }, color = DARK }, -- a bunk
      { "box", at = { w / 2 - 1.1, 0.56, z }, size = { 2.0, 0.14, 0.95 }, color = FABRIC },
      { "box", at = { w / 2 - 0.25, 0.7, z }, size = { 0.4, 0.14, 0.7 }, color = WHITE },
      { "box", at = { w / 2 - 0.06, 1.0, z }, size = { 0.12, 2.0, 1.1 }, color = STEEL },
      { "box", at = { w / 2 - 0.12, 1.6, z + 0.3 }, size = { 0.04, 0.12, 0.2 }, color = LAMP, glow = true })
  end
  add(p, { "box", at = { -w / 2 + 0.35, 1.0, d / 2 - 0.8 }, size = { 0.6, 2.0, 1.2 }, color = STEEL }, -- lockers
    { "box", at = { 0.2, 0.75, -d / 2 + 0.4 }, size = { 1.4, 0.05, 0.6 }, color = WOOD }, -- a desk and its chair
    { "box", at = { 0.2, 0.37, -d / 2 + 0.4 }, size = { 1.3, 0.74, 0.04 }, color = DARK },
    { "box", at = { 0.2, 1.3, -d / 2 + 0.08 }, size = { 0.7, 0.45, 0.04 }, color = SCREEN, glow = true })
  add(p, chair(0.2, -d / 2 + 1.0, -1))
  return p
end })

rooms.register("bath", { fixture = "wash", parts = function(w, d)
  local p = {}
  for i = 0, 2 do -- shower stalls along the far wall, glass fronts
    local z = -d / 2 + 1.2 + i * 1.4
    add(p, { "box", at = { w / 2 - 0.6, 1.1, z + 0.65 }, size = { 1.2, 2.2, 0.06 }, color = WHITE },
      { "box", at = { w / 2 - 1.2, 1.1, z }, size = { 0.04, 2.0, 1.2 }, color = { 0.5, 0.65, 0.7 } },
      { "box", at = { w / 2 - 0.1, 2.2, z }, size = { 0.2, 0.06, 0.3 }, color = STEEL })
  end
  add(p, { "box", at = { 0.4, 0.45, d / 2 - 0.35 }, size = { 3.0, 0.9, 0.6 }, color = WHITE }, -- the basins
    { "box", at = { 0.4, 1.6, d / 2 - 0.05 }, size = { 2.8, 0.9, 0.04 }, color = { 0.7, 0.8, 0.85 } }, -- the mirror
    { "box", at = { 0.4, 2.15, d / 2 - 0.1 }, size = { 2.8, 0.06, 0.06 }, color = LAMP, glow = true },
    { "box", at = { -w / 2 + 0.6, 1.1, -d / 2 + 0.8 }, size = { 1.2, 2.2, 0.06 }, color = STEEL }, -- the toilet cubicle
    { "box", at = { -w / 2 + 1.2, 1.1, -d / 2 + 0.4 }, size = { 0.06, 2.2, 0.8 }, color = STEEL },
    { "box", at = { -w / 2 + 0.4, 0.22, -d / 2 + 0.4 }, size = { 0.4, 0.44, 0.55 }, color = WHITE })
  return p
end })

rooms.register("med bay", { fixture = "heal", parts = function(w, d)
  local p = {}
  for _, z in ipairs({ -d / 4, d / 4 }) do
    add(p, { "box", at = { w / 2 - 1.3, 0.45, z }, size = { 2.0, 0.12, 0.85 }, color = WHITE }, -- a med bed under its scanner arch
      { "box", at = { w / 2 - 1.3, 0.22, z }, size = { 1.6, 0.44, 0.5 }, color = STEEL },
      { "torus", at = { w / 2 - 1.3, 0.5, z }, axis = "x", r = 0.75, tube = 0.06, sides = 6, segments = 16, color = STEEL },
      { "box", at = { w / 2 - 0.15, 1.5, z }, size = { 0.06, 0.6, 0.8 }, color = SCREEN, glow = true })
  end
  add(p, { "box", at = { -w / 2 + 0.35, 1.0, d / 2 - 1.0 }, size = { 0.6, 2.0, 1.6 }, color = WHITE }, -- the cabinets
    { "box", at = { -w / 2 + 0.66, 1.4, d / 2 - 1.0 }, size = { 0.02, 0.2, 0.2 }, color = { 1, 0.2, 0.2 }, glow = true })
  return p
end })

rooms.register("engine room", { fixture = "maintain", parts = function(w, d)
  return {
    { "lathe", axis = "y", at = { w / 4, 0, 0 }, stations = { { 0, 1.4 }, { 0.4, 1.5 }, { 2.6, 1.5 }, { 3.0, 1.2 } }, sides = 16, color = STEEL },
    { "torus", at = { w / 4, 1.5, 0 }, axis = "y", r = 1.52, tube = 0.08, sides = 6, segments = 24, color = SCREEN, glow = true },
    { "torus", at = { w / 4, 2.2, 0 }, axis = "y", r = 1.52, tube = 0.08, sides = 6, segments = 24, color = SCREEN, glow = true },
    { "strut", from = { w / 4, 2.6, 0 }, to = { w / 2 - 0.2, 2.6, -d / 2 + 0.4 }, size = { 0.3, 0.3 }, color = DARK },
    { "strut", from = { w / 4, 2.6, 0 }, to = { w / 2 - 0.2, 2.6, d / 2 - 0.4 }, size = { 0.3, 0.3 }, color = DARK },
    { "strut", from = { w / 2 - 0.3, 0.3, -d / 2 + 0.4 }, to = { w / 2 - 0.3, 3.0, -d / 2 + 0.4 }, size = { 0.25, 0.25 }, color = DARK },
    { "box", at = { -w / 2 + 1.4, 0.55, -d / 2 + 0.5 }, size = { 1.6, 1.1, 0.6 }, color = DARK }, -- the maintenance console
    { "box", at = { -w / 2 + 1.4, 1.15, -d / 2 + 0.35 }, size = { 1.4, 0.4, 0.05 }, color = WARN, glow = true },
    { "box", at = { 0.0, 0.05, 0 }, size = { 0.9, 0.1, d - 1.0 }, color = { 0.8, 0.65, 0.1 } }, -- the hazard stripe
  }
end })

rooms.register("life support", { fixture = "maintain", parts = function(w, d)
  local p = {}
  for i = -1, 1 do
    add(p, { "lathe", axis = "y", at = { w / 2 - 1.0, 0, i * 2.4 }, stations = { { 0, 0.8 }, { 2.4, 0.8 }, { 2.8, 0.4 } }, sides = 12, color = WHITE },
      { "box", at = { w / 2 - 1.0, 1.2, i * 2.4 + 0.82 }, size = { 0.3, 0.2, 0.02 }, color = SCREEN, glow = true })
  end
  add(p, { "torus", at = { -w / 2 + 1.4, 1.6, d / 2 - 0.2 }, axis = "z", r = 0.8, tube = 0.1, sides = 6, segments = 16, color = STEEL },
    { "strut", from = { -w / 2 + 1.4, 1.6, d / 2 - 0.2 }, to = { w / 2 - 1.0, 2.8, 0 }, size = { 0.2, 0.2 }, color = DARK })
  return p
end })

rooms.register("workshop", { fixture = "workbench", parts = function(w, d)
  local p = {
    { "box", at = { w / 2 - 0.5, 0.45, 0 }, size = { 1.0, 0.9, d - 2 }, color = STEEL }, -- the workbench
    { "box", at = { w / 2 - 0.5, 0.93, 0 }, size = { 1.05, 0.06, d - 1.9 }, color = WOOD },
    { "box", at = { w / 2 - 0.05, 1.8, 0 }, size = { 0.1, 1.2, d - 2 }, color = DARK }, -- the tool wall
    { "ball", at = { w / 2 - 0.6, 1.0, -1.5 }, r = 0.15, color = WARN }, -- a robot arm
    { "strut", from = { w / 2 - 0.6, 1.0, -1.5 }, to = { w / 2 - 0.9, 1.8, -1.0 }, size = { 0.1, 0.1 }, color = WARN },
    { "strut", from = { w / 2 - 0.9, 1.8, -1.0 }, to = { w / 2 - 0.7, 1.4, -0.4 }, size = { 0.08, 0.08 }, color = WARN },
  }
  for i = 0, 2 do add(p, { "box", at = { -w / 2 + 0.7, 0.4 + i * 0.8, d / 2 - 0.9 }, size = { 1.2, 0.8, 1.2 }, color = WOOD }) end
  return p
end })

rooms.register("lab", { fixture = "lab", parts = function(w, d)
  local p = {
    { "box", at = { w / 2 - 0.5, 0.45, 0 }, size = { 1.0, 0.9, d - 2 }, color = WHITE },
    { "box", at = { w / 2 - 0.05, 1.5, 0 }, size = { 0.06, 0.8, 2.0 }, color = SCREEN, glow = true },
    { "lathe", axis = "y", at = { -w / 2 + 1.0, 0, d / 2 - 1.0 }, stations = { { 0, 0.5 }, { 1.0, 0.5 }, { 1.2, 0.3 } }, sides = 12, color = STEEL }, -- a centrifuge
  }
  for i = -2, 2 do
    add(p, { "lathe", axis = "y", at = { w / 2 - 0.5, 0.92, i * 0.6 }, stations = { { 0, 0.08 }, { 0.3, 0.08 } }, sides = 8,
      color = i % 2 == 0 and GREEN or SCREEN, glow = true }) -- sample jars
  end
  return p
end })

rooms.register("suit bay", { fixture = "suit", parts = function(w, d)
  return {
    { "box", at = { w / 2 - 0.4, 0.1, 0 }, size = { 0.8, 0.2, 2.4 }, color = DARK }, -- the suit's cradle and frame
    { "strut", from = { w / 2 - 0.2, 0.2, -1.1 }, to = { w / 2 - 0.2, 4.0, -1.1 }, size = { 0.2, 0.2 }, color = STEEL },
    { "strut", from = { w / 2 - 0.2, 0.2, 1.1 }, to = { w / 2 - 0.2, 4.0, 1.1 }, size = { 0.2, 0.2 }, color = STEEL },
    { "box", at = { w / 2 - 0.2, 3.0, 0 }, size = { 0.3, 0.3, 2.4 }, color = STEEL },
    { "box", at = { w / 2 - 0.3, 2.4, 0 }, size = { 0.05, 0.2, 1.6 }, color = WARN, glow = true },
  }
end })

rooms.register("clone bay", { fixture = "clone", parts = function(w, d)
  local p = {}
  for i = -1, 1 do
    add(p, { "lathe", axis = "y", at = { w / 2 - 1.0, 0, i * 2.4 }, stations = { { 0, 0.7 }, { 0.3, 0.7 }, { 0.3, 0.55 }, { 2.5, 0.55 }, { 2.5, 0.7 }, { 2.8, 0.7 } }, sides = 14, color = STEEL },
      { "lathe", axis = "y", at = { w / 2 - 1.0, 0.3, i * 2.4 }, stations = { { 0, 0.5 }, { 2.2, 0.5 } }, sides = 14, color = { 0.3, 0.9, 0.7 }, glow = true })
  end
  return p
end })

rooms.register("drone bay", { parts = function(w, d)
  local p = {}
  for i = -1, 1 do add(p, { "box", at = { w / 2 - 0.4, 1.4, i * 2.2 }, size = { 0.8, 2.8, 1.6 }, color = DARK },
    { "box", at = { w / 2 - 0.82, 1.4 + (i % 2) * 0.4, i * 2.2 }, size = { 0.04, 0.1, 1.2 }, color = SCREEN, glow = true }) end
  return p
end })

rooms.register("cargo deck", { parts = function(w, d)
  local p = {}
  for i = 0, 5 do
    local x, z, h = w / 2 - 0.8 - (i % 2) * 1.6, -d / 2 + 1.2 + (i // 2) * 2.2, 0.8 + (i % 3) * 0.4
    add(p, { "box", at = { x, h / 2, z }, size = { 1.4, h, 1.4 }, color = i % 2 == 0 and WOOD or STEEL })
  end
  return p
end })

-- The biotope: a hall of growing beds, fruit trees and a water channel under grow lights, where food is harvested.
rooms.register("biotope", { fixture = "harvest", height = 9, parts = function(w, d)
  local p = {
    { "box", at = { 0, 0.04, 0 }, size = { 1.2, 0.08, d - 2 }, color = { 0.55, 0.5, 0.42 } }, -- the path
    { "box", at = { -w / 4, 0.12, 0 }, size = { 0.8, 0.2, d - 6 }, color = { 0.2, 0.45, 0.6 }, glow = true }, -- the channel
  }
  for i = 0, 3 do -- growing beds with their crops
    local x = 2.5 + i * (w / 2 - 3) / 4
    add(p, { "box", at = { x, 0.3, 0 }, size = { 1.6, 0.6, d - 6 }, color = SOIL },
      { "box", at = { x, 0.75, 0 }, size = { 1.3, 0.3, d - 6.4 }, color = i % 2 == 0 and GREEN or LEAF },
      { "box", at = { x, 8.6, 0 }, size = { 0.3, 0.08, d - 4 }, color = GROW, glow = true }) -- grow lights
  end
  for i = 0, 5 do -- fruit trees along the far side
    local z = -d / 2 + 4 + i * (d - 8) / 5
    local x = -w / 2 + 3 + (i % 2) * 2
    add(p, { "strut", from = { x, 0, z }, to = { x, 3.2, z }, size = { 0.35, 0.35 }, color = WOOD },
      { "ball", at = { x, 4.2, z }, r = 1.6, sides = 10, color = LEAF },
      { "ball", at = { x + 0.6, 3.6, z + 0.4 }, r = 0.15, color = { 1, 0.55, 0.15 } })
  end
  return p
end })

return rooms
