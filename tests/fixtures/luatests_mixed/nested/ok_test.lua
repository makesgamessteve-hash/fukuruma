return {
  ["adds"] = function() assert(1 + 1 == 2) end,
  ["requires a game module"] = function() assert(require("mat4").identity()[1] == 1) end,
}
