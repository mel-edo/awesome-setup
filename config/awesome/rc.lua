-- awesome_mode: api-level=4:screen=on
-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

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
-- Declarative object management
local ruled = require("ruled")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

local dpi = beautiful.xresources.apply_dpi

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
naughty.connect_signal("request::display_error", function(message, startup)
  naughty.notification {
    urgency = "critical",
    title   = "Oops, an error happened" .. (startup and " during startup!" or "!"),
    message = message
  }
end)
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init("/home/meledo/.config/awesome/theme-def.lua")

-- This is used later as the default terminal and editor to run.
terminal = "alacritty"
editor = os.getenv("EDITOR") or "nvim"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"
-- }}}

-- {{{ Tag layout
-- Table of layouts to cover with awful.layout.inc, order matters.
tag.connect_signal("request::default_layouts", function()
  awful.layout.append_default_layouts({
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.floating,
  })
end)
-- }}}

-- {{{ Wallpaper
screen.connect_signal("request::wallpaper", function(s)
  awful.wallpaper {
    screen = s,
    widget = {
      {
        image     = beautiful.wallpaper,
        upscale   = true,
        downscale = true,
        widget    = wibox.widget.imagebox,
      },
      valign = "center",
      halign = "center",
      tiled  = false,
      widget = wibox.container.tile,
    }
  }
end)
-- }}}

-- {{{ Tags
screen.connect_signal("request::desktop_decoration", function(s)
  -- Each screen has its own tag table.
  local names = { "1", "2", "3", "4", "5" }
  local l = awful.layout.suit
  local layouts = { l.spiral.dwindle, l.spiral.dwindle, l.spiral.dwindle, l.spiral.dwindle, l.floating }
  awful.tag(names, s, layouts)
end)
-- }}}

-- {{{ Mouse bindings
awful.mouse.append_global_mousebindings({
  awful.button({}, 4, awful.tag.viewprev),
  awful.button({}, 5, awful.tag.viewnext),
})
-- }}}

-- {{{ Calendar widget
local calendar_widget = require("calendar")
local cw = calendar_widget({
  theme = 'catppuccin',
  placement = 'top center',
  start_sunday = false,
  radius = 8,
})
-- }}}

