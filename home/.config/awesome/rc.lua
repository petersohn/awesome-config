local D = require("debug_util")
D.log(D.info, "-----------------------------------")
D.log(D.info, "Awesome starting up")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")


math.randomseed(os.time())

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    D.notify_error({ title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        D.notify_error({
            title = "Oops, an error happened!",
            text = tostring(err),
            destroy = function(reason)
                if reason == naughty.notificationClosedReason.
                        dismissedByUser then
                    local stream = io.popen("xsel --input --clipboard", "w")
                    stream:write(tostring(err))
                    stream:close()
                end
            end})
        in_error = false
    end)
end
-- }}}

local hotkeys_popup = require("awful.hotkeys_popup").widget
local xrandr = require("xrandr")
local multimonitor = require("multimonitor")
local variables = require("variables")
local command = require("command")
local compton = require("compton")
local async = require("async")
local widgets = require("widgets")
local cyclefocus = require('cyclefocus')
local input = require('input')
local locker = require('locker')
local pulseaudio = require("apw/pulseaudio")
require("safe_restart")
local lgi = require("lgi")
local power = require("power")
local rex = require("rex_pcre")
local wallpaper = require("wallpaper")
local tresorit = require("tresorit")

-- {{{ Variable definitions

-- Themes define colours, icons, font and wallpapers.
local theme = dofile(awful.util.get_themes_dir() .. "default/theme.lua")

theme.titlebar_bg_focus = "#007EE6"
theme.apw_show_text = true
theme.apw_notify = true
theme.battery_widget_popup_position = "bottom_right"
theme.memory_widget_popup_placement = function(w)
    return awful.placement.bottom_right(w,
            { margins = {bottom = 25, right = 10}})
end

beautiful.init(theme)

wallpaper.init()

local modkey = variables.modkey

local APW = require("apw/widget")
local battery_widget = require("awesome-wm-widgets.battery-widget.battery")
local cpu_widget = require("awesome-wm-widgets.cpu-widget.cpu-widget")
local ram_widget = require("awesome-wm-widgets.ram-widget.ram-widget")


local last_started_client = nil

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier,
    awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Menu
-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", wallpaper.set_wallpaper)

local launcher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = widgets.main_menu })

local local_widgets_file = variables.config_dir .. "/widgets.local.lua"
if gears.filesystem.file_readable(local_widgets_file) then
    local_widgets = dofile(local_widgets_file)
else
    local_widgets = {}
end

awful.screen.connect_for_each_screen(function(s)
    D.log(D.debug, "Got screen: " .. multimonitor.get_screen_name(s))
    -- Wallpaper
    wallpaper.set_wallpaper(s)

    -- Each screen has its own tag table.
    awful.tag({"1", "2"}, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, widgets.taglist_buttons)

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, widgets.tasklist_buttons)

    -- s.mytasklist:connect_signal("mouse::enter",
    --         function(c)
    --             c:raise()
    --         end)
    -- s.mytasklist:connect_signal("mouse::leave",
    --         function(_)
    --             client.focus:raise()
    --         end)
    -- Create the wibox
    s.mywibox = awful.wibar({ position = "bottom", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            launcher,
            tresorit.widget,
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist, -- Middle widget
        gears.table.join(
            { -- Right widgets
                layout = wibox.layout.fixed.horizontal,
                widgets.keyboard_layout_switcher.widget,
                APW,
                widgets.systray_widget,
                battery_widget,
                cpu_widget,
                ram_widget,
            }, local_widgets,
            {
                widgets.text_clock,
                s.mylayoutbox,
            }),
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev),
    awful.button({ }, 6, APW.Down),
    awful.button({ }, 7, APW.Up)
))
-- }}}

