-- Tweens for UI, HUD and diegetic screens (effects spec): a value moving from one number to another
-- over a duration with an easing curve.
local tween = {}

tween.ease = {
  linear = function(t) return t end,
  quad_out = function(t) return 1 - (1 - t) * (1 - t) end,
  cubic_in_out = function(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end,
  back_out = function(t) -- overshoots a little, then settles: a juicy pop
    local c = 1.70158
    return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
  end,
  elastic_out = function(t)
    if t == 0 or t == 1 then return t end
    return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) + 1
  end,
}

local Tween = {}
Tween.__index = Tween

function tween.new(from, to, duration, ease)
  local f = tween.ease[ease or "quad_out"]
  assert(f, "tween: no easing named '" .. tostring(ease) .. "'")
  return setmetatable({ from = from, to = to, duration = duration, ease = f, time = 0 }, Tween)
end

-- Advances by dt and returns the current value.
function Tween:update(dt)
  self.time = math.min(self.duration, self.time + dt)
  return self:value()
end

function Tween:value()
  local t = self.duration > 0 and self.time / self.duration or 1
  return self.from + (self.to - self.from) * self.ease(t)
end

function Tween:done() return self.time >= self.duration end

return tween
