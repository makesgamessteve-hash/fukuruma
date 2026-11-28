-- story.lua and story/signal.lua (story-threads spec): the signal is heard at a solved ruin, followed to its star and
-- answered there.
local game = require("main")
local sim = require("fk.sim")
local actions = require("fk.actions")
local chain = require("chain")
local sensors = require("sensors")
local story = require("story")
local artifacts = require("artifacts")
local universe = require("universe")
local economy = require("economy")
local survival = require("survival")

local function start()
  sim.reset()
  actions.reset()
  game.init()
  sim.step(game)
end

local function step(n)
  for _ = 1, n or 1 do sim.step(game) end
end

local function solve()
  local key = sensors.state().world
  local site = artifacts.of(key)
  for _, i in ipairs(site.order) do artifacts.wake(i, site, key) end
end

return {
  ["the signal: heard, followed, answered"] = function()
    start()
    local lines = {}
    sim.listen("story", function(d) lines[#lines + 1] = d.text end)
    step(story.CHECK)
    assert(story.progress("the_signal").step == 1 and #story.journal() == 0, "nothing yet")
    solve()
    step(story.CHECK)
    local pr = story.progress("the_signal")
    assert(pr.step == 2 and pr.star and pr.star.seed ~= universe.state().seed, "a signal from another star")
    assert(#story.journal() == 1 and lines[1]:find("SIGNAL", 1, true))
    for _, d in ipairs(chain.state().dolls) do
      if d.kind == "jump_ship" then chain.state().at = d.id end
    end
    sim.send("jump", { sector = pr.star.sector, seed = pr.star.seed })
    step(story.CHECK + 2)
    assert(universe.state().seed == pr.star.seed and pr.step == 3, "followed to its star")
    local exotic = economy.has("exotic")
    solve()
    step(story.CHECK)
    assert(pr.step == 4 and economy.has("exotic") >= exotic + 2, "answered, and rewarded")
    step(survival.CHECK)
    assert(survival.state().found.threads.the_signal and story.journal()[1]:find("ANSWERED", 1, true))
  end,
}
