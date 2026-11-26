return scenario { run = function(t) t.frames(2); t.frames(); t.expect(true, "fine"); t.screenshot("skipped") end }