-- {{{ Key bindings

local globalkeys = awful.util.table.join(root.keys(),
    awful.key({modkey, }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({}, "XF86Sleep", power.suspend,
              {description = "sleep", group = "awesome"}),
    awful.key({modkey, "Control"}, "s", power.suspend,
              {description = "sleep", group = "awesome"}),
    awful.key({}, "XF86PowerOff", power.power_menu,
        {description = "power menu", group = "awesome"}),
    -- awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
    --           {description = "view previous", group = "tag"}),
    -- awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
    --           {description = "view next", group = "tag"}),
    awful.key({ modkey, }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey, "Mod1"}, "Up",
        function() compton.increase_opacity(0.05) end,
        {description = "Increase inactive window opacity",
            group = "compositor"}),
    awful.key({ modkey, "Mod1"}, "Down",
            function() compton.decrease_opacity(0.05) end,
            {description = "Decrease inactive window opacity",
                group = "compositor"}),
    awful.key({modkey}, "F5", compton.toggle,
        {description = "Toggle compositor", group = "compositor"}),
    awful.key({ modkey, "Shift"}, "F5", compton.toggle_transparency,
        {description = "Toggle inactive window transparency",
            group = "compositor"}),

    awful.key({ modkey, "Shift"}, "j",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey, "Control"}, "v",
        function ()
            awful.spawn.with_shell(
                'sleep 0.5; xdotool type --delay 100 "$(xsel --clipboard)"')
        end,
        {description = "Force paste", group = "input"}
    ),
    awful.key({ modkey, "Shift"}, "k",
        function ()
            awful.client.focus.byidx(1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey, "Shift"   }, "s", multimonitor.show_screens,
              {description = "show screens", group = "screen"}),
    awful.key({ modkey, }, "F1",
            function()
                local c = client.focus
                naughty.notify({text=
                        D.print_property(c, "name") .. "\n"
                        .. D.print_property(c, "type") .. "\n"
                        .. D.print_property(c, "class") .. "\n"
                        .. D.print_property(c, "role") .. "\n"
                        .. D.print_property(c, "window") .. "\n"
                        .. D.print_property(c, "pid") .. "\n"
                        .. D.print_property(c, "x") .. "\n"
                        .. D.print_property(c, "y") .. "\n"
                        .. D.print_property(c, "width") .. "\n"
                        .. D.print_property(c, "height") .. "\n"
                        .. D.print_property(c, "fullscreen") .. "\n"
                        .. D.print_property(c, "maximized"),
                        timeout=30})
            end,
              {description = "print debug info", group = "client"}),
    awful.key({ modkey, }, "F2", multimonitor.print_debug_info,
              {description = "print debug info", group = "screen"}),
    awful.key({modkey, "Shift"}, "t",
            function()
                multimonitor.set_system_tray_position()
            end,
            {description = "Put system tray to this screen", group="screen"}),

    -- Layout manipulation
    awful.key({ modkey, }, "Right", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, }, "Left", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "k",
            function ()
                awful.screen.focus(awful.screen.focused()
                        :get_next_in_direction("right"))
            end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "j",
            function ()
                awful.screen.focus(awful.screen.focused()
                        :get_next_in_direction("left"))
            end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey, "Shift"   }, "x",
          function()
              awful.spawn(variables.screen_configurator)
          end,
          {description = "Show screen configurator", group = "screen"}),
    awful.key({ modkey, }, "l",
          function()
              locker.lock()
          end,
          {description = "Lock session", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),

-- Standard program
    awful.key({ modkey,           }, "Return",
            function ()
                awful.spawn(variables.terminal)
            end,
            {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey,           }, "b",
            function ()
                awful.spawn(variables.browser)
            end,
            {description = "open a browser", group = "launcher"}),
    awful.key({ modkey, "Control" }, "p",
            function ()
                awful.spawn(variables.password_manager)
            end,
            {description = "open password manager", group = "launcher"}),
    awful.key({}, "Print",
            function ()
                awful.spawn(variables.screenshot_tool, true,
                        function(c) client.focus = c end)
            end,
            {description = "Take screenshot", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", power.quit,
              {description = "quit awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "r", power.reboot,
              {description = "reboot", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "p", power.poweroff,
              {description = "power off", group = "awesome"}),

    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                      client.focus = c
                      c:raise()
                  end
              end,
              {description = "restore minimized", group = "client"}),

    --- Volume
    awful.key({ }, "XF86AudioRaiseVolume",  APW.Up,
            {description="Volume Up", group="volume"}),
    awful.key({ }, "XF86AudioLowerVolume",  APW.Down,
            {description="Volume Down", group="volume"}),
    awful.key({ }, "XF86AudioMute",         APW.ToggleMute,
            {description="Toggle Mute", group="volume"}),

    --- Brightness
    awful.key({ }, "XF86MonBrightnessUp",
            function() multimonitor.increase_brightness(0.1) end,
            {description="Increase brightness", group="screen"}),
    awful.key({ }, "XF86MonBrightnessDown",
            function() multimonitor.increase_brightness(-0.1) end,
            {description="Decrease brightness", group="screen"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"}),
    awful.key({modkey, "Shift"}, "l", widgets.keyboard_layout_switcher.switch,
            {description="switch keyboard layout", group="input"}),
    awful.key({}, "XF86TouchpadToggle",
            function()
                input.toggle_device(input.touchpad)
            end,
            {description="toggle touchpad", group="input"}),
    awful.key({modkey}, "F4",
            function()
                input.toggle_device(input.touchpad)
            end,
            {description="toggle touchpad", group="input"}),

    awful.key({modkey}, "Tab",
            function()
                if last_started_client then
                    client.focus = last_started_client
                    last_started_client:raise()
                end
            end,
            {description="focus last started client", group="client"}),
    awful.key({modkey}, "F6",
            function()
                for _, c in pairs(client.get()) do
                    c.sticky = false
                end
            end,
            {description="focus last started client", group="client"})
)

local function has_no_transient(target)
    for _, c in pairs(client.get()) do
        if c.transient_for == target then
            return false
        end
    end
    return true
end

local clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ "Mod1"   }, "F4",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey, }, "k",
            function (c)
                multimonitor.move_to_screen(
                        c, c.screen:get_next_in_direction("right"))
            end,
            {description = "move to previous screen", group = "client"}),
    awful.key({ modkey, }, "j",
            function (c)
                multimonitor.move_to_screen(
                        c, c.screen:get_next_in_direction("left"))
            end,
            {description = "move to next screen", group = "client"}),
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
        {description = "maximize", group = "client"}),
    awful.key({ "Mod1",         }, "Tab", function(c)
        cyclefocus.cycle(1, {
                modifier="Alt_L",
                cycle_filters={cyclefocus.filters.same_screen, has_no_transient},
                initiating_client=c
            })
    end),
    awful.key({ "Mod1", "Shift" }, "Tab", function(c)
        cyclefocus.cycle(-1, {
                modifier="Alt_L",
                cycle_filters={cyclefocus.filters.same_screen, has_no_transient},
                initiating_client=c
            })
    end),

    awful.key({ modkey, "Control" }, "Left", function(c)
        c.x = c.x - 10
    end,
    {description="Move left", group="client"}),
    awful.key({ modkey, "Control" }, "Right", function(c)
        c.x = c.x + 10
    end,
    {description="Move right", group="client"}),
    awful.key({ modkey, "Control" }, "Up", function(c)
        c.y = c.y - 10
    end,
    {description="Move up", group="client"}),
    awful.key({ modkey, "Control" }, "Down", function(c)
        c.y = c.y + 10
    end,
    {description="Move down", group="client"}),

    awful.key({ modkey, "Control", "Shift" }, "Left", function(c)
        c.x = c.x - 1
    end,
    {description="Move left slowly", group="client"}),
    awful.key({ modkey, "Control", "Shift" }, "Right", function(c)
        c.x = c.x + 1
    end,
    {description="Move right", group="client"}),
    awful.key({ modkey, "Control", "Shift" }, "Up", function(c)
        c.y = c.y - 1
    end,
    {description="Move up slowly", group="client"}),
    awful.key({ modkey, "Control", "Shift" }, "Down", function(c)
        c.y = c.y + 1
    end,
    {description="Move down slowly", group="client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 2 do
    globalkeys = awful.util.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

local clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize),
    awful.button({ }, 6, APW.Down),
    awful.button({ }, 7, APW.Up))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    {
        rule = { },
            properties={
                border_width=beautiful.border_width,
                border_color=beautiful.border_normal,
                raise=true,
                focus=false,
                keys=clientkeys,
                buttons=clientbuttons,
                screen=awful.screen.preferred,
                placement=awful.placement.centered
           }
    },

    {
        rule_any={
            class={"Gnome-terminal", "konsole", "XTerm"}
        },
        properties={
            focus=true,
            placement=awful.placement.no_overlap + awful.placement.no_offscreen
        }
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
        },
        class = {
          "Arandr",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Wpa_gui",
          "pinentry",
          "veromix",
          "xtightvncviewer"},

        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup and
      not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = awful.util.table.join(
        awful.button({ }, 1, function()
            client.focus = c
            c:raise()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            client.focus = c
            c:raise()
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
        and awful.client.focus.filter(c) then
        client.focus = c
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)

client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
client.connect_signal("unfocus",
        function(c)
            if not c.minimized then
                return
            end
            gears.timer.start_new(0.1,
                    function()
                        local target = mouse.current_client
                        if target == c then
                            return true
                        end
                        if target then
                            client.focus = target
                        end
                        return false
                    end)
        end)

client_status = {}

client.connect_signal("unfocus",
        function(c)
            client_status[c.window] = {fullscreen=c.fullscreen}
        end)

client.connect_signal("focus",
        function(c)
            status = client_status[c.window]
            if status then
                c.fullscreen = status.fullscreen
            end
        end)

client.connect_signal("unmanage",
        function(c)
            client_status[c.window] = nil
        end)

screen.connect_signal("list",
        function()
            D.log(D.info, "Screen configuration changed")
            multimonitor.detect_screens()
        end)

client.connect_signal("manage",
        function(c)
            D.log(D.debug, "New client: " .. D.get_client_debug_info(c))
            last_started_client = c

            if c.maximized then
                c.maximized = false
                c.maximized = true
            end

            if client.focus and c.pid == client.focus.pid then
                client.focus = c
            end
        end)

client.connect_signal("unmanage",
        function(c)
            if last_started_client == c then
                last_started_client = nil
            end
        end)

local fullscreen_idle_prevention = false

local function has_visible_fullscreen_client()
    for s in screen do
        for _, t in ipairs(s.selected_tags) do
            for _, c in ipairs(t:clients()) do
                if c.valid and c.fullscreen then
                    return true
                end
            end
        end
    end
    return false
end

local function check_fullscreen()
    local has_fullscreen = has_visible_fullscreen_client()
    if has_fullscreen and not fullscreen_idle_prevention then
        locker.prevent_idle:lock()
        fullscreen_idle_prevention = true
    elseif not has_fullscreen and fullscreen_idle_prevention then
        locker.prevent_idle:unlock()
        fullscreen_idle_prevention = false
    end
end

client.connect_signal("manage", check_fullscreen)
client.connect_signal("unmanage", check_fullscreen)
client.connect_signal("property::size", check_fullscreen)
client.connect_signal("property::position", check_fullscreen)

awesome.connect_signal("startup",
        function()
            command.start_if_not_running(variables.clipboard_manager, "")
        end)


-- }}}

