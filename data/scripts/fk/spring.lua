-- Damped springs for presentation (camera follow, secondary motion such as antennas and cables).
-- frequency: oscillations per second; damping: 1 settles without overshoot, below 1 wobbles.
local spring = {}
local Spring = {}
Spring.__index = Spring

function spring.new(frequency, damping, value)
  return setmetatable({ value = value or 0, velocity = 0, frequency = frequency, damping = damping }, Spring)
end

local STEP = 1 / 240 -- substeps keep stiff springs stable at low frame rates

-- Moves the value towards target over dt seconds and returns it.
function Spring:update(target, dt)
  local w = 2 * math.pi * self.frequency
  local steps = math.max(1, math.ceil(dt / STEP))
  local h = dt / steps
  for _ = 1, steps do
    local accel = w * w * (target - self.value) - 2 * self.damping * w * self.velocity
    self.velocity = self.velocity + accel * h
    self.value = self.value + self.velocity * h
  end
  return self.value
end

-- Pushes the spring (an impulse, in units per second).
function Spring:kick(velocity)
  self.velocity = self.velocity + velocity
end

return spring
