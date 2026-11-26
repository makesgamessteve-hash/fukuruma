-- menu.lua: every row of the graphics menu changes the settings and saves them. Raw input is faked.
local menu = require("menu")
local graphics = require("settings.graphics")

local real = fk.input
local keys = {}
local fake = {
  key = function(k) return keys[k] == true end,
  button = function() return false end,
  axis = function() return 0 end,
  mouse = function() return 0, 0, 0, 0 end,
  mouse_button = function() return false end,
  touches = function() return {} end,
  device = function() return "keyboard" end,
}

local function tap(state, key)
  keys[key] = true; menu.draw(state)
  keys[key] = nil; menu.draw(state)
end

return {
  ["every row changes and saves the settings"] = function()
    fk.input = fake
    local ok, err = pcall(function()
      local state = graphics.defaults({ renderer = "x", web = false, phone = false }) -- High
      menu.draw(state) -- closed: draws nothing
      menu.toggle()
      assert(menu.open)
      tap(state, "Right"); assert(state.level == "ultra")
      tap(state, "Down"); tap(state, "Right"); assert(state.resolution == "sharp")
      tap(state, "Down"); tap(state, "Right"); assert(state.fill == false)
      tap(state, "Down"); tap(state, "Left"); assert(state.aa == "taa" and state.level == "custom")
      tap(state, "Up"); tap(state, "Up"); tap(state, "Up"); tap(state, "Right")
      assert(state.level == "low", "Custom steps on to the first level")
      for _ = 1, 4 do tap(state, "Down") end
      tap(state, "Right"); assert(state.shadows == 2)
      tap(state, "Down"); tap(state, "Right"); assert(state.shadow_size == 2048)
      tap(state, "Down"); tap(state, "Right"); assert(state.ao == 6)
      tap(state, "Down"); tap(state, "Right"); assert(state.lights == 8)
      tap(state, "Down"); tap(state, "Right"); assert(state.dither == false)
      tap(state, "Down"); tap(state, "Right"); assert(state.palette == true)
      assert(graphics.decode(fk.storage.load("graphics"), {}).palette == true, "saved")
      tap(state, "Down"); tap(state, "Return"); assert(not menu.open, "Close")
      menu.toggle()
      tap(state, "Escape"); assert(not menu.open, "Escape closes")
      graphics.apply(graphics.defaults({ renderer = "none", web = false, phone = false }))
    end)
    fk.input = real
    keys = {}
    assert(ok, err)
  end,
}
