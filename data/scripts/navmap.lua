-- The navigation maps (navigation-maps spec; CONCEPT 4.4 "Maps"): the galaxy map, a point cloud of the real stars
-- around the current one seen from above, with the jump range and unusual signatures; and the system map, a schematic
-- of the current system with orbits on a logarithmic scale, the bodies where they are now and a time scrubber.
-- Left/right choose, up/down scrub time (system map), Enter jumps (galaxy map), Tab switches maps, M or Escape closes.
local ui = require("fk.ui")
local galaxy = require("fk.galaxy")
local systems = require("gen.systems")
local universe = require("universe")
local units = require("gen.units")
local wonders = require("gen.wonders")

local navmap = { open = false, mode = "galaxy", selected = 1, time_offset = 0, speed = 0 }

local VIEW = 30 -- light-years shown around the current star
local PANEL = { 0.03, 0.05, 0.1, 0.88 }
local TEXT = { 0.75, 0.95, 1, 1 }
local DIM = { 0.4, 0.6, 0.7, 1 }
local WARN = { 1, 0.6, 0.3, 1 }

local cache = {} -- the stars and systems around the current star, kept while it stays the same

local function neighbourhood(here)
  if cache.seed ~= here.seed then
    cache = { seed = here.seed, stars = {}, systems = {} }
    for _, s in ipairs(galaxy.near(here.position, VIEW)) do
      if s.seed ~= here.seed then
        cache.stars[#cache.stars + 1] = s
        cache.systems[s.seed] = systems.generate(s)
      end
    end
  end
  return cache
end

function navmap.toggle()
  navmap.open = not navmap.open
  navmap.mode, navmap.selected, navmap.time_offset, navmap.speed = "galaxy", 1, 0, 0
  if navmap.open then ui.reset() end
  fk.audio.play(navmap.open and "ui_open" or "ui_move", { bus = "ui", volume = 0.6 })
end

-- Reads the controls; returns a jump target {sector, seed} when the Commander jumps.
function navmap.update(dt)
  local p = ui.input()
  local tab = fk.input.key("Tab") or fk.input.button("x")
  local switch = tab and not navmap.tab_held
  navmap.tab_held = tab
  if p.back then
    navmap.toggle()
    return nil
  end
  if switch then
    navmap.mode = navmap.mode == "galaxy" and "system" or "galaxy"
    navmap.selected = 1
    fk.audio.play("ui_move", { bus = "ui", volume = 0.6 })
  end
  local v = universe.view()
  local count = navmap.mode == "galaxy" and #neighbourhood(v.star).stars or #v.sys.bodies
  if count > 0 then
    if p.right then navmap.selected = navmap.selected % count + 1 end
    if p.left then navmap.selected = (navmap.selected - 2) % count + 1 end
    if p.left or p.right then fk.audio.play("ui_move", { bus = "ui", volume = 0.5 }) end
  end
  if navmap.mode == "system" then
    if p.up then navmap.speed = math.min(navmap.speed + 1, 6) end
    if p.down then navmap.speed = math.max(navmap.speed - 1, -6) end
    local rate = navmap.speed == 0 and 0 or (navmap.speed > 0 and 1 or -1) * 3600 * 4 ^ math.abs(navmap.speed) -- presentation only
    navmap.time_offset = navmap.time_offset + rate * dt
  elseif p.confirm then
    local s = neighbourhood(v.star).stars[navmap.selected]
    if s and galaxy.distance(s.position, v.star.position) <= universe.reach() then
      navmap.toggle()
      return { sector = { s.sector[1], s.sector[2], s.sector[3] }, seed = s.seed }
    end
    fk.audio.play("ui_move", { bus = "ui", volume = 0.6 })
  end
  return nil
end

local function panel(x, y, w, h) fk.gfx.rect(x, y, w, h, PANEL) end

local function fit(line, w) -- cut a line to the panel's width (8-pixel characters)
  local n = math.floor((w - 12) / 8)
  return #line > n and line:sub(1, n - 1) .. "." or line
end

local function bright(c, k) return { math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k), 1 } end

