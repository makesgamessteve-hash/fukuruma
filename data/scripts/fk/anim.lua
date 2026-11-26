-- Blend trees and state machines over fk.anim poses (animation spec). Presentation only: driven by frame
-- time and read-only game parameters, never by the simulation's state changes.
local anim = {}

-- A 1D blend tree: entries sorted by `at` (a parameter value, for example speed in m/s). The two entries
-- around the parameter are blended; all entries share one phase (0..1), so walk and run cycles stay in step.
-- entries: { { clip = "walk", at = 2.6, events = { { at = 0.25, name = "step_left" }, ... } }, ... }
-- The events of the entry with the larger weight fire when the phase passes them.
local Tree = {}
Tree.__index = Tree

function anim.blend1d(model, entries, param)
  assert(#entries >= 1, "blend1d: needs at least one entry")
  local durations = {}
  for _, clip in ipairs(model:clips()) do durations[clip.name] = clip.duration end
  for i, e in ipairs(entries) do
    assert(durations[e.clip], "blend1d: the model has no clip named '" .. tostring(e.clip) .. "'")
    assert(i == 1 or e.at > entries[i - 1].at, "blend1d: entries must be sorted by 'at'")
  end
  return setmetatable({ entries = entries, param = param, durations = durations, phase = 0 }, Tree)
end

-- The two entries around value and the weight of the second (0..1).
function Tree:weights(value)
  local e = self.entries
  if #e == 1 or value <= e[1].at then return 1, 1, 0 end
  for i = 2, #e do
    if value <= e[i].at then return i - 1, i, (value - e[i - 1].at) / (e[i].at - e[i - 1].at) end
  end
  return #e, #e, 0
end

function Tree:update(dt, params, fired)
  local a, b, w = self:weights(params[self.param] or 0)
  local ea, eb = self.entries[a], self.entries[b]
  local duration = self.durations[ea.clip] * (1 - w) + self.durations[eb.clip] * w
  local before = self.phase
  self.phase = self.phase + dt / duration
  self.a, self.b, self.w = a, b, w
  for _, event in ipairs((w > 0.5 and eb or ea).events or {}) do
    local at = event.at
    if (before < at and self.phase >= at) or (before < at + 1 and self.phase >= at + 1) then fired[#fired + 1] = event.name end
  end
  self.phase = self.phase % 1
end

function Tree:apply(pose)
  local ea, eb = self.entries[self.a or 1], self.entries[self.b or 1]
  pose:rest()
  pose:sample(ea.clip, self.phase * self.durations[ea.clip])
  if (self.w or 0) > 0 then pose:sample(eb.clip, self.phase * self.durations[eb.clip], self.w) end
end

-- A state machine of blend trees and single clips with crossfades.
-- def = { model = m, start = "walk", states = { walk = { tree = t }, wave = { clip = "wave", next = "walk" } },
--         transitions = { { from = "walk", to = "wave", when = function(params) ... end, fade = 0.2 } } }
-- A single clip loops unless the state names a `next` state, which follows when the clip ends.
local Machine = {}
Machine.__index = Machine

function anim.machine(def)
  assert(def.states[def.start], "machine: no start state '" .. tostring(def.start) .. "'")
  local durations = {}
  for _, clip in ipairs(def.model:clips()) do durations[clip.name] = clip.duration end
  local m = setmetatable({ def = def, durations = durations, current = def.start, time = 0, fade = 0, fade_time = 0,
    scratch = fk.anim.pose(def.model) }, Machine)
  return m
end

-- Switches to a state, crossfading over `fade` seconds.
function Machine:set(name, fade)
  assert(self.def.states[name], "machine: no state '" .. tostring(name) .. "'")
  if name == self.current then return end
  self.previous, self.previous_time = self.current, self.time
  self.current, self.time = name, 0
  self.fade, self.fade_time = fade or 0, 0
end

-- Advances by dt with the given parameters; returns the names of the events that fired.
function Machine:update(dt, params)
  local fired = {}
  for _, t in ipairs(self.def.transitions or {}) do
    if t.from == self.current and t.when(params) then
      self:set(t.to, t.fade)
      break
    end
  end
  local state = self.def.states[self.current]
  self.time = self.time + dt
  if state.tree then
    state.tree:update(dt, params, fired)
  elseif state.next and self.time >= self.durations[state.clip] then
    self:set(state.next, state.fade_out or 0.2)
  end
  if self.previous then
    local old = self.def.states[self.previous]
    if old.tree then old.tree:update(dt, params, {}) end -- keeps moving while it fades out; its events are dropped
    self.previous_time = self.previous_time + dt
    self.fade_time = self.fade_time + dt
    if self.fade_time >= self.fade then self.previous = nil end
  end
  return fired
end

local function evaluate(self, name, time, pose)
  local state = self.def.states[name]
  if state.tree then return state.tree:apply(pose) end
  local duration = self.durations[state.clip]
  pose:rest()
  pose:sample(state.clip, state.next and math.min(time, duration) or time % duration)
end

function Machine:apply(pose)
  evaluate(self, self.current, self.time, pose)
  if self.previous then
    evaluate(self, self.previous, self.previous_time, self.scratch)
    pose:blend(self.scratch, 1 - self.fade_time / self.fade)
  end
end

return anim
