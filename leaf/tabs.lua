-- Tabbed window stacks for awesome 4.3
--
-- A stack is a group of clients that behaves like one window: only the
-- active member is shown, the rest are `hidden` (which keeps them out of the
-- tiling layout and the tasklist), and every member carries a titlebar with
-- one tab per member.
--
-- Stack membership is stored in an X property on each client so stacks
-- survive `awesome.restart()`.

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")

local tabs = {}

local XPROP = "_LEAF_TAB_GROUP"
awesome.register_xproperty(XPROP, "string")

local group_of = setmetatable({}, { __mode = "k" }) -- client -> group
local next_id = 1

local function new_group(clients)
    local g = { id = next_id, clients = clients or {}, active = nil }
    next_id = next_id + 1
    for _, c in ipairs(g.clients) do
        group_of[c] = g
    end
    return g
end

local function index_of(g, c)
    for i, m in ipairs(g.clients) do
        if m == c then return i end
    end
end

local function save(g)
    for _, c in ipairs(g.clients) do
        c:set_xproperty(XPROP, g.id .. (c == g.active and ":active" or ""))
    end
end

local function focus(c)
    c.minimized = false
    client.focus = c
    c:raise()
end

local function tab_colors(g, c)
    if c == g.active and client.focus == c then
        return beautiful.tabs_bg_focus or beautiful.bg_focus,
            beautiful.tabs_fg_focus or beautiful.fg_focus
    elseif c == g.active then
        return beautiful.tabs_bg_active or beautiful.bg_minimize or beautiful.bg_normal,
            beautiful.tabs_fg_active or beautiful.fg_normal
    end
    return beautiful.tabs_bg_normal or beautiful.bg_normal,
        beautiful.tabs_fg_normal or beautiful.fg_normal
end

local function make_tab(g, c)
    local bg, fg = tab_colors(g, c)
    local tab = wibox.widget {
        {
            {
                widget = wibox.widget.textbox,
                text = c.name or c.class or "?",
                align = "center",
                ellipsize = "end",
                font = beautiful.tabs_font,
            },
            left = 6,
            right = 6,
            widget = wibox.container.margin,
        },
        bg = bg,
        fg = fg,
        widget = wibox.container.background,
    }

    -- Clicking a background tab switches to it; dragging the front tab moves
    -- the stack. Starting a move while the layout is still settling from a
    -- switch makes tiled layouts swap the stack with its neighbour.
    tab:buttons(gears.table.join(
        awful.button({}, 1, function()
            if g.active == c then
                focus(c)
                awful.mouse.client.move(c)
            else
                tabs.activate(c)
            end
        end),
        awful.button({}, 2, function() tabs.detach(c) end),
        awful.button({}, 3, function()
            tabs.activate(c)
            awful.mouse.client.resize(c)
        end),
        awful.button({}, 4, function() tabs.cycle(c, -1) end),
        awful.button({}, 5, function() tabs.cycle(c, 1) end)
    ))
    return tab
end

-- Every member gets the same tab bar so frame sizes match when swapping.
local function render(g)
    for _, c in ipairs(g.clients) do
        local row = { layout = wibox.layout.flex.horizontal, spacing = 1 }
        for _, m in ipairs(g.clients) do
            table.insert(row, make_tab(g, m))
        end
        awful.titlebar(c, { position = "top", size = beautiful.tabs_height }):setup(row)
    end
end

-- Put `to` where `from` is: same screen, tags, floating state, geometry and
-- slot in the layout.
local function transfer(from, to, hide_from, swap)
    if to.screen ~= from.screen then
        to.screen = from.screen
    end
    local t = from:tags()
    if #t > 0 then
        to:tags(t)
    end
    to.floating = from.floating
    if from.maximized then
        to.maximized = true
    else
        to.maximized = false
        to:geometry(from:geometry())
    end
    if swap then
        to:swap(from)
    end
    to.hidden = false
    if hide_from then
        from.hidden = true
    end
end

local function release(c)
    group_of[c] = nil
    if c.valid then
        awful.titlebar.hide(c, "top")
        c:set_xproperty(XPROP, "")
        c.hidden = false
    end
end