local function draw_galaxy(w, h, time)
  local v = universe.view()
  local n = neighbourhood(v.star)
  local cx, cy, scale = math.floor(w * 0.36), math.floor(h * 0.52), (h * 0.42) / VIEW
  local here = v.star.position
  local function at(p) return cx + (p[1] - here[1]) * scale, cy + (p[3] - here[3]) * scale - (p[2] - here[2]) * scale * 0.3 end
  for k = 0, 63 do -- the jump range
    local a = k / 64 * 2 * fk.math.pi
    fk.gfx.rect(math.floor(cx + fk.math.cos(a) * universe.reach() * scale), math.floor(cy + fk.math.sin(a) * universe.reach() * scale), 1, 1, DIM)
  end
  fk.gfx.rect(cx - 3, cy, 7, 1, TEXT)
  fk.gfx.rect(cx, cy - 3, 1, 7, TEXT)
  for i, s in ipairs(n.stars) do
    local x, y = at(s.position)
    local size = s.luminosity > 0.5 and 2 or 1
    fk.gfx.rect(math.floor(x), math.floor(y), size, size, bright(s.color, s.kind == "star" and 1 or 0.6))
    local sys = n.systems[s.seed]
    if sys.signature and math.floor(time * 2) % 2 == 0 then
      fk.gfx.rect(math.floor(x) - 2, math.floor(y) - 2, 1, 1, WARN)
      fk.gfx.rect(math.floor(x) + 3, math.floor(y) - 2, 1, 1, WARN)
    end
    if i == navmap.selected then
      fk.gfx.rect(math.floor(x) - 4, math.floor(y) - 4, 9, 1, TEXT)
      fk.gfx.rect(math.floor(x) - 4, math.floor(y) + 4, 9, 1, TEXT)
    end
  end
  local s = n.stars[navmap.selected]
  local px = math.floor(w * 0.66)
  panel(px, 30, w - px - 8, h - 60)
  fk.gfx.text(px + 6, 36, "GALAXY MAP", TEXT)
  fk.gfx.text(px + 6, 48, v.sys.name .. " (HERE)", DIM)
  if not s then return end
  local sys = n.systems[s.seed]
  local d = galaxy.distance(s.position, here)
  local planets = 0
  for _, b in ipairs(sys.bodies) do if b.kind == "planet" then planets = planets + 1 end end
  local lines = { sys.name, (s.class ~= "" and s.class .. " " or "") .. s.kind:gsub("_", " "):upper(),
    string.format("%.1f LY", d), sys.archetype:gsub("_", " "):upper(), planets .. " PLANETS" }
  if sys.signature then lines[#lines + 1] = "SIGNATURE: " .. wonders.by_id[sys.signature].name:upper() end
  for i, line in ipairs(lines) do fk.gfx.text(px + 6, 64 + i * 11, fit(line, w - px - 8), i == 1 and TEXT or DIM) end
  fk.gfx.text(px + 6, h - 44, d <= universe.reach() and "ENTER: JUMP" or "OUT OF RANGE", d <= universe.reach() and TEXT or WARN)
  fk.gfx.text(px + 6, h - 33, "TAB: SYSTEM MAP", DIM)
end

local function radius_of(a) return fk.math.log(1 + a / units.AU / 0.02) end

local function draw_system(w, h, t)
  local v = universe.view()
  local sys = v.sys
  local cx, cy = math.floor(w * 0.36), math.floor(h * 0.52)
  local far = radius_of(1e-3 * units.AU)
  for _, b in ipairs(sys.bodies) do
    if b.kind == "planet" and b.orbit then far = math.max(far, radius_of(b.orbit.a * (1 + b.orbit.e))) end
  end
  local scale = h * 0.42 / far
  local function at(p)
    local r = math.sqrt(p[1] * p[1] + p[3] * p[3])
    local k = r > 0 and radius_of(r) * scale / r or 0
    return cx + p[1] * k, cy + p[3] * k
  end
  for _, s in ipairs(sys.stars) do
    local x, y = at(s.orbit and fk.orbit.state(s.orbit, t) or { 0, 0, 0 })
    fk.gfx.rect(math.floor(x) - 1, math.floor(y) - 1, 3, 3, bright(s.color, 1))
  end
  for _, belt in ipairs(sys.belts) do
    for k = 0, 47 do
      local a = k / 48 * 2 * fk.math.pi
      local r = radius_of((belt.inner + belt.outer) / 2) * scale
      fk.gfx.rect(math.floor(cx + fk.math.cos(a) * r), math.floor(cy + fk.math.sin(a) * r), 1, 1, { 0.5, 0.45, 0.4, 1 })
    end
  end
  for i, b in ipairs(sys.bodies) do
    if b.kind == "planet" and b.orbit then
      local period = fk.orbit.period(b.orbit)
      for k = 0, 39 do -- the orbit, where the body will be over one period
        local x, y = at(fk.orbit.state(b.orbit, t + period * k / 40))
        fk.gfx.rect(math.floor(x), math.floor(y), 1, 1, { 0.35, 0.6, 0.75, 1 })
      end
    end
    if b.kind ~= "comet" and b.kind ~= "moon" then
      local x, y = at(universe.position(sys, i, t))
      local c = universe.PALETTE[b.class] or universe.PALETTE.barren
      fk.gfx.rect(math.floor(x) - 1, math.floor(y) - 1, 3, 3, { c[1], c[2], c[3], 1 })
      if i == v.place then fk.gfx.text(math.floor(x) + 4, math.floor(y) - 3, "*", WARN) end
      if i == navmap.selected then
        fk.gfx.rect(math.floor(x) - 3, math.floor(y) - 3, 8, 1, TEXT)
        fk.gfx.rect(math.floor(x) - 3, math.floor(y) + 4, 8, 1, TEXT)
      end
    end
  end
  local b = sys.bodies[navmap.selected]
  local px = math.floor(w * 0.66)
  panel(px, 30, w - px - 8, h - 60)
  fk.gfx.text(px + 6, 36, "SYSTEM MAP", TEXT)
  fk.gfx.text(px + 6, 48, sys.name, DIM)
  if b then
    local lines = { b.name, b.class:gsub("_", " "):upper(), string.format("%d C", math.floor(b.temperature - 273.15 + 0.5)),
      string.format("%.2f G", universe.gravity(b) / 9.81), b.atmosphere and string.format("%s %.2g BAR", b.atmosphere.gas:upper(), b.atmosphere.pressure) or "NO AIR" }
    for _, id in ipairs(b.marvels or {}) do lines[#lines + 1] = wonders.by_id[id].name:upper() end
    if navmap.selected == v.place then lines[#lines + 1] = "YOU ARE HERE" end
    for i, line in ipairs(lines) do fk.gfx.text(px + 6, 64 + i * 11, fit(line, w - px - 8), i == 1 and TEXT or DIM) end
  end
  fk.gfx.text(px + 6, h - 44, navmap.speed == 0 and "TIME: NOW" or string.format("TIME: X%d", navmap.speed), DIM)
  fk.gfx.text(px + 6, h - 33, "TAB: GALAXY MAP", DIM)
end

function navmap.draw(time)
  if not navmap.open then return end
  local w, h = fk.gfx.size()
  fk.gfx.rect(0, 0, w, h, { 0, 0.02, 0.05, 0.9 })
  if navmap.mode == "galaxy" then draw_galaxy(w, h, time)
  else draw_system(w, h, time + navmap.time_offset) end
end

return navmap
