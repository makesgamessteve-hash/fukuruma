return {
  ["fails"] = function() error("expected failure") end,
  ["not a function"] = 5,
  [1] = "ignored: not a named test",
}
