-- The ship AI's voice (doll-chain presentation): a line of text at the bottom of the view for what the chain does,
-- for a few seconds. Presentation only: it listens to simulation events and never changes them.
local dolls = require("dolls")

local ship_ai = { SHOW = 4 }

local function name(kind) return dolls.by_id[kind] and dolls.by_id[kind].name:upper() or "UNKNOWN" end

-- The line for an event, or nil. target(id): the kind of the doll with that ID (or nil).
function ship_ai.line(event, data, target)
  local other = data.id and target(data.id)
  if event == "deploy" then return name(data.kind) .. " DEPLOYED."
  elseif event == "recall" then return name(data.kind) .. " RECOVERED TO THE HOLD."
  elseif event == "board" then return "WELCOME ABOARD THE " .. name(data.kind) .. ", COMMANDER."
  elseif event == "teleport" then return "TELEPORT COMPLETE. " .. name(data.kind) .. "."
  elseif event == "autopilot" then return "AUTOPILOT ENGAGED: " .. (other and name(other) or "TARGET") .. "."
  elseif event == "arrived" then return "AUTOPILOT: ARRIVED AT THE " .. (other and name(other) or "TARGET") .. "."
  elseif event == "hazard_stop" then
    return "AUTOPILOT HALTED: " .. (data.hazard or "HAZARD"):upper():gsub("_", " ") .. " AHEAD. YOU HAVE CONTROL."
  elseif event == "alerted" then return "WARNING: THE PING WAS HEARD. SOMETHING IS COMING."
  end
end

-- Listens to the chain's events. state: {text, until}; now(): presentation time; target(id): a doll's kind.
function ship_ai.listen(sim, state, now, target)
  for _, event in ipairs({ "deploy", "recall", "board", "teleport", "autopilot", "arrived", "hazard_stop", "alerted" }) do
    sim.listen(event, function(data)
      state.text, state["until"] = ship_ai.line(event, data or {}, target), now() + ship_ai.SHOW
    end)
  end
end

-- Draws the current line, if any, centred near the bottom (8 pixels a letter). Returns whether it drew.
function ship_ai.draw(state, now, w, h)
  if not state.text or now > state["until"] then return false end
  local text = "SHIP AI: " .. state.text
  fk.gfx.text(math.floor(w / 2 - #text * 4), h - 34, text, { 0.6, 0.95, 1 })
  return true
end

return ship_ai
