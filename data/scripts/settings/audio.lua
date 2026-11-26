-- Audio settings (audio spec): music and effects volumes, saved with fk.storage.
local store = require("settings.store")

local audio = {}

audio.CHOICES = { music = { 1, 0.75, 0.5, 0.25, 0 }, effects = { 1, 0.75, 0.5, 0.25, 0 } }

function audio.defaults() return { music = 0.75, effects = 1 } end

audio.current = audio.defaults()

function audio.apply()
  fk.audio.volume("music", audio.current.music)
  for _, bus in ipairs({ "sfx", "ui", "ambient" }) do fk.audio.volume(bus, audio.current.effects) end
end

function audio.load()
  audio.current = store.load("audio", audio.defaults(), audio.CHOICES)
  audio.apply()
  return audio.current
end

function audio.save()
  fk.storage.save("audio", store.encode(audio.current, audio.CHOICES))
  audio.apply()
end

return audio
