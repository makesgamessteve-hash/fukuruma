-- Flora and rocks over the ground near the eye (biomes-and-scatter spec). The ground's own colour and slope say what
-- grows where: grass, shrubs and trees on green ground, rocks on steep, dry or frozen ground. Each 2 m cell of a grid
-- around the eye gets its plants from a hash of the cell, so the same place always looks the same; they are drawn
-- as instances (one draw per kind) and sway in the wind. Presentation only: nothing here touches the simulation.
local scatter = {}

scatter.CELL = 2    -- metres per cell
scatter.N = 64      -- cells along the grid's edge (128 m)
scatter.SNAP = 32   -- the grid moves in steps of this many metres
scatter.GRASS = 36  -- grass only this near the grid's centre (metres)
scatter.DECK = 81   -- nothing grows on the deck (half its size, metres)
scatter.density = 1 -- the graphics level's share of the plants (0..1.5)

local function hash(a, b, salt) -- deterministic integer hash of a cell: 0 .. 2^31 - 1
  local h = (a * 73856093) ~ (b * 19349663) ~ (salt * 83492791)
  h = (h ~ (h >> 13)) * 1274126177
  h = h ~ (h >> 16)
  return h & 0x7fffffff
end

local function unit(h, k) -- independent fractions (0..1) from one hash
  return (((h * (2 * k + 1) * 2654435761) >> 11) & 0xffff) / 65535
end

local function add(mesh, x, y, z, r, g, b, nx, ny, nz)
  local n = #mesh.positions
  mesh.positions[n + 1], mesh.positions[n + 2], mesh.positions[n + 3] = x, y, z
  mesh.colors[n + 1], mesh.colors[n + 2], mesh.colors[n + 3] = r, g, b
  mesh.normals[n + 1], mesh.normals[n + 2], mesh.normals[n + 3] = nx, ny, nz
  return n // 3 + 1
end

local function new_mesh() return { positions = {}, colors = {}, normals = {}, indices = {} } end

