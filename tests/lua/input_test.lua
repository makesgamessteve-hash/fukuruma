-- fk.input without a window: idle state and errors for unknown names.
return {
  ["idle state"] = function()
    assert(fk.input.key("W") == false and fk.input.axis("leftx") == 0 and fk.input.button("a") == false)
    assert(fk.input.mouse_button(1) == false and #fk.input.touches() == 0)
    local x, y, dx, dy = fk.input.mouse()
    assert(x == 0 and y == 0 and dx == 0 and dy == 0)
    assert(fk.input.device() == "keyboard")
  end,
  ["unknown names are errors"] = function()
    local ok, err = pcall(fk.input.key, "NoSuchKey")
    assert(not ok and err:find("unknown key 'NoSuchKey'", 1, true))
    assert(not pcall(fk.input.axis, "wobble"))
    assert(not pcall(fk.input.button, "turbo"))
  end,
}
