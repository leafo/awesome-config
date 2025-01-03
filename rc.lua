-- vim: shiftwidth=4:tabstop=4:softtabstop=4:expandtab
-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")

unpack = unpack or table.unpack

-- custom widgets
local status = require("leaf.status")

local hotkeys_popup = require("awful.hotkeys_popup").widget

naughty.config.defaults.font = "Terminus 12"
naughty.config.defaults.icon_size = 32

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({
        preset = naughty.config.presets.critical,
        title = "Oops, there were errors during startup!",
        text = awesome.startup_errors
    })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = err })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions

-- load theme
beautiful.init("/home/leafo/.config/awesome/themes/niceandclean/theme.lua")

local function notify(msg)
    awful.util.spawn("notify-send " .. ("%q"):format(msg))
end

local function print(...)
    local flat = {}
    for _, arg in ipairs{...} do
        table.insert(flat, tostring(arg))
    end

    notify(table.concat(flat, "\t"))
end

local function dmenu_colors()
    return "-nb '" ..  beautiful.bg_normal ..
        "' -nf '" .. beautiful.fg_normal ..
        "' -sb '" .. beautiful.bg_focus ..
        "' -sf '" .. beautiful.fg_focus ..
        "' -fn 'Terminus-20' "
end

-- This is used later as the default terminal and editor to run.
local terminal = "urxvt"
local editor = os.getenv("EDITOR") or "vim"
local editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.

local modkey = "Mod4"
local other_modkey = "Mod1"

-- swap if laptop
if os.getenv("LAPTOP") then
    modkey, other_modkey = other_modkey, modkey
end

os.execute"setxkbmap -option ctrl:nocaps"
-- os.execute"/home/leafo/bin/selfspy.py -c /home/leafo/.selfspy.conf"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.tile,
    -- awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    -- awful.layout.suit.tile.top,
    -- awful.layout.suit.fair,
    -- awful.layout.suit.fair.horizontal,
    -- awful.layout.suit.spiral,
    -- awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    -- awful.layout.suit.max.fullscreen,
    awful.layout.suit.floating,
    -- awful.layout.suit.magnifier
}
-- }}}

-- {{{ Tags shared on all screens
local layout_pairs = {
    {"www", awful.layout.suit.max},
    {"dev"},
    {"term"},
    {"music"},
    {"float", awful.layout.suit.floating},
}
-- }}}

-- {{{ Menu
-- Create a laucher widget and a main menu
local myawesomemenu = {
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end }
}

local mymainmenu = awful.menu({
    items = {
        { "awesome", myawesomemenu, beautiful.awesome_icon },
        { "terminal", terminal },
        { "thunar", "thunar" }
    }
})

-- awesome logo on top left of screen
local mylauncher = awful.widget.launcher({
    image = beautiful.awesome_icon,
    menu = mymainmenu
})

-- {{{ Wibox
-- Create a textclock widget
local mytextclock = awful.widget.textclock()

-- Create a wibox for each screen and add it
local taglist_buttons = awful.util.table.join(
    awful.button({ }, 1, awful.tag.viewonly),
    awful.button({ modkey }, 1, awful.client.movetotag),
    awful.button({ }, 3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, awful.client.toggletag),
    awful.button({ }, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
    awful.button({ }, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
)


local function client_menu_toggle_fn()
    local instance = nil

    return function()
        if instance and instance.wibox.visible then
            instance:hide()
            instance = nil
        else
            instance = awful.menu.clients({ theme = { width = 400 } })
        end
    end
end

local tasklist_buttons = awful.util.table.join(
    awful.button({ }, 1, function (c)
        if c == client.focus then
            c.minimized = true
        else
            c.minimized = false
            if not c:isvisible() then
                awful.tag.viewonly(c:tags()[1])
            end
            -- This will also un-minimize
            -- the client, if needed
            client.focus = c
            c:raise()
        end
    end),
    awful.button({ }, 3, client_menu_toggle_fn()),
    awful.button({ }, 4, function ()
        awful.client.focus.byidx(1)
        if client.focus then client.focus:raise() end
    end),
    awful.button({ }, 5, function ()
        awful.client.focus.byidx(-1)
        if client.focus then client.focus:raise() end
    end)
)


--  screen steup
awful.screen.connect_for_each_screen(function(s)
    -- setup wallapper
    if beautiful.wallpaper then
        local kind = beautiful.wallpaper_type or "maximized"
        gears.wallpaper[kind](beautiful.wallpaper, s, unpack(beautiful.wallpaper_args or {}))
    end

    -- create tags on each screen
    local default_layout = awful.layout.layouts[1]

    local name_list, layout_list = {}, {}
    for _, item in pairs(layout_pairs) do
        table.insert(name_list, item[1])
        table.insert(layout_list, item[2] or default_layout)
    end

    awful.tag(name_list, s, layout_list)

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons)

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, tasklist_buttons)

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            -- mykeyboardlayout, -- not used, but new in aweseome 4
            wibox.widget.systray(),
            mytextclock,

            -- custom widget
            status.make_selfwatch_textbox(),

            s.mylayoutbox,
        },
    }
end)
-- }}}