local function tri(mesh, a, b, c)
  local i = mesh.indices
  i[#i + 1], i[#i + 2], i[#i + 3] = a, b, c
end

-- A tuft of tapered blades leaning outwards, darker at the root.
local function grass_mesh()
  local m = new_mesh()
  for k = 0, 6 do
    local a = k * 2.399963
    local lean, h = 0.12 + (k % 3) * 0.05, 0.35 + (k * 37 % 5) * 0.06
    local cx, cz = fk.math.cos(a), fk.math.sin(a)
    local px, pz = -cz * 0.035, cx * 0.035 -- half the blade's width, across it
    local b1 = add(m, -px, 0, -pz, 0.18, 0.3, 0.1, cx, 0.3, cz)
    local b2 = add(m, px, 0, pz, 0.18, 0.3, 0.1, cx, 0.3, cz)
    local t = add(m, cx * lean, h, cz * lean, 0.55, 0.75, 0.3, cx, 0.6, cz)
    tri(m, b1, b2, t)
  end
  return m
end

-- A lumpy dome of leaves.
local function shrub_mesh()
  local m = new_mesh()
  local SEG, RINGS = 8, 4
  for r = 0, RINGS do
    local phi = r / RINGS * fk.math.pi * 0.5
    for s = 0, SEG do
      local th = s / SEG * 2 * fk.math.pi
      local bump = 1 + 0.18 * fk.math.sin(th * 3 + r * 1.7)
      local x, y, z = fk.math.cos(phi) * fk.math.cos(th), fk.math.sin(phi), fk.math.cos(phi) * fk.math.sin(th)
      local shade = 0.6 + 0.4 * y
      add(m, x * 0.6 * bump, y * 0.55 * bump, z * 0.6 * bump, 0.16 * shade, 0.32 * shade, 0.1 * shade, x, y, z)
    end
  end
  for r = 0, RINGS - 1 do
    for s = 0, SEG - 1 do
      local a, b = r * (SEG + 1) + s + 1, (r + 1) * (SEG + 1) + s + 1
      tri(m, a, b, a + 1)
      tri(m, a + 1, b, b + 1)
    end
  end
  return m
end

-- A faceted, flattened boulder.
local function rock_mesh()
  local m = new_mesh()
  local SEG, RINGS = 7, 5
  for r = 0, RINGS do
    local phi = r / RINGS * fk.math.pi
    for s = 0, SEG do
      local th = s / SEG * 2 * fk.math.pi
      local k = 1 + 0.22 * fk.math.sin(th * 2 + r * 2.3) * fk.math.cos(phi * 3)
      local x, y, z = fk.math.sin(phi) * fk.math.cos(th), fk.math.cos(phi), fk.math.sin(phi) * fk.math.sin(th)
      add(m, x * k * 0.6, y * k * 0.38 + 0.12, z * k * 0.5, 0.42, 0.4, 0.37, x, y, z)
    end
  end
  for r = 0, RINGS - 1 do
    for s = 0, SEG - 1 do
      local a, b = r * (SEG + 1) + s + 1, (r + 1) * (SEG + 1) + s + 1
      tri(m, a, a + 1, b)
      tri(m, a + 1, b + 1, b)
    end
  end
  return m
end

-- A conifer: a trunk and three tiers of cones.
local function tree_mesh()
  local m = new_mesh()
  local SEG = 7
  local function cone(y0, y1, r, cr, cg, cb)
    local tip = add(m, 0, y1, 0, cr * 1.3, cg * 1.3, cb * 1.3, 0, 1, 0)
    local first = #m.positions // 3 + 1
    for s = 0, SEG do
      local th = s / SEG * 2 * fk.math.pi
      local x, z = fk.math.cos(th), fk.math.sin(th)
      add(m, x * r, y0, z * r, cr, cg, cb, x, r / (y1 - y0), z)
    end
    for s = 0, SEG - 1 do tri(m, first + s, tip, first + s + 1) end
  end
  cone(0, 2.2, 0.16, 0.3, 0.2, 0.12)      -- the trunk
  cone(1.2, 4.2, 1.5, 0.08, 0.22, 0.1)
  cone(2.6, 5.4, 1.15, 0.09, 0.25, 0.11)
  cone(3.9, 6.6, 0.8, 0.1, 0.28, 0.12)
  return m
end

-- Far trees: one cone each, standing in for the full trees beyond the near grid.
local function far_tree_mesh()
  local m = new_mesh()
  local tip = add(m, 0, 6.4, 0, 0.12, 0.3, 0.13, 0, 1, 0)
  for s = 0, 5 do
    local th = s / 5 * 2 * fk.math.pi
    add(m, fk.math.cos(th) * 1.4, 0.6, fk.math.sin(th) * 1.4, 0.08, 0.22, 0.1, fk.math.cos(th), 0.5, fk.math.sin(th))
  end
  for s = 0, 4 do tri(m, tip + 1 + s, tip, tip + 2 + s) end
  return m
end

scatter.FAR_CELL = 16 -- metres per cell of the far grid (trees only)
scatter.FAR_N = 32    -- its cells along the edge (512 m)

local KINDS = { "grass", "shrub", "rock", "tree", "far_tree" }
local IDENTITY = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
local SWAY = { grass = 1.6, shrub = 0.08, rock = 0, tree = 0.004, far_tree = 0 }

function scatter.meshes()
  return { grass = fk.gfx.mesh(grass_mesh()), shrub = fk.gfx.mesh(shrub_mesh()), rock = fk.gfx.mesh(rock_mesh()),
    tree = fk.gfx.mesh(tree_mesh()), far_tree = fk.gfx.mesh(far_tree_mesh()) }
end

-- The ground's kind from its colour (sRGB) and slope: what grows there, as chances per cell.
function scatter.chances(r, g, b, slope)
  local green = g - (r + b) / 2
  local bright = (r + g + b) / 3
  if slope > 0.55 then return { rock = 0.12 } end
  if bright > 0.8 then return { rock = 0.01 } end                     -- snow and ice
  if green > 0.05 then return { grass = 5, shrub = 0.05, tree = 0.012, rock = 0.01 } end
  if r > b + 0.1 then return { rock = 0.03, shrub = 0.008 } end       -- dry ground
  return { rock = 0.02 }
end

-- Builds the instances of the 128 m grid centred near (cx, cz) (local axes) on ground g.
function scatter.build(g, cx, cz, salt)
  local N, CELL = scatter.N, scatter.CELL
  local x0, z0 = cx - N * CELL / 2, cz - N * CELL / 2
  local heights, colors = g.surface:grid({ up = g.up, east = g.east, north = g.north, origin = { x0, z0 }, cell = CELL,
    n = N, colors = true })
  local out = { grass = {}, shrub = {}, rock = {}, tree = {}, far_tree = {} }
  local row = N + 1
  local function put(kind, x, y, z, scale, h)
    local list = out[kind]
    local n = #list
    list[n + 1], list[n + 2], list[n + 3], list[n + 4] = x, y, z, scale
    list[n + 5], list[n + 6], list[n + 7], list[n + 8] = unit(h, 3) * 6.2832, 0.8 + 0.4 * unit(h, 4), unit(h, 5) * 6.2832, SWAY[kind]
  end
  for j = 0, N - 1 do
    for i = 0, N - 1 do
      local x, z = x0 + i * CELL, z0 + j * CELL
      if math.abs(x + CELL / 2) > scatter.DECK or math.abs(z + CELL / 2) > scatter.DECK then
        local k = j * row + i + 1
        local h00, h10, h01, h11 = heights[k], heights[k + 1], heights[k + row], heights[k + row + 1]
        local slope = math.sqrt((h10 - h00) * (h10 - h00) + (h01 - h00) * (h01 - h00)) / CELL
        local c = 3 * (k - 1)
        local cell_i, cell_j = math.floor(x / CELL + 0.5), math.floor(z / CELL + 0.5)
        local d2 = (x - cx) * (x - cx) + (z - cz) * (z - cz)
        for kind, chance in pairs(scatter.chances(colors[c + 1], colors[c + 2], colors[c + 3], slope)) do
          if kind ~= "grass" or d2 < scatter.GRASS * scatter.GRASS then
            local count = chance * scatter.density
            for m = 0, math.ceil(count) - 1 do
              local hsh = hash(cell_i, cell_j, salt * 16 + m * 4 + (kind == "grass" and 0 or kind == "shrub" and 1 or kind == "rock" and 2 or 3))
              if unit(hsh, 0) < count - m then
                local fx, fz = unit(hsh, 1), unit(hsh, 2)
                local y = h00 + (h10 - h00) * fx + (h01 - h00) * fz -- (the lower triangle's plane: close enough)
                local u = unit(hsh, 6)
                local scale = kind == "tree" and 0.7 + 0.6 * u or kind == "rock" and 0.4 + 1.4 * u * u or 0.7 + 0.6 * u
                put(kind, x + fx * CELL, y - 0.08, z + fz * CELL, scale, hsh)
              end
            end
          end
        end
      end
    end
  end
  -- the far grid: trees where the near grid ends, as many per cell as the near grid would have
  local FN, FC = scatter.FAR_N, scatter.FAR_CELL
  local fx0, fz0 = cx - FN * FC / 2, cz - FN * FC / 2
  local fh, fc = g.surface:grid({ up = g.up, east = g.east, north = g.north, origin = { fx0, fz0 }, cell = FC, n = FN,
    colors = true })
  local half = N * CELL / 2
  for j = 0, FN - 1 do
    for i = 0, FN - 1 do
      local x, z = fx0 + i * FC, fz0 + j * FC
      local outside = math.abs(x + FC / 2 - cx) > half or math.abs(z + FC / 2 - cz) > half
      if outside and (math.abs(x + FC / 2) > scatter.DECK or math.abs(z + FC / 2) > scatter.DECK) then
        local k = j * (FN + 1) + i + 1
        local c = 3 * (k - 1)
        local slope = math.abs(fh[k + 1] - fh[k]) / FC
        local tree = scatter.chances(fc[c + 1], fc[c + 2], fc[c + 3], slope).tree
        if tree then
          local count = tree * (FC / CELL) * (FC / CELL) * scatter.density
          local hsh = hash(math.floor(x / FC + 0.5), math.floor(z / FC + 0.5), salt * 16 + 7)
          for m = 0, math.min(3, math.ceil(count) - 1) do
            local hm = hash(hsh, m, 9)
            if unit(hm, 0) < count - m then
              local ux, uz = unit(hm, 1), unit(hm, 2)
              put("far_tree", x + ux * FC, fh[k] + (fh[k + 1] - fh[k]) * ux + (fh[k + FN + 1] - fh[k]) * uz - 0.3,
                z + uz * FC, 0.7 + 0.6 * unit(hm, 6), hm)
            end
          end
        end
      end
    end
  end
  return out
end

-- Draws the plants around eye (local axes) on ground g: rebuilt when the eye has moved on by half a step.
function scatter.draw(state, g, eye)
  if not g or scatter.density <= 0 then return 0 end
  state.meshes = state.meshes or scatter.meshes()
  local cx, cz = math.floor(eye[1] / scatter.SNAP + 0.5) * scatter.SNAP, math.floor(eye[3] / scatter.SNAP + 0.5) * scatter.SNAP
  if state.g ~= g or state.cx ~= cx or state.cz ~= cz or state.density ~= scatter.density then
    state.g, state.cx, state.cz, state.density = g, cx, cz, scatter.density
    local lists = scatter.build(g, cx, cz, 1)
    state.instances, state.count = {}, 0
    for _, kind in ipairs(KINDS) do
      state.instances[kind] = fk.gfx.instances(lists[kind])
      state.count = state.count + #lists[kind] // 8
    end
  end
  for _, kind in ipairs(KINDS) do
    fk.gfx.draw(state.meshes[kind], IDENTITY, { instances = state.instances[kind], roughness = kind == "rock" and 0.85 or 0.7 })
  end
  return state.count
end

return scatter
