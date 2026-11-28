-- Living aboard (living-interiors spec): why the Commander walks the dolls. A person needs food, sleep and a wash;
-- dolls need maintenance; big dolls grow their own food. The rooms (interior.plan, interior/rooms.lua) hold the
-- fixtures for all of it, used with the hand (E):
--   eat (galley): a meal from the doll's stores, or a ration grown in a biotope; hunger to 0
--   sleep (quarters): fatigue to 0         wash (bath): grime to 0
--   heal (med bay): the radiation dose cleared and the suit made whole
--   maintain (engine room): the doll's wear to 0; (life support): its air plant's wear to 0
--   harvest (biotope): the ripe crop into rations      workbench (workshop), lab: the workshop and research menus
-- Hunger and fatigue rise all the time, grime outside (faster in toxins); at full the Commander tires (the suit no longer mends aboard,
-- and slowly breaks outside). Engine wear rises while a doll moves and slows it above half; life support wears while
-- the Commander is aboard, and when it is spent the doll no longer restores the suit. All of it is simulation state.
local sim = require("fk.sim")
local chain = require("chain")
local interior = require("interior")
local survival = require("survival")
local environment = require("environment")

local living = {}

living.HUNGER = 2400   -- seconds from fed to starving
living.FATIGUE = 3600  -- seconds from rested to exhausted
living.GRIME = 1800    -- seconds outside from clean to filthy (faster in toxins and dust)
living.WEAR = 7200     -- seconds of moving from overhauled to worn out
living.AIR = 5400      -- seconds aboard from serviced to spent (dolls with life support)
living.CROP = 1200     -- seconds for a biotope's crop to ripen
living.HARVEST = 6     -- rations from a ripe crop
living.STORES = 12     -- meals in a doll's galley when it is new

-- (kept on the survival entity, and made when missing: saves from before living aboard load with fresh needs)
function living.state()
  local s = sim.get(survival.id, "living")
  if not s then
    s = { hunger = 0, fatigue = 0, grime = 0 }
    sim.set(survival.id, "living", s)
  end
  return s
end

-- Whether doll kind has a room of type t.
local function has(kind, t)
  for _, r in ipairs(interior.layout(kind).rooms) do
    if r.type == t then return true end
  end
  return false
end

-- The doll's wear (engine) and its air plant's, its galley's stores and its crop (fields on the doll, saved with it).
local function upkeep(d)
  d.wear, d.air = d.wear or 0, d.air or 0
  d.stores = d.stores or living.STORES
  d.crop = d.crop or 0
  return d
end

-- How fast doll d may go of its best: worn engines above half lose up to half their speed.
function living.speed_factor(d)
  local w = d.wear or 0
  return w > 0.5 and 1 - (w - 0.5) or 1
end

local function pct(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

-- What each fixture does: hint(d, f) -> the visor's text, or nil; act(d, f) (the use command).
local function here(d) return { d.x, d.y, d.z } end
living.FIXTURES = {
  eat = {
    hint = function(d) return (upkeep(d).stores > 0 or (require("economy").state().items.food or 0) > 0) and "EAT" or "THE GALLEY IS EMPTY" end,
    act = function(d)
      local items = require("economy").state().items
      if upkeep(d).stores > 0 then d.stores = d.stores - 1
      elseif (items.food or 0) > 0 then items.food = items.food - 1
      else return end
      living.state().hunger = 0
      sim.emit("eat", { position = here(d), strength = 0.3 })
    end,
  },
  sleep = {
    hint = function() return "SLEEP" end,
    act = function(d) living.state().fatigue = 0 sim.emit("sleep", { position = here(d), strength = 0.4 }) end,
  },
  wash = {
    hint = function() return "WASH" end,
    act = function(d) living.state().grime = 0 sim.emit("wash", { position = here(d), strength = 0.3 }) end,
  },
  heal = {
    hint = function() return "TREATMENT" end,
    act = function(d)
      local s = survival.state()
      s.dose, s.integrity = 0, 1
      sim.emit("heal", { position = here(d), strength = 0.5 })
    end,
  },
  maintain = {
    hint = function(d, f)
      local what = f.room == "life support" and "air" or "wear"
      return (f.room == "life support" and "SERVICE LIFE SUPPORT " or "OVERHAUL THE ENGINES ") .. pct(upkeep(d)[what])
    end,
    act = function(d, f)
      upkeep(d)
      if f.room == "life support" then d.air = 0 else d.wear = 0 end
      sim.emit("maintain", { position = here(d), kind = d.kind, strength = 0.6 })
    end,
  },
  harvest = {
    hint = function(d) return upkeep(d).crop >= 1 and "HARVEST" or ("CROP " .. pct(d.crop)) end,
    act = function(d)
      if upkeep(d).crop < 1 then return end
      local items = require("economy").state().items
      d.crop, items.food = 0, (items.food or 0) + living.HARVEST
      sim.emit("harvest", { position = here(d), strength = 0.4 })
    end,
  },
  workbench = {
    hint = function() return "WORKSHOP" end,
    act = function() if not require("dialogue").open() then require("dialogue").menu("workshop", "workshop") end end,
  },
  lab = {
    hint = function() return "LAB" end,
    act = function() if not require("dialogue").open() then require("dialogue").menu("workshop", "lab") end end,
  },
}

function living.install()
  chain.fixtures = living.FIXTURES
  chain.speed_factor = living.speed_factor
  chain.wear_screen = function(d)
    upkeep(d)
    return { "MAINTENANCE", "ENGINES " .. pct(1 - d.wear) .. (has(d.kind, "life support") and ("  AIR " .. pct(1 - d.air)) or "") }
  end
  survival.weary = function() -- (survival.lua: a tired Commander mends slower, aboard and out)
    local s = living.state()
    return s.hunger >= 1 or s.fatigue >= 1
  end
  survival.air = function(d) return not d or (d.air or 0) < 1 end -- (a spent air plant restores nothing)
end

-- Each tick (after the chain's): the Commander's needs, and the dolls' wear and crops.
function living.tick()
  local s, dt = living.state(), sim.dt
  s.hunger = math.min(1, s.hunger + dt / living.HUNGER)
  s.fatigue = math.min(1, s.fatigue + dt / living.FATIGUE)
  if chain.on_foot() then
    local p = chain.suit()
    local e = environment.at(p.x, p.z)
    s.grime = math.min(1, s.grime + dt * (1 + e.toxin * 4) / living.GRIME)
  end
  local current, walk = chain.current(), chain.walking()
  local aboard = walk and chain.find(walk.doll) or (current.kind ~= "exosuit" and current)
  for _, d in ipairs(chain.state().dolls) do
    if d.kind ~= "exosuit" then
      upkeep(d)
      if math.abs(d.speed or 0) > 0.01 then d.wear = math.min(1, d.wear + dt / living.WEAR) end
      if d == aboard and has(d.kind, "life support") then d.air = math.min(1, d.air + dt / living.AIR) end
      if has(d.kind, "biotope") then d.crop = math.min(1, d.crop + dt / living.CROP) end
    end
  end
end

-- The visor's warnings (presentation): needs nearly full.
function living.warnings()
  local s, out = living.state(), {}
  if s.hunger > 0.8 then out[#out + 1] = s.hunger >= 1 and "STARVING: EAT IN A GALLEY" or "HUNGRY" end
  if s.fatigue > 0.8 then out[#out + 1] = s.fatigue >= 1 and "EXHAUSTED: SLEEP IN QUARTERS" or "TIRED" end
  if s.grime > 0.8 then out[#out + 1] = "FILTHY: WASH" end
  return out
end

return living
