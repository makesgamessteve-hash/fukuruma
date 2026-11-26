-- audio spec: the sandbox plays wind and music, footsteps while walking and the scan sound; a scan crossfades to
-- the discovery theme; voices end on time (tests mix silently on frame time); the beacon tower's reverb zone.
return scenario {
  seed = 1,
  timeout_s = 30,
  run = function(t)
    local music, reverb = require("fk.music"), require("fk.reverb")
    t.frames(10)
    t.expect(fk.audio.track_volume("surface") > 0 and music.current == "surface", "the surface theme fades in")
    t.expect(fk.audio.active() == 1, "the wind plays")
    t.expect(reverb.current == reverb.default, "out in the open")
    t.key("W", true)
    t.frames(80)
    t.expect(fk.audio.active() >= 2, "footsteps play")
    t.expect(reverb.current ~= reverb.default and reverb.current.room == 0.85, "near the tower the sound rings")
    t.key("W", false)
    t.frames(100)
    t.expect(fk.audio.active() == 1, "the footsteps ended; the wind goes on")
    t.key("E", true)
    t.frames(1)
    t.key("E", false)
    t.frames(2)
    t.expect(music.current == "discovery" and fk.audio.active() == 2, "a scan plays its sound and the discovery theme")
    t.frames(150)
    t.expect(fk.audio.track_volume("discovery") == 1 and fk.audio.track_volume("surface") == 0, "crossfaded")
  end,
}
