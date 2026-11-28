-- Story threads (story-threads spec): the mystery arc as threads of steps (story/*.lua; mods add their own with
-- story.register). Each step waits for its condition, then happens: the ship AI says its line, its effect runs, and
-- the thread moves on. A finished thread goes into the codex's finds. Checked every CHECK ticks; simulation state.
local sim = require("fk.sim")
local chain = require("chain")
local sensors = require("sensors")

local story = { threads = {} }

story.CHECK = 30

function story.register(thread) story.threads[#story.threads + 1] = thread end
story.register(require("story.signal"))

function story.state() return sim.get(story.id, "story") end

-- A thread's progress {step (the next step's index), ...its own data}.
function story.progress(id)
  local s = story.state()
  s.threads[id] = s.threads[id] or { step = 1 }
  return s.threads[id]
end

function story.install()
  story.id = sim.create()
  sim.set(story.id, "story", { threads = {} })
end

-- A star for a thread to point at: another star within the drive's reach, the same for the same world.
local function pick_star(world)
  local universe, galaxy = require("universe"), require("fk.galaxy")
  local home = universe.state().seed
  local list = {}
  for _, s in ipairs(galaxy.near(universe.view().star.position, universe.RANGE)) do
    if s.seed ~= home then list[#list + 1] = s end
  end
  if #list == 0 then return nil end
  local s = list[fk.rng("story-star", world):range(1, #list)]
  return { seed = s.seed, sector = s.sector }
end

function story.tick()
  if sim.tick % story.CHECK ~= 0 then return end
  local world = sensors.state().world
  if not world then return end
  local universe = require("universe")
  for _, thread in ipairs(story.threads) do
    local pr = story.progress(thread.id)
    local step = thread.steps[pr.step]
    if step then
      local ctx = { state = pr, world = world, system = universe.state().seed,
        solved = require("artifacts").progress(world).solved, pick_star = function() return pick_star(world) end,
        reward = function(name, n)
          local samples = require("economy").state().samples
          samples[name] = (samples[name] or 0) + n
        end }
      if step.when(ctx) then
        if step.on then step.on(ctx) end
        pr.step = pr.step + 1
        local star = pr.star and string.format("%X", pr.star.seed % 0x10000) or "?"
        sim.emit("story", { position = { chain.suit().x, chain.suit().y, chain.suit().z }, thread = thread.id,
          text = string.format(step.text, star), strength = 0.7 })
        if not thread.steps[pr.step] then require("survival").state().found.threads[thread.id] = true end
      end
    end
  end
end

-- The threads under way, for the codex and the screens: {name, step text so far}.
function story.journal()
  local out = {}
  for _, thread in ipairs(story.threads) do
    local pr = story.state().threads[thread.id]
    if pr and pr.step > 1 then out[#out + 1] = thread.name .. (thread.steps[pr.step] and "" or " (ANSWERED)") end
  end
  return out
end

return story
