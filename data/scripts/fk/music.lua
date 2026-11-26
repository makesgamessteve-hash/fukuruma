-- Music by situation (audio spec): every track loops silently in the background and the current situation's
-- track is faded in while the others fade out.
local music = { tracks = {}, current = nil }

-- tracks: { name = "music/file.ogg", ... } (48 kHz OGG Vorbis)
function music.load(tracks)
  music.tracks, music.current = {}, nil
  local names = {}
  for name in pairs(tracks) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    fk.audio.music(name, tracks[name], 0)
    music.tracks[#music.tracks + 1] = name
  end
end

-- Crossfades to the named track over `fade` seconds (default 3); nil fades everything out.
function music.play(name, fade)
  for _, track in ipairs(music.tracks) do fk.audio.fade(track, track == name and 1 or 0, fade or 3) end
  music.current = name
end

return music