local APWTimer = timer({ timeout = 0.5 }) -- set update interval in s
APWTimer:connect_signal("timeout", APW.Update)
APWTimer:start()

local apw_tooltip = awful.tooltip({
        objects={APW},
        delay_show=1,
        timer_function=function()
            local p = pulseaudio:Create()
            p:UpdateState()
            return tostring(math.floor(p.Volume * 100 + 0.5)) .. "%"
        end})

local local_rc_file = variables.config_dir .. "/rc.local.lua"
if gears.filesystem.file_readable(local_rc_file) then
    dofile(local_rc_file)
end

locker.init(require("xautolock"), {
    locker="xsecurelock --",
    notifier="/usr/libexec/xsecurelock/until_nonidle " ..
        "/usr/libexec/xsecurelock/dimmer",
    lock_time=15,   -- minutes
    blank_time=30,  -- minutes
    notify_time=30  -- seconds
})

-- locker.init(require("xscreensaver"))

naughty.config.notify_callback = function(args)
    if args.icon_size == nil or args.icon_size > 64 then
        args.icon_size = 64
    end
    return args
end

local battery_info = {}
local acpi_command = command.get_available_command({{
    command="acpi",
    test="acpi",
}})
D.log(D.info, "ACPI=" .. tostring(acpi_command))
local battery_timer = nil

