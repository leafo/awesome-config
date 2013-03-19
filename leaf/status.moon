
textbox = require "wibox.widget.textbox"
awful = require "awful"
naughty = require "naughty"

make_status = (timeout=60) ->
  w = textbox!

  check_running = ->
    awful.util.pread("ps x | grep selfspy")\match "python2"

  run = ->
    naughty.notify text: "Starting selfspy..."
    awful.util.spawn_with_shell "selfspy.py -c /home/leafo/.selfspy.conf"

  t = with timer(:timeout)
    \connect_signal "timeout", ->
      w\set_markup "[selfspy: #{check_running! and "ON" or "OFF"}] "

    \start!
    \emit_signal "timeout"

  w\connect_signal "button::press", ->
    -- run! unless check_running!
    naughty.notify text: "running: #{check_running!}"
    t\emit_signal "timeout"

  w

{ :make_status }
