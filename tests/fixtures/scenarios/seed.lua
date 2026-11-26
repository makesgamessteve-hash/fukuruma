return scenario { seed = 42, run = function(t) t.expect(fk.seed() == 42, "seed from the scenario") end }
