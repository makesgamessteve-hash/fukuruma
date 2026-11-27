-- The galaxy for scripts (galaxy-generation spec): sectors of the world seed's galaxy, cached, and the stars near
-- a point. Positions are light-years from the galactic centre (fk.galaxy).
local galaxy = {}

local SECTOR = fk.galaxy.SECTOR
local cache, order = {}, {}
local CACHE_SIZE = 256

local function key(sx, sy, sz) return sx .. "," .. sy .. "," .. sz end

function galaxy.sector_of(p)
  return math.floor(p[1] / SECTOR), math.floor(p[2] / SECTOR), math.floor(p[3] / SECTOR)
end

-- The stars of a sector (generated once, then kept among the last CACHE_SIZE sectors used).
function galaxy.sector(sx, sy, sz)
  local k = key(sx, sy, sz)
  local stars = cache[k]
  if not stars then
    stars = fk.galaxy.sector(fk.seed(), sx, sy, sz)
    for _, s in ipairs(stars) do s.sector = { sx, sy, sz } end
    cache[k] = stars
    order[#order + 1] = k
    if #order > CACHE_SIZE then cache[table.remove(order, 1)] = nil end
  end
  return stars
end

function galaxy.reset() cache, order = {}, {} end

local function distance(a, b)
  local x, y, z = a[1] - b[1], a[2] - b[2], a[3] - b[3]
  return math.sqrt(x * x + y * y + z * z)
end
galaxy.distance = distance

-- The stars within radius light-years of p, nearest first (ties by seed, so the order never depends on tables).
function galaxy.near(p, radius, filter)
  local x0, y0, z0 = galaxy.sector_of({ p[1] - radius, p[2] - radius, p[3] - radius })
  local x1, y1, z1 = galaxy.sector_of({ p[1] + radius, p[2] + radius, p[3] + radius })
  local found = {}
  for sx = x0, x1 do
    for sy = y0, y1 do
      for sz = z0, z1 do
        for _, s in ipairs(galaxy.sector(sx, sy, sz)) do
          local d = distance(p, s.position)
          if d <= radius and (not filter or filter(s)) then found[#found + 1] = { star = s, distance = d } end
        end
      end
    end
  end
  table.sort(found, function(a, b)
    if a.distance ~= b.distance then return a.distance < b.distance end
    return a.star.seed < b.star.seed
  end)
  local stars = {}
  for i, f in ipairs(found) do stars[i] = f.star end
  return stars
end

-- Where a new game starts: the Sun-like star nearest the galaxy's home position.
function galaxy.home_star()
  for _, radius in ipairs({ 16, 32, 64 }) do
    local stars = galaxy.near(fk.galaxy.HOME, radius, function(s) return s.kind == "star" and s.mass >= 0.8 and s.mass <= 1.2 end)
    if stars[1] then return stars[1] end
  end
  return galaxy.near(fk.galaxy.HOME, 64)[1]
end

return galaxy
