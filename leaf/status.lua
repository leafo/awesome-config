local textbox = require("wibox.widget.textbox")
local awful = require("awful")
local naughty = require("naughty")
local make_status
make_status = function(timeout)
  if timeout == nil then
    timeout = 60
  end
  local w = textbox()
  local check_running
  check_running = function()
    return awful.util.pread("ps x | grep selfspy"):match("python2")
  end
  local run
  run = function()
    naughty.notify({
      text = "Starting selfspy..."
    })
    return awful.util.spawn_with_shell("selfspy.py -c /home/leafo/.selfspy.conf")
  end
  local t
  do
    local _with_0 = timer({
      timeout = timeout
    })
    _with_0:connect_signal("timeout", function()
      return w:set_markup("[selfspy: " .. tostring(check_running() and "ON" or "OFF") .. "] ")
    end)
    _with_0:start()
    _with_0:emit_signal("timeout")
    t = _with_0
  end
  w:connect_signal("button::press", function()
    naughty.notify({
      text = "running: " .. tostring(check_running())
    })
    return t:emit_signal("timeout")
  end)
  return w
end
return {
  make_status = make_status
}
