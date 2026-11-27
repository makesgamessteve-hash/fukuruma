-- fk.galaxy and fk/galaxy.lua (galaxy-generation spec).
local galaxy = require("fk.galaxy")

return {
  ["sectors, background requests and caching"] = function()
    local now = fk.galaxy.sector(5, 812, 0, 0)
    assert(#now > 10 and now[1].seed and #now[1].position == 3 and now[1].kind and now[1].color[1] <= 1)
    local req = fk.galaxy.request(5, 812, 0, 0)
    local later = req:stars()
    assert(req:ready() and #later == #now and later[1].seed == now[1].seed, "the same stars in the background")
    fk.galaxy.request(5, 1, 2, 3) -- never read: when it is collected, its job finishes first
    galaxy.reset()
    local a = galaxy.sector(812, 0, 0)
    assert(galaxy.sector(812, 0, 0) == a, "cached")
    assert(a[1].sector[1] == 812)
    for i = 1, 260 do galaxy.sector(i, 50, 0) end
    assert(galaxy.sector(812, 0, 0) ~= a, "old sectors are dropped")
  end,
  ["stars near a point, nearest first, and the home star"] = function()
    local near = galaxy.near(fk.galaxy.HOME, 20)
    assert(#near > 20)
    for i = 2, #near do
      assert(galaxy.distance(fk.galaxy.HOME, near[i].position) >= galaxy.distance(fk.galaxy.HOME, near[i - 1].position))
    end
    local home = galaxy.home_star()
    assert(home.kind == "star" and home.mass >= 0.8 and home.mass <= 1.2 and home.class ~= "")
    local sx = galaxy.sector_of({ -1, 31.9, 32 })
    assert(sx == -1)
  end,
  ["star physics and density for scripts"] = function()
    local sun = fk.galaxy.physics("star", 1)
    assert(math.abs(sun.luminosity - 1) < 1e-9 and sun.class == "G")
    assert(fk.galaxy.physics("black_hole", 10).luminosity == 0)
    assert(fk.galaxy.density(0, 0, 0) > fk.galaxy.density(26000, 0, 0))
    local ok = pcall(fk.galaxy.physics, "star", 0)
    assert(not ok)
    for _, m in ipairs({ 60, 5, 2.2, 1.3, 0.85, 0.4 }) do assert(fk.galaxy.physics("star", m).class ~= "") end
    assert(math.abs(fk.math.exp(1) - math.exp(1)) < 1e-15 and math.abs(fk.math.log(10) - math.log(10)) < 1e-15)
    assert(math.abs(fk.math.atan2(1, 2) - math.atan(1, 2)) < 1e-15 and math.abs(fk.math.pow(2, 0.5) - math.sqrt(2)) < 1e-15)
  end,
}