-- {{{ Key bindings

-- General Awesome keys
awful.keyboard.append_global_keybindings({
  awful.key({ modkey, }, "s", hotkeys_popup.show_help,
    { description = "show help", group = "awesome" }),
  awful.key({ modkey, "Control" }, "r", awesome.restart,
    { description = "reload awesome", group = "awesome" }),
  awful.key({ modkey, "Shift" }, "q", awesome.quit,
    { description = "quit awesome", group = "awesome" }),
  awful.key({ modkey, }, "Return", function() awful.spawn(terminal) end,
    { description = "open a terminal", group = "launcher" }),

  awful.key({}, "XF86AudioRaiseVolume", function() awful.spawn.with_shell("pactl set-sink-volume @DEFAULT_SINK@ +5%") end),

  awful.key({}, "F6", function() awful.util.spawn("playerctl play-pause", false) end),

  awful.key({}, "F8", function() awful.util.spawn("playerctl next", false) end),

  awful.key({}, "F7", function() awful.util.spawn("playerctl previous", false) end),

  awful.key({}, "XF86AudioLowerVolume", function() awful.spawn.with_shell("pactl set-sink-volume @DEFAULT_SINK@ -5%") end),

  awful.key({}, "XF86MonBrightnessDown", function() awful.util.spawn("brightnessctl s 10%-") end),

  awful.key({}, "XF86MonBrightnessUp", function() awful.util.spawn("brightnessctl s +10%") end),

})

-- Tags related keybindings
awful.keyboard.append_global_keybindings({
  awful.key({ modkey, }, "Left", awful.tag.viewprev,
    { description = "view previous", group = "tag" }),
  awful.key({ modkey, }, "Right", awful.tag.viewnext,
    { description = "view next", group = "tag" }),
  awful.key({ modkey, }, "Escape", awful.tag.history.restore,
    { description = "go back", group = "tag" }),
})

-- Focus related keybindings
awful.keyboard.append_global_keybindings({
  awful.key({ "Mod1", }, "Tab",
    function()
      awful.client.focus.byidx(1)
    end,
    { description = "focus next by index", group = "client" }
  ),
  awful.key({ modkey, "Control" }, "j", function() awful.screen.focus_relative(1) end,
    { description = "focus the next screen", group = "screen" }),
  awful.key({ modkey, "Control" }, "k", function() awful.screen.focus_relative(-1) end,
    { description = "focus the previous screen", group = "screen" }),
  awful.key({ modkey, "Control" }, "n",
    function()
      local c = awful.client.restore()
      -- Focus restored client
      if c then
        c:activate { raise = true, context = "key.unminimize" }
      end
    end,
    { description = "restore minimized", group = "client" }),
})

-- Layout related keybindings
awful.keyboard.append_global_keybindings({
  awful.key({ modkey, "Shift" }, "j", function() awful.client.swap.byidx(1) end,
    { description = "swap with next client by index", group = "client" }),
  awful.key({ modkey, "Shift" }, "k", function() awful.client.swap.byidx(-1) end,
    { description = "swap with previous client by index", group = "client" }),
  awful.key({ modkey, }, "u", awful.client.urgent.jumpto,
    { description = "jump to urgent client", group = "client" }),
  awful.key({ modkey, }, "l", function() awful.tag.incmwfact(0.05) end,
    { description = "increase master width factor", group = "layout" }),
  awful.key({ modkey, }, "h", function() awful.tag.incmwfact(-0.05) end,
    { description = "decrease master width factor", group = "layout" }),
  awful.key({ modkey, "Shift" }, "h", function() awful.tag.incnmaster(1, nil, true) end,
    { description = "increase the number of master clients", group = "layout" }),
  awful.key({ modkey, "Shift" }, "l", function() awful.tag.incnmaster(-1, nil, true) end,
    { description = "decrease the number of master clients", group = "layout" }),
  awful.key({ modkey, "Control" }, "h", function() awful.tag.incncol(1, nil, true) end,
    { description = "increase the number of columns", group = "layout" }),
  awful.key({ modkey, "Control" }, "l", function() awful.tag.incncol(-1, nil, true) end,
    { description = "decrease the number of columns", group = "layout" }),
  awful.key({ modkey, }, "space", function() awful.layout.inc(1) end,
    { description = "select next", group = "layout" }),
  awful.key({ modkey, "Shift" }, "space", function() awful.layout.inc(-1) end,
    { description = "select previous", group = "layout" }),

  -- Prompt
  awful.key({ modkey }, "a", function()
    awful.spawn.with_shell("sh ~/.config/rofi/launchers/type-6/launcher.sh")
  end,
    { description = "run rofi apps", group = "launcher" }),

  awful.key({ modkey }, "r", function()
    awful.spawn.with_shell("sh ~/.config/rofi/launchers/type-6/launcher2.sh")
  end,
    { description = "run rofi programs", group = "launcher" }),

  awful.key({ modkey }, "w", function()
    awful.spawn.with_shell("sh ~/.config/rofi/launchers/type-6/launcher1.sh")
  end,
    { description = "run rofi windows", group = "launcher" }),

  awful.key({ modkey }, "e", function()
    awful.spawn.with_shell("nemo")
  end,
    { description = "run nemo", group = "launcher" }),

  awful.key({ modkey }, "`", function()
    awful.spawn.with_shell("sh ~/.config/rofi/powermenu/type-6/powermenu.sh")
  end,
    { description = "power options", group = "awesome" }),

  awful.key({ modkey }, "c", function()
    cw.toggle()
  end,
    { description = "calendar popup", group = "launcher" }),

  awful.key({}, "F4", function()
    awful.spawn.with_shell("flameshot gui")
  end,
    { description = "run flameshot", group = "launcher" }),

  awful.key({ modkey }, "p", function()
    awful.spawn.with_shell("scrcpy -S --power-off-on-close --window-x 10")
  end,
    { description = "run scrcpy", group = "launcher" }),


  awful.key({ modkey }, "z", function()
    awful.spawn.with_shell("sh ~/.config/awesome/kpolybar.sh")
  end,
    { description = "kill polybar", group = "launcher" }),

  awful.key({ modkey }, "x", function()
    awful.spawn.with_shell("sh ~/.config/awesome/spolybar.sh")
  end,
    { description = "run polybar", group = "launcher" })
})

awful.keyboard.append_global_keybindings({
  awful.key {
    modifiers   = { modkey },
    keygroup    = "numrow",
    description = "only view tag",
    group       = "tag",
    on_press    = function(index)
      local screen = awful.screen.focused()
      local tag = screen.tags[index]
      if tag then
        tag:view_only()
      end
    end,
  },
  awful.key {
    modifiers   = { modkey, "Shift" },
    keygroup    = "numrow",
    description = "move focused client to tag",
    group       = "tag",
    on_press    = function(index)
      if client.focus then
        local tag = client.focus.screen.tags[index]
        if tag then
          client.focus:move_to_tag(tag)
        end
      end
    end,
  }
})

client.connect_signal("request::default_mousebindings", function()
  awful.mouse.append_client_mousebindings({
    awful.button({}, 1, function(c)
      c:activate { context = "mouse_click" }
    end),
    awful.button({ modkey }, 1, function(c)
      c:activate { context = "mouse_click", action = "mouse_move" }
    end),
    awful.button({ modkey }, 3, function(c)
      c:activate { context = "mouse_click", action = "mouse_resize" }
    end),
  })
end)

client.connect_signal("request::default_keybindings", function()
  awful.keyboard.append_client_keybindings({
    awful.key({ modkey, }, "f",
      function(c)
        c.fullscreen = not c.fullscreen
        c:raise()
      end,
      { description = "toggle fullscreen", group = "client" }),
    awful.key({ modkey }, "q", function(c) c:kill() end,
      { description = "close", group = "client" }),
    awful.key({ "Control" }, "space",
      function(c)
        awful.client.floating.toggle(c)
        c.width = 1000
        c.height = 550
        awful.placement.centered(c)
      end,
      { description = "toggle floating", group = "client" }),
    awful.key({ modkey, "Control" }, "Return", function(c) c:swap(awful.client.getmaster()) end,
      { description = "move to master", group = "client" }),
    awful.key({ modkey, }, "o", function(c) c:move_to_screen() end,
      { description = "move to screen", group = "client" }),
    awful.key({ modkey, }, "t", function(c) c.ontop = not c.ontop end,
      { description = "toggle keep on top", group = "client" }),
    awful.key({ modkey, }, "n",
      function(c)
        -- The client currently has the input focus, so it cannot be
        -- minimized, since minimized clients can't have the focus.
        c.minimized = true
      end,
      { description = "minimize", group = "client" }),
    awful.key({ modkey, }, "m",
      function(c)
        c.maximized = not c.maximized
        c:raise()
      end,
      { description = "(un)maximize", group = "client" }),
    awful.key({ modkey, "Control" }, "m",
      function(c)
        c.maximized_vertical = not c.maximized_vertical
        c:raise()
      end,
      { description = "(un)maximize vertically", group = "client" }),
    awful.key({ modkey, "Shift" }, "m",
      function(c)
        c.maximized_horizontal = not c.maximized_horizontal
        c:raise()
      end,
      { description = "(un)maximize horizontally", group = "client" }),
  })
end)

-- }}}

