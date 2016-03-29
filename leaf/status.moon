
textbox = require "wibox.widget.textbox"
awful = require "awful"
naughty = require "naughty"


local refresh_hamster

refresh = ->
  refresh_hamster() if refresh_hamster

make_selfspy_textbox = (timeout=60) ->
  w = textbox!

  check_running = ->
    awful.util.pread("ps x | grep selfspy")\match "python2"

  run = ->
    naughty.notify text: "Starting selfspy..."
    awful.util.spawn_with_shell "selfspy.py -c /home/leafo/.selfspy.conf"

  t = with timer(:timeout)
    \connect_signal "timeout", ->
      str = if check_running!
        '<span color="#B7CE42">SP✓</span>'
      else
        '<span color="#F00060">SP✕</span>'

      w\set_markup "#{str} "

    \start!
    \emit_signal "timeout"

  w\connect_signal "button::press", ->
    -- run! unless check_running!
    naughty.notify text: "running: #{check_running!}"
    t\emit_signal "timeout"

  w

make_hamster_textbox = (timeout=30) ->
  return nil if refresh_hamster

  w = textbox!

  current_activity = ->
    awful.util.pread("hamster-current")\match "[^%s]+"

  refresh_hamster = ->
    activity = current_activity!
    w\set_markup "<span color='#777777'>[</span>#{activity}<span color='#777777'>]</span> "

  t = with timer(:timeout)
    \connect_signal "timeout", refresh_hamster
    \start!
    \emit_signal "timeout"

  w

{ :make_selfspy_textbox, :make_hamster_textbox, :refresh }
