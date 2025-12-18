local textbox = require("wibox.widget.textbox")
local awful = require("awful")
local naughty = require("naughty")
local hamster_text, selfwatch_text, refresh_hamster
local refresh
refresh = function()
  if refresh_hamster then
    return refresh_hamster()
  end
end
local make_selfwatch_textbox
make_selfwatch_textbox = function(timeout)
  if timeout == nil then
    timeout = 60
  end
  if selfwatch_text then
    return selfwatch_text
  end
  local w = textbox()
  local check_running
  check_running = function(fn)
    return awful.spawn.easy_async("pidof selfwatch", function(stdout, stderr, reason, code)
      return fn(code == 0)
    end)
  end
  local get_status
  get_status = function(fn)
    return awful.spawn.easy_async("selfwatch status", function(stdout, stderr, reason, code)
      return fn(stdout)
    end)
  end
  local t
  do
    local _with_0 = timer({
      timeout = timeout
    })
    _with_0:connect_signal("timeout", function()
      return check_running(function(running)
        if running then
          return get_status(function(status)
            return w:set_markup('<span color="#B7CE42">✓ ' .. status .. '</span> ')
          end)
        else
          return w:set_markup('<span color="#F00060">✕ SW</span> ')
        end
      end)
    end)
    _with_0:start()
    _with_0:emit_signal("timeout")
    t = _with_0
  end
  w:connect_signal("button::press", function()
    return t:emit_signal("timeout")
  end)
  selfwatch_text = w
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
  make_selfwatch_textbox = make_selfwatch_textbox,
  make_hamster_textbox = make_hamster_textbox,
  refresh = refresh
}