-- Bring `c` to the front of its stack.
function tabs.activate(c)
    local g = c and group_of[c]
    if not g or not c.valid then return end

    local old = g.active
    if old ~= c then
        if old and old.valid then
            transfer(old, c, true, true)
        else
            c.hidden = false
        end
        g.active = c
    end

    focus(c)
    render(g)
    save(g)
end

-- Move `offset` tabs over from `c` (wrapping around).
function tabs.cycle(c, offset)
    local g = c and group_of[c]
    if not g then return end
    local i = index_of(g, g.active) or 1
    local n = #g.clients
    tabs.activate(g.clients[(i - 1 + offset) % n + 1])
end

-- Remove `c` from its stack. When `dying` the client is being unmanaged.
local function remove(c, dying)
    local g = group_of[c]
    if not g then return end

    local i = index_of(g, c)
    table.remove(g.clients, i)
    local was_active = g.active == c
    local front = g.active

    if was_active then
        -- The neighbouring tab takes over the stack's place.
        local nxt = g.clients[i] or g.clients[i - 1]
        g.active = nxt
        front = nxt
        if nxt and c.valid then
            transfer(c, nxt, false, not dying)
        elseif nxt then
            nxt.hidden = false
        end
    elseif not dying and front then
        -- A background tab leaves: show it next to the stack.
        c:tags(front:tags())
    end

    if dying then
        group_of[c] = nil
    else
        release(c)
    end

    if #g.clients == 1 then
        release(g.clients[1])
    end

    if #g.clients >= 2 then
        render(g)
        save(g)
    end

    if dying and was_active and front and front.valid then
        focus(front)
    end
end

-- Pull `c` out of its stack into its own window.
function tabs.detach(c)
    if not (c and group_of[c]) then return end
    remove(c, false)
    focus(c)
end

-- Pull `target` into the stack of `home` as background tabs. If `target` is
-- already in a stack, the whole stack comes along. `home` stays in front.
function tabs.pull(home, target)
    if not (home and target) or home == target then return end
    if not (home.valid and target.valid) then return end

    local g = group_of[home]
    if g and group_of[target] == g then return end

    local incoming = { target }
    local old = group_of[target]
    if old then
        incoming = old.clients
        for _, m in ipairs(incoming) do
            group_of[m] = nil
        end
    end

    if not g then
        g = new_group({ home })
        g.active = home
    end

    local front = g.active
    for _, m in ipairs(incoming) do
        table.insert(g.clients, m)
        group_of[m] = g
        transfer(front, m, false, false)
        m.hidden = true
    end

    render(g)
    save(g)
end

-- Keysyms that release each modifier.
local modifier_keys = {
    Mod4 = { Super_L = true, Super_R = true },
    Mod1 = { Alt_L = true, Alt_R = true, Meta_L = true, Meta_R = true },
}

local function has_modifier(mods, modkey)
    for _, m in ipairs(mods) do
        if m == modkey then return true end
    end
    return false
end

-- The topmost visible client under screen point (x, y).
local function client_at(x, y)
    for _, c in ipairs(client.get(nil, true)) do
        if c:isvisible() then
            local g = c:geometry()
            local bw = c.border_width or 0
            if x >= g.x and x < g.x + g.width + 2 * bw
                and y >= g.y and y < g.y + g.height + 2 * bw then
                return c
            end
        end
    end
end

-- Outline drawn around the window a group-mode click would pull in. Four
-- bars rather than one translucent overlay, since there's no compositor.
local highlight_bars

local function hide_highlight()
    for _, bar in ipairs(highlight_bars or {}) do
        bar.visible = false
    end
end

local function show_highlight(c)
    if not highlight_bars then
        highlight_bars = {}
        for i = 1, 4 do
            highlight_bars[i] = wibox {
                ontop = true,
                visible = false,
                width = 1,
                height = 1,
                bg = beautiful.tabs_highlight_color or "#b7ce42",
            }
        end
    end

    local g = c:geometry()
    local bw = c.border_width or 0
    local x, y = g.x, g.y
    local w, h = g.width + 2 * bw, g.height + 2 * bw
    local t = tonumber(beautiful.tabs_highlight_width) or 5

    local rects = {
        { x = x, y = y, width = w, height = t },
        { x = x, y = y + h - t, width = w, height = t },
        { x = x, y = y, width = t, height = h },
        { x = x + w - t, y = y, width = t, height = h },
    }
    for i, bar in ipairs(highlight_bars) do
        bar:geometry(rects[i])
        bar.visible = true
    end
