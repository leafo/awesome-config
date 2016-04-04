local textbox = require("wibox.widget.textbox")
local awful = require("awful")
local naughty = require("naughty")
local hamster_text, selfspy_text, refresh_hamster
local refresh
refresh = function()
  if refresh_hamster then
    return refresh_hamster()
  end
end
local make_selfspy_textbox
make_selfspy_textbox = function(timeout)
  if timeout == nil then
    timeout = 60
  end
  if selfspy_text then
    return selfspy_text
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
      local str
      if check_running() then
        str = '<span color="#B7CE42">SP✓</span>'
      else
        str = '<span color="#F00060">SP✕</span>'
      end
      return w:set_markup(tostring(str) .. " ")
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
  selfspy_text = w
  return w
end
local make_hamster_textbox
make_hamster_textbox = function(timeout)
  if timeout == nil then
    timeout = 30
  end
  if hamster_text then
    return hamster_text
  end
  local w = textbox()
  local current_activity
  current_activity = function()
    return awful.util.pread("hamster-current"):match("[^%s]+")
  end
  refresh_hamster = function()
    local activity = current_activity()
    return w:set_markup("<span color='#777777'>[</span>" .. tostring(activity) .. "<span color='#777777'>]</span> ")
  end
  local t
  do
    local _with_0 = timer({
      timeout = timeout
    })
    _with_0:connect_signal("timeout", refresh_hamster)
    _with_0:start()
    _with_0:emit_signal("timeout")
    t = _with_0
  end
  hamster_text = w
  return w
end
return {
  make_selfspy_textbox = make_selfspy_textbox,
  make_hamster_textbox = make_hamster_textbox,
  refresh = refresh
}
