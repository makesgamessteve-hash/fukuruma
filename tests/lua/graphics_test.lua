-- settings.graphics (graphics-settings spec): levels, Custom, device defaults, storing.
local graphics = require("settings.graphics")

local desktop = { renderer = "AMD Radeon RX 7800", web = false, phone = false }

return {
  ["device defaults"] = function()
    assert(graphics.default_level({ renderer = "llvmpipe (LLVM 20.1, 256 bits)", web = false, phone = false }) == "low")
    assert(graphics.default_level({ renderer = "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device))", web = true, phone = false }) == "low")
    assert(graphics.default_level({ renderer = "Adreno (TM) 740", web = true, phone = true }) == "low")
    assert(graphics.default_level({ renderer = "WebKit WebGL", web = true, phone = false }) == "medium")
    assert(graphics.default_level(desktop) == "high")
    assert(graphics.default_level({ renderer = "none", web = false, phone = false }) == "low")
  end,
  ["levels differ in light, shadows and effects"] = function()
    local s = graphics.defaults(desktop)
    graphics.set_level(s, "low")
    assert(s.shadows == 1 and s.ao == 0 and s.aa == "none")
    graphics.set_level(s, "ultra")
    assert(s.shadows == 4 and s.ao == 16 and s.aa == "ssaa" and s.level == "ultra")
  end,
  ["custom keeps the rest"] = function()
    local s = graphics.defaults(desktop)
    graphics.set(s, "shadows", 1)
    assert(s.level == "custom" and s.ao == 10 and s.lights == 16 and s.aa == "taa")
    graphics.set(s, "palette", true) -- not a level option: the level stays
    assert(s.level == "custom")
  end,
  ["encode and decode"] = function()
    local s = graphics.defaults(desktop)
    s.palette, s.resolution = true, "sharp"
    local back = graphics.decode(graphics.encode(s), graphics.defaults(desktop))
    for key in pairs(graphics.CHOICES) do assert(back[key] == s[key], key) end
    local ignored = graphics.decode("level=extreme\nao=7\nnonsense=1\nfill=false\n", graphics.defaults(desktop))
    assert(ignored.level == "high" and ignored.ao == 10 and ignored.fill == false)
  end,
  ["load stores the defaults the first time"] = function()
    fk.storage.save("graphics", "") -- (other tests may have started the game, which stores its settings)
    local first = graphics.load(desktop)
    assert(first.level == "high" and fk.storage.load("graphics"))
    first.level = "ultra"
    graphics.save(first)
    assert(graphics.load(desktop).level == "ultra")
  end,
  ["apply configures the renderer"] = function()
    local s = graphics.defaults(desktop)
    s.palette, s.aa = true, "ssaa"
    graphics.apply(s)
    local settings = fk.gfx.settings()
    assert(settings.supersample == 2 and settings.taa == false and settings.shadow_cascades == 3)
    s.palette, s.aa = false, "taa"
    graphics.apply(s)
    assert(fk.gfx.settings().taa and fk.gfx.settings().supersample == 1)
  end,
}
