-- Economy (trading, crafting and outposts specs). What the Commander carries: credits, samples (taken on foot from
-- creatures and hazards: F within reach), goods and crafted items. Each settlement is a market (natives curious or
-- friendlier trade): its prices come from the world's seed (a named stream) per good, rise as it is bought from and
-- fall as it is sold to, and its people's reputation gives a discount. The workshop (K, inside a doll or at an
-- outpost) crafts from recipes; an outpost kit builds an outpost on foot (H), and modules make it more: power
-- (it restores the suit nearby), storage, a landing pad and a scanner (it scans around itself like a Walker).
-- All of it is simulation state; recipes, goods and modules are data open to mods.
local sim = require("fk.sim")
local chain = require("chain")
local sensors = require("sensors")
local factions = require("factions")
local settlements = require("settlements")
local dialogue = require("dialogue")

local economy = {}

economy.GOODS = { { "ore", 20 }, { "spice", 35 }, { "crystal", 60 }, { "tools", 45 } } -- {name, base price}
economy.SAMPLE = { grazer = true, vent = true, gas_pocket = true, radiation = true, predator = "stunned" }
economy.REACH = 4             -- metres to take a sample
economy.STEP = 0.06           -- price change for each one bought or sold
economy.SPREAD = 0.85         -- what a market pays of its price
economy.OUTPOST_REACH = 20    -- metres to work on an outpost
economy.RECIPES = { -- {id, name, needs = {goods and samples}, makes}
  { "filter", "FILTER CARTRIDGE", needs = { spice = 1, gas_pocket = 1 } },
  { "repair", "REPAIR KIT", needs = { ore = 2 } },
  { "outpost", "OUTPOST KIT", needs = { ore = 3, tools = 1 } },
}
economy.MODULES = { { "power", { ore = 1 } }, { "storage", { tools = 1 } }, { "pad", { ore = 2 } }, { "scanner", { crystal = 1 } } }

function economy.state() return sim.get(economy.id, "economy") end

-- How many of a good or sample the Commander has.
function economy.has(name)
  local s = economy.state()
  return s.goods[name] or s.samples[name] or 0
end

local function take(needs)
  local s = economy.state()
  for name, n in pairs(needs) do
    if economy.has(name) < n then return false end
  end
  for name, n in pairs(needs) do
    if s.goods[name] then s.goods[name] = s.goods[name] - n else s.samples[name] = s.samples[name] - n end
  end
  return true
end

