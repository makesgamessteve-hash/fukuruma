-- The ship AI's voice (doll-chain presentation): a line of text at the bottom of the view for what the chain does,
-- for a few seconds. Presentation only: it listens to simulation events and never changes them.
local dolls = require("dolls")

local ship_ai = { SHOW = 4 }

local S = require("strings").t

local function name(kind) return dolls.by_id[kind] and dolls.by_id[kind].name:upper() or S("ship.unknown") end

-- What fills in each event's line (strings/en.lua: "ship.<event>"); events without one have no arguments.
local ARGS = {
  deploy = function(d) return name(d.kind) end, recall = function(d) return name(d.kind) end,
  board = function(d) return name(d.kind) end, teleport = function(d) return name(d.kind) end,
  autopilot = function(_, other) return other and name(other) or S("ship.target") end,
  arrived = function(_, other) return other and name(other) or S("ship.target") end,
  hazard_stop = function(d) return ((d.hazard or S("ship.hazard")):upper():gsub("_", " ")) end,
  breach = function(d) return math.floor((d.integrity or 0) * 100 + 0.5) end,
  collapse = function(d) return name(d.kind) end, theft = function(d) return name(d.kind) end,
  recovered = function(d) return name(d.kind) end, boarders = function(d) return name(d.kind) end,
  researched = function(d) return d.name or S("ship.project") end,
}

-- The line for an event, or nil. target(id): the kind of the doll with that ID (or nil).
function ship_ai.line(event, data, target)
  if event == "story" then return data.text end -- (story.lua writes its own lines)
  local other = data.id and target(data.id)
  local key = "ship." .. event
  if S(key) == key then return nil end
  if ARGS[event] then return S(key, ARGS[event](data, other)) end
  return S(key)
end

-- Listens to the chain's events. state: {text, until}; now(): presentation time; target(id): a doll's kind.
function ship_ai.listen(sim, state, now, target)
  for _, event in ipairs({ "deploy", "recall", "board", "teleport", "autopilot", "arrived", "hazard_stop", "alerted", "breach", "clone", "collapse", "noticed", "theft",
    "recovered", "boarders", "sealed", "repelled", "looted", "artifact", "guardian", "researched", "outpost",
    "repaired", "story" }) do
    sim.listen(event, function(data)
      state.text, state["until"] = ship_ai.line(event, data or {}, target), now() + ship_ai.SHOW
    end)
  end
end

-- Draws the current line, if any, centred near the bottom (8 pixels a letter). Returns whether it drew.
function ship_ai.draw(state, now, w, h)
  if not state.text or now > state["until"] then return false end
  local lines, fit = {}, math.max(20, math.floor(w / 8) - 2) -- words wrapped to the width (8 pixels a letter)
  for word in (S("ship.prefix") .. state.text):gmatch("%S+") do
    if #lines == 0 or #lines[#lines] + 1 + #word > fit then lines[#lines + 1] = word
    else lines[#lines] = lines[#lines] .. " " .. word end
  end
  for i, line in ipairs(lines) do
    fk.gfx.text(math.floor(w / 2 - #line * 4), h - 34 + (i - 1) * 10, line, { 0.6, 0.95, 1 }) -- (down: the hint is above)
  end
  return true
end

return ship_ai
