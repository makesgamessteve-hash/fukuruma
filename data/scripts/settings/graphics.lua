-- Graphics detail levels and options (graphics-settings spec). The levels change light, shadows and
-- effects; every level renders the same models. Saved with fk.storage as "key=value" lines.
local store = require("settings.store")

local graphics = {}

graphics.ORDER = { "low", "medium", "high", "ultra" }

-- The rows a level controls. Changing one of them by hand makes the level "custom".
local PRESETS = {
  low = { shadows = 1, shadow_size = 1024, ao = 0, lights = 4, aa = "none", particles = 1000, terrain = 24, plants = 0.3, material = 1, reach = 2e4 },
  medium = { shadows = 2, shadow_size = 1024, ao = 6, lights = 8, aa = "taa", particles = 3000, terrain = 6, plants = 0.6, material = 2, reach = 2e5 },
  high = { shadows = 3, shadow_size = 2048, ao = 10, lights = 16, aa = "taa", particles = 6000, terrain = 4, plants = 1, material = 3, reach = false },
  ultra = { shadows = 4, shadow_size = 2048, ao = 16, lights = 32, aa = "ssaa", particles = 12000, terrain = 3, plants = 1.5, material = 3, reach = false },
}

-- Allowed values of every stored setting.
graphics.CHOICES = {
  level = { "low", "medium", "high", "ultra", "custom" },
  resolution = { "classic", "sharp", "fine" },
  shadows = { 0, 1, 2, 3, 4 },
  shadow_size = { 1024, 2048 },
  ao = { 0, 6, 10, 16 },
  lights = { 4, 8, 16, 32 },
  aa = { "none", "taa", "ssaa" },
  particles = { 1000, 3000, 6000, 12000 },
  terrain = { 24, 6, 4, 3 }, -- the most internal pixels a terrain quad may span before it splits
  plants = { 0.3, 0.6, 1, 1.5 }, -- the share of the flora and rocks drawn
  material = { 1, 2, 3 }, -- the terrain material: layers only, with detail, with bumps
  reach = { 2e4, 2e5, false }, -- how far the ground is drawn (metres; false: to the horizon)
  fill = { true, false },
  dither = { true, false },
  palette = { false, true },
}

graphics.RESOLUTIONS = {
  classic = { width = 480, height = 270 },
  sharp = { width = 640, height = 360 },
  fine = { width = 960, height = 540 },
}

-- 32 colours for the palette mode: dusk, rust, steel and signal tones.
graphics.PALETTE = {
  { 0.04, 0.04, 0.08 }, { 0.1, 0.1, 0.18 }, { 0.18, 0.2, 0.32 }, { 0.28, 0.32, 0.5 }, { 0.4, 0.48, 0.7 },
  { 0.58, 0.68, 0.86 }, { 0.82, 0.88, 0.96 }, { 1, 1, 1 }, { 0.16, 0.08, 0.06 }, { 0.3, 0.14, 0.08 },
  { 0.46, 0.22, 0.1 }, { 0.62, 0.32, 0.14 }, { 0.78, 0.46, 0.2 }, { 0.9, 0.62, 0.3 }, { 0.98, 0.8, 0.5 },
  { 1, 0.94, 0.76 }, { 0.22, 0.2, 0.18 }, { 0.36, 0.33, 0.3 }, { 0.52, 0.48, 0.44 }, { 0.68, 0.64, 0.6 },
  { 0.12, 0.22, 0.14 }, { 0.22, 0.4, 0.22 }, { 0.4, 0.6, 0.3 }, { 0.66, 0.8, 0.42 }, { 0.5, 0.08, 0.1 },
  { 0.8, 0.16, 0.14 }, { 1, 0.4, 0.22 }, { 1, 0.78, 0.2 }, { 0.06, 0.26, 0.36 }, { 0.12, 0.5, 0.6 },
  { 0.4, 0.8, 0.84 }, { 0.6, 0.3, 0.6 },
}

local function index_of(list, value)
  for i, v in ipairs(list) do
    if v == value then return i end
  end
end

-- Software renderers, phones and runs without a GPU start on Low, desktop browsers on Medium, the rest on High.
function graphics.default_level(device)
  local renderer = device.renderer:lower()
  if renderer == "none" then return "low" end
  for _, software in ipairs({ "llvmpipe", "swiftshader", "softpipe", "basic render" }) do
    if renderer:find(software, 1, true) then return "low" end
  end
  if device.phone then return "low" end
  return device.web and "medium" or "high"
end

function graphics.set_level(state, level)
  for key, value in pairs(PRESETS[level]) do state[key] = value end
  state.level = level
end

-- Changes one option; options that a level controls turn the level into "custom".
function graphics.set(state, key, value)
  state[key] = value
  if PRESETS.low[key] ~= nil then state.level = "custom" end
end

function graphics.defaults(device)
  local state = { resolution = "classic", fill = true, dither = true, palette = false }
  graphics.set_level(state, graphics.default_level(device))
  return state
end

function graphics.apply(state)
  local resolution = graphics.RESOLUTIONS[state.resolution]
  fk.gfx.configure({
    width = resolution.width, height = resolution.height, fill = state.fill,
    supersample = state.aa == "ssaa" and 2 or 1, taa = state.aa == "taa",
    shadow_cascades = state.shadows, shadow_size = state.shadow_size, ao_samples = state.ao,
    max_lights = state.lights, max_particles = state.particles, dither = state.dither,
  })
  fk.gfx.palette(state.palette and graphics.PALETTE or nil)
  require("planet_view").PIXELS = state.terrain or 4
  require("scatter").density = state.plants or 1
  local planet_view = require("planet_view")
  planet_view.MATERIAL = state.material or 3
  planet_view.REACH = state.reach or nil -- false: to the horizon
  planet_view.MAX_LEVEL = state.reach == 2e4 and 14 or state.reach == 2e5 and 19 or 20
end

function graphics.encode(state) return store.encode(state, graphics.CHOICES) end
function graphics.decode(text, base) return store.decode(text, base, graphics.CHOICES) end
function graphics.save(state) fk.storage.save("graphics", graphics.encode(state)) end
function graphics.load(device) return store.load("graphics", graphics.defaults(device), graphics.CHOICES) end

graphics.index_of = index_of
return graphics