if not acpi_command then
    D.log(D.warning, "ACPI is not supported.")
else
    battery_timer = gears.timer({
        timeout=60,
        autostart=true,
        call_now=true,
        callback=function()
            async.spawn_and_get_lines(acpi_command, {
                line=function(line)
                    local name, status, level = rex.match(line,
                        "^([^:]+): (\\w+), (\\d+)%")
                    if not name then
                        D.log(D.debug, "Bad battery info: " .. line)
                        return
                    end
                    D.log(D.debug, "Battery info: " .. name .. ", " ..
                        status .. ", " .. level .. "%")
                    local prev_level = nil
                    if not battery_info[name] then
                        D.log(D.info, "Found battery: " .. name)
                        prev_level = 0
                    else
                        prev_level = battery_info[name].level
                    end
                    local new_level = tonumber(level)
                    local preset = nil
                    if prev_level > 50 and new_level <= 50 then
                        preset = naughty.config.presets.info
                    elseif prev_level > 25 and new_level <= 25 then
                        preset = naughty.config.presets.warn
                    elseif prev_level > 10 and new_level <= 10 then
                        preset = naughty.config.presets.critical
                    end
                    if preset then
                        naughty.notify{
                            title=name,
                            text="Battery level: " .. level,
                            preset=preset,
                        }
                    end
                    battery_info[name] = {
                        level=new_level,
                    }
                end})
        end,
    })
end

D.log(D.info, "Initialization finished")
