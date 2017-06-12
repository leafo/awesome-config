
textbox = require "wibox.widget.textbox"
awful = require "awful"
naughty = require "naughty"


local hamster_text, selfwatch_text, refresh_hamster

refresh = ->
  refresh_hamster() if refresh_hamster

make_selfwatch_textbox = (timeout=60) ->
  return selfwatch_text if selfwatch_text

  w = textbox!

  check_running = (fn) ->
    awful.spawn.easy_async "pidof selfwatch", (stdout, stderr, reason, code) ->
      fn code == 0

  get_status = (fn) ->
    awful.spawn.easy_async "selfwatch -config /home/leafo/.selfwatch/selfwatch.json status", (stdout, stderr, reason, code) ->
      fn stdout

  t = with timer(:timeout)
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

make_hamster_textbox = (timeout=30) ->
  return hamster_text if hamster_text

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

  hamster_text = w
  w

{ :make_selfwatch_textbox, :make_hamster_textbox, :refresh }