-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
local globalkeys = awful.util.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end, {
            description = "focus next by index", group = "client"
        }),

    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end, {
        description = "focus previous by index", group = "client"
        }),

    -- music stuff
    awful.key({ modkey, "Shift" }, "Left", function()
        awful.util.spawn("mpc toggle")
    end, {
        description = "mpc toggle",
        group = "music"
    }),

    awful.key({ }, "Pause", function()
        awful.util.spawn("mpc toggle")
    end, {
        description = "mpc toggle",
        group = "music"
    }),

    awful.key({ modkey }, "Up", function()
        awful.util.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%")
    end, {
        description = "volume up",
        group = "music"
    }),

    awful.key({ modkey }, "Down", function()
        awful.util.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%")
    end, {
        description = "volume down",
        group = "music"
    }),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n", function ()
          local c = awful.client.restore()
          -- Focus restored client
          if c then
              client.focus = c
              c:raise()
          end
      end, {
          description = "restore minimized",
          group = "client"
      }),

    awful.key({ modkey }, "p", function ()
        awful.util.spawn("hamster-dmenu")
    end, {
        description = "set task in hamster",
        group = "dmenu"
    }),

    -- Prompt
    awful.key({ modkey }, "r", function ()
        awful.util.spawn("dmenu_run -i -p 'Run command:' " .. dmenu_colors())
    end, {
        description = "run prompt",
        group = "dmenu"
    }),

    awful.key({ modkey }, "o", function ()
        awful.util.spawn_with_shell([[wmctrl -l | dmenu -i -l 20 ]] .. dmenu_colors() .. [[ | sed -e 's/.*\(0x[^ ]\+\).*/\1/g' | xargs wmctrl -ia]])
    end, {
        description = "go to window by name",
        group = "dmenu"
    }),

    awful.key({ modkey }, "x", function ()
        awful.prompt.run {
            prompt       = "Run Lua code: ",
            textbox      = awful.screen.focused().mypromptbox.widget,
            exe_callback = awful.util.eval,
            history_path = awful.util.get_cache_dir() .. "/history_eval"
        }
    end, {
        description = "lua execute prompt",
        group = "awesome"
    })
)

local clientkeys = awful.util.table.join(
    awful.key({ modkey }, "d", awful.placement.under_mouse, {
        description = "place under mouse",
        group = "client"
    }),

    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    -- awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
    --           {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "maximize", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, #layout_pairs do
    globalkeys = awful.util.table.join(globalkeys,
        -- view tag only
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end),
        -- toggle tag
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end),
        -- move client to tag
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end),
        -- toggle tag on focused client
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end))
end

local clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     keys = clientkeys,
                     buttons = clientbuttons } },

    { rule = { class = "MPlayer" },
      properties = { floating = true } },
    { rule = { class = "pinentry" },
      properties = { floating = true } },
    { rule = { class = "gimp" },
      properties = { floating = true } },

    { rule = { class = "Conky" },
      properties = {
          border_width = 0,
          focusable = false,
          below = true,
          sticky = true,
      } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    if awesome.startup and
      not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    else
        -- make sure new windows are visible on the screen
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)

-- Enable sloppy focus
client.connect_signal("mouse::enter", function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
        and awful.client.focus.filter(c) then
        client.focus = c
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}
