-- Comfort settings (effects spec): camera shake, light flashes, rumble, head bob, field of view and the turning vignette. Saved with
-- fk.storage; `comfort.current` is what the effects read.
local store = require("settings.store")

local comfort = {}

comfort.CHOICES = {
  shake = { 1, 0.5, 0 },
  flashes = { 1, 0.5, 0 },
  rumble = { true, false },
  head_bob = { 1, 0.5, 0 },
  fov = { 70, 80, 90, 60 },
  vignette = { true, false },
}

function comfort.defaults() return { shake = 1, flashes = 1, rumble = true, head_bob = 1, fov = 70, vignette = true } end

comfort.current = comfort.defaults()

function comfort.load()
  comfort.current = store.load("comfort", comfort.defaults(), comfort.CHOICES)
  return comfort.current
end

function comfort.save() fk.storage.save("comfort", store.encode(comfort.current, comfort.CHOICES)) end

return comfort
