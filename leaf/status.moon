
textbox = require "wibox.widget.textbox"
awful = require "awful"

make_status = (timeout=60) ->
  w = textbox!
  t = with timer(:timeout)
    \connect_signal "timeout", ->
      running = awful.util.pread("ps x | grep selfspy | grep python2")\match "%S"
      w\set_markup "[selfspy: #{running and "ON" or "OFF"}] "

    \start!
    \emit_signal "timeout"
  w

{ :make_status }
