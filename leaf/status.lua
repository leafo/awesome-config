local textbox = require("wibox.widget.textbox")
local awful = require("awful")
local make_status
make_status = function(timeout)
  if timeout == nil then
    timeout = 60
  end
  local w = textbox()
  local t
  do
    local _with_0 = timer({
      timeout = timeout
    })
    _with_0:connect_signal("timeout", function()
      local running = awful.util.pread("ps x | grep selfspy | grep python2"):match("%S")
      return w:set_markup("[selfspy: " .. tostring(running and "ON" or "OFF") .. "] ")
    end)
    _with_0:start()
    _with_0:emit_signal("timeout")
    t = _with_0
  end
  return w
end
return {
  make_status = make_status
}