-- {{{ Rules
-- Rules to apply to new clients.
ruled.client.connect_signal("request::rules", function()
  -- All clients will match this rule.
  ruled.client.append_rule {
    id         = "global",
    rule       = {},
    properties = {
      focus     = awful.client.focus.filter,
      raise     = true,
      screen    = awful.screen.preferred,
      placement = awful.placement.no_overlap + awful.placement.no_offscreen
    }
  }

  -- Floating clients.
  ruled.client.append_rule {
    id         = "floating",
    rule_any   = {
      instance = { "copyq", "pinentry" },
      class    = {
        "Arandr", "Blueman-manager", "Gpick", "Kruler", "Sxiv",
        "Tor Browser", "Wpa_gui", "veromix", "xtightvncviewer"
      },
      -- Note that the name property shown in xprop might be set slightly after creation of the client
      -- and the name shown there might not match defined rules here.
      name     = {
        "Event Tester", -- xev.
      },
      role     = {
        "AlarmWindow", -- Thunderbird's calendar.
        "ConfigManager", -- Thunderbird's about:config.
        "pop-up", -- e.g. Google Chrome's (detached) Developer Tools.
      }
    },
    properties = { floating = true }
  }

  -- Add titlebars to normal clients and dialogs
  ruled.client.append_rule {
    id         = "titlebars",
    rule_any   = { type = { "normal", "dialog" } },
    properties = { titlebars_enabled = false }
  }

  -- Set Firefox to always map on the tag named "1" on screen 1.
  ruled.client.append_rule {
    rule_any   = {
      class = { "firefox" }
    },
    properties = { screen = 1, tag = "1", border_width = 0 }
  }
  ruled.client.append_rule {
    rule       = { instance = "discord" },
    properties = { screen = 1, tag = "2" }
  }
  ruled.client.append_rule {
    rule_any   = {
      instance = { "youtube music" }
    },
    properties = { screen = 1, tag = "3" }
  }
  ruled.client.append_rule {
    rule       = { instance = "vscodium" },
    properties = { screen = 1, tag = "4" }
  }
  ruled.client.append_rule {
    rule       = { instance = "feh" },
    properties = { floating = true }
  }
  ruled.client.append_rule {
    rule       = { instance = "nm-connection-editor" },
    properties = { floating = true }
  }

  ruled.client.append_rule {
    rule       = { instance = "scrcpy" },
    properties = { floating = true }
  }
  ruled.client.append_rule {
    rule       = { instance = "polybar" },
    properties = { border_width = 0 }
  }
end)
-- }}}

