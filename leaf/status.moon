
textbox = require "wibox.widget.textbox"
awful = require "awful"
gears = require "gears"
naughty = require "naughty"

local selfwatch_text

make_selfwatch_textbox = (timeout=60) ->
  return selfwatch_text if selfwatch_text

  w = textbox!

  check_running = (fn) ->
    awful.spawn.easy_async "pidof selfwatch", (stdout, stderr, reason, code) ->
      fn code == 0

  get_status = (fn) ->
    awful.spawn.easy_async "selfwatch status", (stdout, stderr, reason, code) ->
      fn stdout

  t = with gears.timer(:timeout)
    \connect_signal "timeout", ->
      check_running (running) ->
        if running
          get_status (status) ->
            w\set_markup '<span color="#B7CE42">✓ ' .. status .. '</span> '
        else
          w\set_markup '<span color="#F00060">✕ SW</span> '

    \start!
    \emit_signal "timeout"

  w\connect_signal "button::press", ->
    t\emit_signal "timeout"

  selfwatch_text = w
  w

{ :make_selfwatch_textbox }
