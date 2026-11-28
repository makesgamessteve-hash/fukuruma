-- Factions and reputation (factions spec). Every world has its natives, a band of thieves, and the system has a
-- spacefaring civilisation, all from the seed (named streams): a name, a kind, a base attitude. What the Commander does
-- moves the reputation with each (-100..100, simulation state); the attitude is the base one shifted by it:
--   hostile < territorial < fearful < curious < trading (friendly enough to trade with).
local sim = require("fk.sim")

local factions = {}

factions.ATTITUDES = { "hostile", "territorial", "fearful", "curious", "trading" }
factions.KINDS = { natives = { 2, 5 }, thieves = { 1, 1 }, spacefarers = { 2, 5 } } -- base attitude range (indexes)
local SYLLABLES = { "an", "tor", "ve", "kel", "is", "ma", "rhu", "sa", "dun", "oth", "pe", "lyr", "gan", "ix" }

local function name(rng, n)
  local s = ""
  for _ = 1, n do s = s .. SYLLABLES[rng:range(1, #SYLLABLES)] end
  return s:upper()
end

-- The factions of world key (its system is the part of the key before the slash): {natives, thieves, spacefarers},
-- each {id, kind, name, base (attitude index)}.
function factions.of(key)
  local system = key:match("^([^/]*)") or key
  local out = {}
  for _, kind in ipairs({ "natives", "thieves", "spacefarers" }) do
    local rng = fk.rng("faction", kind == "spacefarers" and system or key, kind)
    local range = factions.KINDS[kind]
    out[kind] = { id = (kind == "spacefarers" and system or key) .. "#" .. kind, kind = kind, name = name(rng, rng:range(2, 3)),
      base = rng:range(range[1], range[2]) }
  end
  return out
end

function factions.state() return sim.get(factions.id, "factions") end

function factions.install()
  factions.id = sim.create()
  sim.set(factions.id, "factions", { reputation = {} })
end

function factions.reputation(f) return factions.state().reputation[f.id] or 0 end

-- Changes the reputation with faction f by amount (clamped), with an event when the attitude changes.
function factions.change(f, amount)
  local before = factions.attitude(f)
  local r = factions.state().reputation
  r[f.id] = math.max(-100, math.min(100, (r[f.id] or 0) + amount))
  local after = factions.attitude(f)
  if after ~= before then sim.emit("attitude", { faction = f.name, attitude = after, strength = 0.4 }) end
end

-- The attitude of faction f now: its base moved one step per 25 points of reputation (so any faction can come to
-- trade, or turn hostile).
function factions.attitude(f)
  local i = f.base + math.floor((factions.reputation(f) + 12) / 25)
  return factions.ATTITUDES[math.max(1, math.min(#factions.ATTITUDES, i))]
end

return factions
