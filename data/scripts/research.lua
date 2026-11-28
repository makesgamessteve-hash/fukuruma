-- Research (research spec): samples go into projects from the research tree (research/tree.lua), one at a time, each
-- taking its time; done projects upgrade the dolls: better sensor suites (sensors.upgrade), a longer-lasting filter
-- and tougher armour (survival.lua), a longer jump (universe.reach). Started from the workshop's lab (K). Simulation
-- state: what is done and what runs.
local sim = require("fk.sim")
local chain = require("chain")
local sensors = require("sensors")
local dialogue = require("dialogue")
local economy = require("economy")

local research = { tree = {} }

function research.register(node) research.tree[#research.tree + 1] = node end
for _, node in ipairs(require("research.tree")) do research.register(node) end

function research.state() return sim.get(research.id, "research") end

function research.done(id) return research.state().done[id] == true end

local function node(id)
  for _, n in ipairs(research.tree) do
    if n[1] == id then return n end
  end
end

-- Whether a project can start now: not done, not running, its prerequisites done and its samples at hand.
function research.can_start(n)
  local s = research.state()
  if s.done[n[1]] or s.current then return false end
  for _, id in ipairs(n.after or {}) do
    if not s.done[id] then return false end
  end
  for name, k in pairs(n.needs) do
    if economy.has(name) < k then return false end
  end
  return true
end

function research.start(id)
  local n = node(id)
  if not n or not research.can_start(n) then return false end
  local samples = economy.state().samples
  for name, k in pairs(n.needs) do samples[name] = samples[name] - k end
  research.state().current = { id = id, left = n.time }
  sim.emit("research_started", { position = { chain.suit().x, chain.suit().y, chain.suit().z }, strength = 0.3 })
  return true
end

-- The product of an upgrade field over the done projects (factors), or the union of lists.
local function upgrades(field)
  local out = {}
  for _, n in ipairs(research.tree) do
    if research.done(n[1]) and n.upgrade[field] then out[#out + 1] = n.upgrade[field] end
  end
  return out
end

local function factor(field)
  local f = 1
  for _, v in ipairs(upgrades(field)) do f = f * v end
  return f
end

-- A doll kind's sensor suite with the research done: {range, resolution, kinds}.
function research.suite(kind, base)
  local suite = { range = base.range, resolution = base.resolution, kinds = base.kinds }
  for _, u in ipairs(upgrades("sensors")) do
    if u.kind == kind then
      suite.range, suite.resolution = suite.range * (u.range or 1), suite.resolution * (u.resolution or 1)
      if u.kinds then
        local k = { table.unpack(suite.kinds) }
        for _, add in ipairs(u.kinds) do k[#k + 1] = add end
        suite.kinds = k
      end
    end
  end
  return suite
end

function research.install()
  research.id = sim.create()
  sim.set(research.id, "research", { done = {}, current = nil })
  sensors.upgrade = research.suite
  require("universe").range_factor = function() return research.id and sim.alive(research.id) and factor("jump") or 1 end
  local survival = require("survival")
  survival.filter_factor = function() return factor("filter") end
  survival.armour = function() return factor("armour") end
  dialogue.trees.workshop.nodes.lab = {
    text = function()
      local s, text = research.state(), "LAB. "
      if s.current then text = text .. string.format("RESEARCHING %s: %d S LEFT. ", node(s.current.id)[2], math.ceil(s.current.left)) end
      local samples, names = economy.state().samples, {}
      for name, k in pairs(samples) do if k > 0 then names[#names + 1] = k .. " " .. name:upper():gsub("_", " ") end end
      table.sort(names)
      return text .. "SAMPLES: " .. (#names > 0 and table.concat(names, ", ") or "NONE") .. "."
    end,
    options = function()
      local out = {}
      for _, n in ipairs(research.tree) do
        if #out < 3 and research.can_start(n) then
          out[#out + 1] = { "Research " .. n[2]:lower(), go = "lab", act = function() research.start(n[1]) end }
        end
      end
      out[#out + 1] = { "Back", go = "workshop" }
      return out
    end,
  }
end

-- Each tick: the running project goes on, and is done when its time is up.
function research.tick()
  local s = research.state()
  if not s.current then return end
  s.current.left = s.current.left - sim.dt
  if s.current.left <= 0 then
    s.done[s.current.id] = true
    sim.emit("researched", { position = { chain.suit().x, chain.suit().y, chain.suit().z }, name = node(s.current.id)[2],
      strength = 0.6 })
    s.current = nil
  end
end

return research
