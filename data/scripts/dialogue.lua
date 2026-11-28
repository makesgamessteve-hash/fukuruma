-- Dialogue (dialogue spec): trees written in Lua (dialogue/*.lua), started by talking to a native on foot (F within
-- reach). The open talk is simulation state: the tree, the node, the faction; choose {option} picks an option (keys 1 to
-- 4, the gamepad's A, X, Y and B, touch buttons), which may change the reputation or reveal something, and goes on or
-- ends the talk. The same trees make the game's menus (dialogue.menu), whose options may be made from the state and
-- act on it. Options that need a better attitude are not offered.
local sim = require("fk.sim")
local chain = require("chain")
local sensors = require("sensors")
local factions = require("factions")
local settlements = require("settlements")

local dialogue = { trees = {} }

function dialogue.register(name, tree) dialogue.trees[name] = tree end
dialogue.register("natives", require("dialogue.natives"))

local function contact(kind, x, z, size)
  local s = sensors.state()
  s.contacts["told-" .. kind] = { id = -1, tick = sim.tick, x = x, z = z, size = size, kind = kind, by = "natives" }
end

-- What options can do: function(faction).
dialogue.EFFECTS = {
  respect = function(f) factions.change(f, 5) end,
  gift = function(f) factions.change(f, 15) end,
  insult = function(f) factions.change(f, -25) end,
  reveal_ruin = function()
    local site = require("artifacts").of(sensors.state().world)
    contact("ruin", site.x, site.z, 30)
  end,
  reveal_hideout = function()
    local h = require("thieves").hideout(sensors.state().world)
    contact("hideout", h.x, h.z, 20)
  end,
}
sensors.HAZARDS.hideout = { signature = "thermal", size = { 20, 20 }, stealth = 1, name = "THIEVES' HIDEOUT" }

function dialogue.state() return sim.get(dialogue.id, "dialogue") end

-- The open talk {tree, node, faction}, or nil.
function dialogue.open() return dialogue.state().open end

local function rank(attitude)
  for i, a in ipairs(factions.ATTITUDES) do
    if a == attitude then return i end
  end
end

-- The options of the open talk's node that are offered now (in order).
function dialogue.options()
  local o = dialogue.open()
  if not o then return {} end
  local f = settlements.faction()
  local out, options = {}, dialogue.trees[o.tree].nodes[o.node].options
  if type(options) == "function" then options = options(o) end -- (menus: options made from the state)
  for _, opt in ipairs(options) do
    if not opt.needs or rank(factions.attitude(f)) >= rank(opt.needs) then out[#out + 1] = opt end
  end
  return out
end

-- The open node's text (with the faction's name; a menu's text may be made from its state).
function dialogue.text()
  local o = dialogue.open()
  if not o then return nil end
  local text = dialogue.trees[o.tree].nodes[o.node].text
  if type(text) == "function" then return text(o) end
  local f = settlements.faction()
  return string.format(text, f and f.name or "")
end

-- Opens a menu: a tree's node, with its context (markets, the workshop, the lab: economy.lua and research.lua).
function dialogue.menu(tree, node, ctx)
  local o = { tree = tree, node = node }
  for k, v in pairs(ctx or {}) do o[k] = v end
  dialogue.state().open = o
end

local function talk_target()
  if chain.current().kind ~= "exosuit" or chain.state().walk or dialogue.open() then return nil end
  local p = chain.suit()
  return settlements.native_near(p.x, p.z, settlements.TALK)
end

function dialogue.install()
  dialogue.id = sim.create()
  sim.set(dialogue.id, "dialogue", { open = nil })
  chain.hands[#chain.hands + 1] = {
    hint = function() return talk_target() and ("TALK TO THE " .. settlements.faction().name) or nil end,
    act = function()
      local h = talk_target()
      if not h then return end
      local tree = dialogue.trees.natives
      dialogue.state().open = { tree = "natives", node = tree.start[factions.attitude(settlements.faction())], native = h.id }
      sim.emit("talk", { position = { h.x, chain.ground(h.x, h.z) + 1.7, h.z }, strength = 0.3 })
    end,
  }
  sim.on("choose", function(args)
    local opt = dialogue.options()[args.option]
    if not opt then return end
    local open = dialogue.state().open
    if opt.effect then dialogue.EFFECTS[opt.effect](settlements.faction()) end
    if opt.act then opt.act(open) end -- (a menu's action: buy, sell, craft, research...)
    if dialogue.state().open ~= open then return end -- (the action opened another menu)
    open.node = opt.go
    if not opt.go then dialogue.state().open = nil end
  end)
end

-- Draws the open talk: the text and the numbered options, on the visor (presentation).
function dialogue.draw(w, h)
  local text = dialogue.text()
  if not text then return false end
  local y, lines = math.floor(h * 0.55), {}
  for chunk in text:gmatch("[^ ]+") do -- wrapped at 52 letters
    if #lines == 0 or #lines[#lines] + #chunk + 1 > 52 then lines[#lines + 1] = chunk
    else lines[#lines] = lines[#lines] .. " " .. chunk end
  end
  local said = #lines
  for i, opt in ipairs(dialogue.options()) do lines[#lines + 1] = i .. ": " .. opt[1] end
  fk.gfx.rect(math.floor(w / 2 - 27 * 8), y - 6, 54 * 8, #lines * 11 + 18, { 0.02, 0.03, 0.06, 0.8 }) -- (a dark panel)
  for i, line in ipairs(lines) do
    fk.gfx.text(math.floor(w / 2 - 26 * 8), y + (i - 1) * 11 + (i > said and 6 or 0), line, i > said and { 1, 0.85, 0.5 } or { 0.9, 0.95, 1 })
  end
  return true
end

return dialogue
