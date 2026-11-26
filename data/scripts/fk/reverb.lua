-- Reverb zones (audio spec): spheres with their own room size, damping and wet level; the listener hears the
-- smallest zone it stands in, or the default outside every zone. The mixer glides between settings.
local reverb = { zones = {}, default = { room = 0.3, damping = 0.6, wet = 0.08 } }

function reverb.clear() reverb.zones, reverb.current = {}, nil end

-- zone: { center = {x, y, z}, radius = metres, room = 0..1, damping = 0..1, wet = 0..1 }
function reverb.zone(zone)
  reverb.zones[#reverb.zones + 1] = zone
  table.sort(reverb.zones, function(a, b) return a.radius < b.radius end)
end

function reverb.at(position)
  for _, z in ipairs(reverb.zones) do
    local dx, dy, dz = position[1] - z.center[1], position[2] - z.center[2], position[3] - z.center[3]
    if dx * dx + dy * dy + dz * dz <= z.radius * z.radius then return z end
  end
  return reverb.default
end

-- Applies the zone at the listener's position when it differs from the last one.
function reverb.update(position)
  local z = reverb.at(position)
  if z ~= reverb.current then
    fk.audio.reverb({ room = z.room, damping = z.damping, wet = z.wet })
    reverb.current = z
  end
  return z
end

return reverb
