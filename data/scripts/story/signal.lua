-- The first thread of the mystery (story-threads spec): "The Signal". A woken artifact hums with a signal from another
-- star; there, the signal grows stronger; that star's ruin answers it. Steps: {id, text (the ship AI's line, %s: the
-- thread's star), when(ctx) (true: the step is done), on(ctx) (what then happens)}. ctx: {state (the thread's own
-- table), world, system, solved (whether the current world's ruin is solved)}.
return {
  id = "the_signal",
  name = "THE SIGNAL",
  steps = {
    { id = "listen", text = "THE ARTIFACT HUMS. A SIGNAL, FROM STAR %s.",
      when = function(ctx) return ctx.solved end,
      on = function(ctx) ctx.state.star = ctx.pick_star() end },
    { id = "follow", text = "THE SIGNAL IS STRONG HERE. ITS SOURCE IS IN THE RUINS OF STAR %s.",
      when = function(ctx) return ctx.state.star and ctx.system == ctx.state.star.seed end },
    { id = "answer", text = "THE RUIN ANSWERS THE SIGNAL. SOMETHING, FAR AWAY, HAS HEARD.",
      when = function(ctx) return ctx.system == ctx.state.star.seed and ctx.solved end,
      on = function(ctx) ctx.reward("exotic", 2) end },
  },
}