local function cost_text(needs)
  local names = {}
  for name in pairs(needs) do names[#names + 1] = name end
  table.sort(names)
  for i, name in ipairs(names) do names[i] = needs[name] .. " " .. name:upper():gsub("_", " ") end
  return table.concat(names, ", ")
end

-- Markets ------------------------------------------------------------------------------------------------------------

-- A market's price of good g (index) when the Commander buys (selling: true when the Commander sells).
function economy.price(market, g, selling)
  local key, si = market:match("^(.*)#(%d+)$")
  local rng = fk.rng("market", key, tonumber(si), g)
  local factor = 0.6 + rng:float()
  local delta = (economy.state().deltas[market] or {})[g] or 0
  local rep = factions.reputation(factions.of(key).natives)
  local p = economy.GOODS[g][2] * factor * (1 + economy.STEP * delta) * (1 - rep / 400)
  if selling then p = p * economy.SPREAD * (1 + rep / 200) end
  return math.max(1, math.floor(p + 0.5))
end

local function trade(o, buying)
  local s, g = economy.state(), o.good
  local name = economy.GOODS[g][1]
  s.deltas[o.market] = s.deltas[o.market] or {}
  local d = s.deltas[o.market]
  if buying then
    local p = economy.price(o.market, g, false)
    if s.credits < p then return end
    s.credits, s.goods[name], d[g] = s.credits - p, s.goods[name] + 1, (d[g] or 0) + 1
  else
    if s.goods[name] < 1 then return end
    s.credits, s.goods[name], d[g] = s.credits + economy.price(o.market, g, true), s.goods[name] - 1, (d[g] or 0) - 1
  end
  sim.emit("trade", { position = { chain.suit().x, chain.suit().y + 1, chain.suit().z }, strength = 0.2 })
end

dialogue.register("market", { start = {}, nodes = { market = {
  text = function(o)
    local g = economy.GOODS[o.good]
    return string.format("MARKET. CREDITS %d. %s: BUY %d, SELL %d, YOU HAVE %d.", economy.state().credits, g[1]:upper(),
      economy.price(o.market, o.good, false), economy.price(o.market, o.good, true), economy.has(g[1]))
  end,
  options = function(o)
    local nxt = economy.GOODS[o.good % #economy.GOODS + 1][1]
    return { { "Next: " .. nxt, go = "market", act = function(open) open.good = open.good % #economy.GOODS + 1 end },
      { "Buy one", go = "market", act = function(open) trade(open, true) end },
      { "Sell one", go = "market", act = function(open) trade(open, false) end },
      { "Done" } }
  end } } })

dialogue.EFFECTS.market = function() -- (the natives' tree: "Trade.")
  local p = chain.suit()
  local h = settlements.native_near(p.x, p.z, settlements.TALK * 2)
  dialogue.menu("market", "market", { market = sensors.state().world .. "#" .. (h and h.settlement or 1), good = 1 })
end

-- The workshop ------------------------------------------------------------------------------------------------------

-- The outpost on the current world within reach of the suit, or nil.
function economy.outpost_near()
  local key = sensors.state().world
  local o = key and economy.state().outposts[key]
  if not o then return nil end
  local p = chain.suit()
  local dx, dz = o.x - p.x, o.z - p.z
  return dx * dx + dz * dz < economy.OUTPOST_REACH * economy.OUTPOST_REACH and o or nil
end

local function craft(r)
  if take(r.needs) then
    local items = economy.state().items
    items[r[1]] = (items[r[1]] or 0) + 1
    sim.emit("crafted", { position = { chain.suit().x, chain.suit().y + 1, chain.suit().z }, strength = 0.4 })
  end
end

local function add_module(m)
  local o = economy.outpost_near()
  if o and not o.modules[m[1]] and take(m[2]) then
    o.modules[m[1]] = true
    sim.emit("crafted", { position = { o.x, chain.ground(o.x, o.z) + 1, o.z }, strength = 0.4 })
  end
end

dialogue.register("workshop", { start = {}, nodes = {
  workshop = {
    text = function()
      local s = economy.state()
      return string.format("WORKSHOP. CREDITS %d. ORE %d SPICE %d CRYSTAL %d TOOLS %d.", s.credits, s.goods.ore, s.goods.spice,
        s.goods.crystal, s.goods.tools)
    end,
    options = function()
      local out = { { "Craft", go = "craft" }, { "Research", go = "lab" } }
      if economy.outpost_near() then out[#out + 1] = { "Outpost modules", go = "modules" } end
      out[#out + 1] = { "Done" }
      return out
    end },
  craft = {
    text = function()
      local lines = {}
      for _, r in ipairs(economy.RECIPES) do lines[#lines + 1] = r[2] .. " (" .. (economy.state().items[r[1]] or 0) .. "): " .. cost_text(r.needs) .. "." end
      return table.concat(lines, " ")
    end,
    options = function()
      local out = {}
      for _, r in ipairs(economy.RECIPES) do out[#out + 1] = { "Make a " .. r[2]:lower(), go = "craft", act = function() craft(r) end } end
      out[#out + 1] = { "Back", go = "workshop" }
      return out
    end },
  modules = {
    text = function()
      local o, lines = economy.outpost_near(), {}
      for _, m in ipairs(economy.MODULES) do
        lines[#lines + 1] = m[1]:upper() .. (o and o.modules[m[1]] and " (BUILT)" or ": " .. cost_text(m[2])) .. "."
      end
      return "OUTPOST. " .. table.concat(lines, " ")
    end,
    options = function()
      local out, o = {}, economy.outpost_near()
      for _, m in ipairs(economy.MODULES) do
        if #out < 3 and o and not o.modules[m[1]] then out[#out + 1] = { "Build the " .. m[1], go = "modules", act = function() add_module(m) end } end
      end
      out[#out + 1] = { "Back", go = "workshop" }
      return out
    end },
} })

-- Samples and outposts ----------------------------------------------------------------------------------------------

local function sample_target()
  if chain.current().kind ~= "exosuit" or chain.state().walk then return nil end
  local p = chain.suit()
  for _, h in ipairs(sensors.hazards()) do
    local rule = economy.SAMPLE[h.kind]
    local dx, dz = h.x - p.x, h.z - p.z
    if rule and not h.sampled and dx * dx + dz * dz < economy.REACH * economy.REACH
      and (rule == true or (h.stunned and h.stunned > sim.tick)) then return h end
  end
end

function economy.install()
  economy.id = sim.create()
  sim.set(economy.id, "economy", { credits = 100, samples = {}, goods = { ore = 0, spice = 0, crystal = 0, tools = 0 },
    items = {}, deltas = {}, outposts = {}, exotic = {} })
  chain.hands[#chain.hands + 1] = {
    hint = function()
      local h = sample_target()
      return h and ("TAKE A SAMPLE: " .. sensors.HAZARDS[h.kind].name) or nil
    end,
    act = function()
      local h = sample_target()
      if not h then return end
      h.sampled = true
      local s = economy.state().samples
      s[h.kind] = (s[h.kind] or 0) + 1
      sim.emit("sample", { position = { h.x, chain.ground(h.x, h.z) + 0.5, h.z }, strength = 0.3 })
    end,
  }
  sim.on("workshop", function() -- in a doll, or on foot at an outpost
    if dialogue.open() or (chain.on_foot() and not economy.outpost_near()) then return end
    dialogue.menu("workshop", "workshop")
  end)
  sim.on("outpost", function() -- an outpost kit unpacked where the suit stands (one per world)
    local s, key = economy.state(), sensors.state().world
    if not chain.on_foot() or not key or s.outposts[key] or (s.items.outpost or 0) < 1 then return end
    s.items.outpost = s.items.outpost - 1
    local p = chain.suit()
    s.outposts[key] = { x = p.x + 6, z = p.z, modules = {}, built = sim.tick }
    sim.emit("outpost", { position = { p.x + 6, p.y, p.z }, strength = 0.8 })
  end)
end

-- Each tick: an artifact found gives exotic matter (once a world); outposts' power restores the suit, their scanners
-- scan.
function economy.tick(restore)
  local s, key = economy.state(), sensors.state().world
  if not key then return end
  if not s.exotic[key] and require("artifacts").progress(key).solved then
    s.exotic[key] = true
    s.samples.exotic = (s.samples.exotic or 0) + 1
  end
  local o = s.outposts[key]
  if not o then return end
  if o.modules.power and economy.outpost_near() then restore() end
  if o.modules.scanner and sim.tick % sensors.PASSIVE == 0 then
    sensors.scan({ kind = "walker", x = o.x, y = chain.ground(o.x, o.z) + 10, z = o.z }, false)
  end
end

-- Draws the outpost on the current world (presentation): a hab, and its modules.
function economy.draw(state, eye)
  local key = sensors.state().world
  local o = key and economy.state().outposts[key]
  if not o then return 0 end
  local hull, mat4 = require("dolls.hull"), require("mat4")
  local sig = "h"
  for _, m in ipairs(economy.MODULES) do sig = sig .. (o.modules[m[1]] and m[1]:sub(1, 2) or "") end
  if state.sig ~= sig then
    local c, d = { 0.8, 0.8, 0.78 }, { 0.3, 0.32, 0.35 }
    local parts = { { "box", at = { 0, 1.5, 0 }, size = { 6, 3, 6 }, color = c }, { "box", at = { 0, 3.2, 0 }, size = { 6.4, 0.4, 6.4 }, color = d } }
    if o.modules.power then parts[#parts + 1] = { "box", at = { 6, 0.3, 0 }, size = { 4, 0.2, 3 }, color = { 0.1, 0.15, 0.35 } } end
    if o.modules.storage then parts[#parts + 1] = { "box", at = { -5, 1.2, 0 }, size = { 3, 2.4, 4 }, color = d } end
    if o.modules.pad then parts[#parts + 1] = { "box", at = { 0, 0.1, 12 }, size = { 12, 0.2, 12 }, color = { 0.4, 0.4, 0.42 } } end
    if o.modules.scanner then parts[#parts + 1] = { "box", at = { 0, 6, 0 }, size = { 0.3, 5, 0.3 }, color = d } end
    state.sig, state.mesh = sig, fk.gfx.mesh(hull.build(parts, 1))
  end
  local y = chain.ground(o.x, o.z)
  fk.gfx.draw(state.mesh, mat4.translation(o.x, y, o.z), { roughness = 0.5, metalness = 0.4 })
  fk.gfx.light({ position = { o.x, y + 4, o.z }, color = { 1, 0.9, 0.7 }, intensity = 20, radius = 25 })
  return 1
end

return economy