end

-- Group mode: while `modkey` stays held, clicking a window pulls it into the
-- stack of `home`. Releasing `modkey` (or Escape) ends it.
function tabs.group_mode(home, modkey)
    if not home then return end
    local release_keys = modifier_keys[modkey] or modifier_keys.Mod4
    local keygrabber
    local was_pressed = false

    -- The window a click at (x, y) would pull in, if any.
    local function target_at(x, y)
        local c = client_at(x, y)
        if not c or c == home then return end
        local g = group_of[home]
        if g and group_of[c] == g then return end
        return c
    end

    local function stop()
        awful.keygrabber.stop(keygrabber)
        mousegrabber.stop()
        hide_highlight()
    end

    keygrabber = awful.keygrabber.run(function(mods, key, event)
        if event == "release" and release_keys[key] then
            stop()
        elseif event == "press" and (key == "Escape" or not has_modifier(mods, modkey)) then
            -- A press without the modifier means its release was missed.
            stop()
        end
    end)

    mousegrabber.run(function(m)
        if not home.valid then
            stop()
            return false
        end

        local target = target_at(m.x, m.y)
        local pressed = m.buttons[1]
        if pressed and not was_pressed and target then
            tabs.pull(home, target)
            -- The layout is about to reshuffle; redraw on the next motion.
            target = nil
        end
        was_pressed = pressed

        if target then
            show_highlight(target)
        else
            hide_highlight()
        end
        return true
    end, "crosshair")

    local coords = mouse.coords()
    local initial = target_at(coords.x, coords.y)
    if initial then
        show_highlight(initial)
    end
end

function tabs.client_keys(modkey)
    return gears.table.join(
        awful.key({ modkey }, "g", function(c) tabs.group_mode(c, modkey) end,
            { description = "group mode: hold mod, click windows to add as tabs", group = "tabs" }),
        awful.key({ modkey, "Shift" }, "g", tabs.detach,
            { description = "detach from stack", group = "tabs" }),
        awful.key({ modkey }, "bracketright", function(c) tabs.cycle(c, 1) end,
            { description = "next tab", group = "tabs" }),
        awful.key({ modkey }, "bracketleft", function(c) tabs.cycle(c, -1) end,
            { description = "previous tab", group = "tabs" })
    )
end

-- Something asked to activate a background tab (urgency, wmctrl, ...):
-- switch to it.
client.connect_signal("request::activate", function(c)
    local g = group_of[c]
    if g and g.active ~= c then
        tabs.activate(c)
    end
end)

client.connect_signal("unmanage", function(c)
    remove(c, true)
end)

-- Background tabs follow the front window's tags.
local function sync_tags(c)
    local g = group_of[c]
    if not (g and g.active == c) then return end
    local t = c:tags()
    -- A closing client is untagged before `unmanage`; don't strand the others.
    if #t == 0 then return end
    for _, m in ipairs(g.clients) do
        if m ~= c then
            m:tags(t)
        end
    end
end
client.connect_signal("tagged", sync_tags)
client.connect_signal("untagged", sync_tags)

local function rerender(c)
    local g = group_of[c]
    if g then render(g) end
end
client.connect_signal("focus", rerender)
client.connect_signal("unfocus", rerender)
client.connect_signal("property::name", rerender)

-- Rebuild stacks from the X property after a restart.
awesome.connect_signal("startup", function()
    local found, order = {}, {}
    for _, c in ipairs(client.get()) do
        local v = c:get_xproperty(XPROP)
        local id = v and v:match("^(%d+)")
        if id then
            if not found[id] then
                found[id] = { clients = {} }
                table.insert(order, id)
            end
            table.insert(found[id].clients, c)
            if v:find(":active", 1, true) then
                found[id].active = c
            end
        end
    end

    for _, id in ipairs(order) do
        local info = found[id]
        if #info.clients >= 2 then
            local g = new_group(info.clients)
            local front = info.active or info.clients[1]
            for _, m in ipairs(g.clients) do
                if m ~= front then
                    transfer(front, m, false, false)
                    m.hidden = true
                end
            end
            g.active = front
            render(g)
            save(g)
        else
            info.clients[1]:set_xproperty(XPROP, "")
        end
    end
end)

return tabs
