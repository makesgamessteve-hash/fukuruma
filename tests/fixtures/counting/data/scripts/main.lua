local counter = require("counter")
local function count(name) counter[name] = counter[name] + 1; counter.order[#counter.order + 1] = name end
return {
  init = function() count("init") end,
  input = function() count("input") end,
  tick = function() count("tick") end,
  draw = function(alpha) assert(alpha == 1, "headless frames draw the current tick"); count("draw") end,
}
