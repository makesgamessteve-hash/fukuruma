-- weather.lua (weather spec): spells, looks, falling particles, lightning, sound.
local weather = require("weather")

local wet_world = { ocean = true }

return {
  ["spells come and go, the same for the same world and time"] = function()
    local kinds = weather.kinds(wet_world, { pressure = 1 }, false)
    assert(#kinds == 4)
    local k1, s1 = weather.at(5, kinds, 3000)
    local k2, s2 = weather.at(5, kinds, 3000)
    assert(k1 == k2 and s1 == s2)
    local _, rising = weather.at(5, { "rain" }, 10)
    local _, full = weather.at(5, { "rain" }, weather.SPELL / 2)
    local _, falling = weather.at(5, { "rain" }, weather.SPELL - 10)
    assert(rising < 0.2 and full == 1 and falling < 0.2)
    assert(select(2, weather.at(5, { "clear" }, weather.SPELL / 2)) == 0)
  end,
  ["each kind has its look"] = function()
    assert(weather.look("rain", 1).wet == 1 and weather.look("storm", 1).cover > weather.look("rain", 1).cover)
    assert(weather.look("snow", 0.5).snow == 0.5 and weather.look("snow", 1).fog.density > 0)
    assert(weather.look("sandstorm", 1).dust == 1)
    assert(weather.look("clear", 0).cover == 0)
  end,
  ["rain, snow and sand fall around the eye"] = function()
    assert(weather.fall("rain", 1, { 0, 0, 0 }, { 1, 0 }, 0.1, 1) > 0)
    assert(weather.fall("sandstorm", 1, { 0, 0, 0 }, { 1, 0 }, 0.1, 1) > 0)
    assert(weather.fall("clear", 1, { 0, 0, 0 }, { 1, 0 }, 0.1, 1) == 0)
    assert(weather.fall("rain", 0, { 0, 0, 0 }, { 1, 0 }, 0.1, 1) == 0)
    assert(weather.fall("snow", 1, { 0, 0, 0 }, { 1, 0 }, 0.0001, 1) == 0, "too little time for a flake")
  end,
  ["storms throw lightning, and the thunder follows"] = function()
    local found
    for i = 0, 2000 do
      local at = weather.strike(9, "storm", 1, i / 2)
      if at then found = i / 2 break end
    end
    assert(found, "a strike now and then")
    assert(weather.strike(9, "rain", 1, found) == nil and weather.strike(9, "storm", 0.2, found) == nil)
    local state = {}
    local ctx = { seed = 9, desc = wet_world, air = { pressure = 1 }, cold = false, t = found, dt = 0.016, eye = { 0, 0, 0 },
      wind = { 1, 0 }, share = 0.1 }
    -- a storm spell needs the kinds to say storm: force it through a world whose only kind is storm
    local kinds = weather.kinds
    weather.kinds = function() return { "storm" } end
    ctx.t = weather.SPELL / 2 + (found % weather.SPELL) * 0 -- the spell's height
    local w
    for i = 0, 4000 do -- run until a strike in this spell
      ctx.t = weather.SPELL * 0.5 + i / 2
      w = weather.present(state, ctx)
      if w.flash == 1 then break end
    end
    assert(w.flash == 1 and w.kind == "storm" and state.voice ~= nil, "a flash, and the rain's sound")
    ctx.dt = 30
    weather.present(state, ctx) -- the thunder arrives
    assert(state.thunder_in == nil)
    weather.kinds = function() return { "clear" } end
    w = weather.present(state, ctx)
    assert(w.kind == "clear" and state.voice == nil, "the sound stops with the weather")
    weather.kinds = kinds
    assert(weather.kinds(wet_world, nil, false)[1] == "clear")
    assert(weather.kinds({}, { pressure = 1 }, false)[2] == "sandstorm")
    assert(weather.kinds({}, { pressure = 1 }, true)[2] == "snow")
  end,
}