-- {{{ Notifications

naughty.config.defaults.ontop = true
naughty.config.defaults.screen = awful.screen.focused()
naughty.config.defaults.timeout = 4
naughty.config.defaults.title = "Notification"
naughty.config.defaults.position = "top_right"
naughty.config.defaults.border_width = 0
beautiful.notification_spacing = 16

local function create_notif(n)
  local icon_visibility

  if n.icon == nil then
    icon_visibility = false
  else
    icon_visibility = true
  end

  -- Action widget
  local action_widget = {
    {
      {
        id = "text_role",
        align = "center",
        font = "Product Sans 10",
        widget = wibox.widget.textbox,
      },
      margins = { left = dpi(3), right = dpi(3) },
      widget = wibox.container.margin,
    },
    widget = wibox.container.background,
  }

  -- Apply action widget ^
  local actions = wibox.widget {
    notification = n,
    base_layout = wibox.widget {
      spacing = dpi(20),
      layout = wibox.layout.flex.horizontal,
    },
    widget_template = action_widget,
    widget = naughty.list.actions,
  }

  local function space_h(length, circumstances)
    return wibox.widget {
      forced_width = length,
      visible = circumstances,
      layout = wibox.layout.fixed.horizontal,
    }
  end

  -- Make other widgets
  local title = wibox.widget.textbox()
  title.font = "Product Sans Bold 12"
  title.align = 'center'
  title.markup = n.title

  local message = wibox.widget.textbox()
  message.font = "Product Sans 12"
  message.align = 'left'
  message.markup = n.message

  local icon = wibox.widget {
    nil,
    {
      {
        image = n.icon,
        visible = icon_visibility,
        widget = wibox.widget.imagebox,
      },
      strategy = "max",
      width = dpi(115),
      height = dpi(115),
      widget = wibox.container.constraint,
    },
    expand = 'none',
    layout = wibox.layout.align.vertical,
  }

  local container = wibox.widget {
    {
      title,
      {
        icon,
        space_h(dpi(25), icon_visibility),
        message,
        layout = wibox.layout.fixed.horizontal,
      },
      actions,
      spacing = dpi(20),
      layout = wibox.layout.fixed.vertical,
    },
    margins = dpi(15),
    widget = wibox.container.margin,
  }

  naughty.layout.box {
    notification = n,
    type = "notification",
    bg = beautiful.bg,
    border_width = 0,
    shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 5) end,
    widget_template = {
      {
        {
          {
            widget = container,
          },
          strategy = "max",
          width = dpi(300),
          height = dpi(200),
          widget = wibox.container.constraint,
        },
        strategy = "min",
        width = dpi(300),
        height = dpi(130),
        widget = wibox.container.constraint,
      },
      bg = beautiful.bg,
      widget = wibox.container.background,
    }
  }
end

naughty.connect_signal("request::display", function(n)
  create_notif(n)
end)

ruled.notification.connect_signal("request::rules", function()
  ruled.notification.append_rule {
    rule = {},
    properties = {
      screen = awful.screen.focused(),
      implicit_timeout = 4,
    }
  }
end)

-- }}}

-- Autostart

awful.spawn.with_shell("sh ~/.fehbg")
awful.spawn.with_shell("sh ~/.config/awesome/autorun.sh")

-- Garbage collection

collectgarbage("setpause", 110)
collectgarbage("setstepmul", 1000)
gears.timer({
  timeout = 5,
  autostart = true,
  call_now = true,
  callback = function()
    collectgarbage("collect")
  end,
})
