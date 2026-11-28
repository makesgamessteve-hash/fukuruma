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
  colour_vision = { "normal", "protanopia", "deuteranopia", "tritanopia" },
}

function comfort.defaults()
  return { shake = 1, flashes = 1, rumble = true, head_bob = 1, fov = 70, vignette = true, colour_vision = "normal" }
end

-- Colour vision (accessibility spec): daltonisation. Each deficiency's simulation S (Machado, Oliveira and Fernandes
-- 2009, full severity, linear RGB, rows) loses some differences; c + D (c - S c) moves what was lost into channels
-- that are still seen. Returns the 3x3 matrix I + D (I - S), column-major, or nil for normal vision.
local SIMULATE = {
  protanopia = { { 0.152286, 1.052583, -0.204868 }, { 0.114503, 0.786281, 0.099216 }, { -0.003882, -0.048116, 1.051998 } },
  deuteranopia = { { 0.367322, 0.860646, -0.227968 }, { 0.280085, 0.672501, 0.047413 }, { -0.011820, 0.042940, 0.968881 } },
  tritanopia = { { 1.255528, -0.076749, -0.178779 }, { -0.078411, 0.930809, 0.147602 }, { 0.004733, 0.691367, 0.303900 } },
}
local SHIFT = { red_green = { { 0, 0, 0 }, { 0.7, 1, 0 }, { 0.7, 0, 1 } }, blue = { { 1, 0, 0.7 }, { 0, 1, 0.7 }, { 0, 0, 0 } } }

function comfort.colour_matrix(kind)
  local s = SIMULATE[kind]
  if not s then return nil end
  local d = kind == "tritanopia" and SHIFT.blue or SHIFT.red_green
  local m = {}
  for col = 1, 3 do
    for row = 1, 3 do
      local v = row == col and 1 or 0
      for k = 1, 3 do v = v + d[row][k] * ((k == col and 1 or 0) - s[k][col]) end
      m[(col - 1) * 3 + row] = v
    end
  end
  return m
end

comfort.current = comfort.defaults()

-- Sets what the renderer needs from the comfort settings: the colour vision matrix.
function comfort.apply()
  fk.gfx.colour(comfort.colour_matrix(comfort.current.colour_vision) or { 1, 0, 0, 0, 1, 0, 0, 0, 1 })
end

function comfort.load()
  comfort.current = store.load("comfort", comfort.defaults(), comfort.CHOICES)
  comfort.apply()
  return comfort.current
end

function comfort.save() fk.storage.save("comfort", store.encode(comfort.current, comfort.CHOICES)) end

return comfort
