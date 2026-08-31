hl.monitor({
	output = "",
	mode = "1920x1080@120",
	position = "auto",
	scale = "1",
})

hl.workspace_rule({
	workspace = "1",
})

hl.workspace_rule({
	workspace = "2",
})

hl.workspace_rule({
	workspace = "3",
})

hl.workspace_rule({
	workspace = "4",
})

hl.workspace_rule({
	workspace = "5",
})

hl.workspace_rule({
	workspace = "6",
})

hl.workspace_rule({
	workspace = "7",
})

hl.workspace_rule({
	workspace = "8",
})

-- Keybinds

local mainMod = "SUPER"

local layout = "'smartgrid'"
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd("alacritty"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + M", hl.dsp.exit())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nemo"))
hl.bind(mainMod .. " + SPACE", function()
	hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
	hl.dispatch(hl.dsp.window.resize({ x = 1000, y = 550 }))
	hl.dispatch(hl.dsp.window.center())
end)
hl.bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true }))
hl.bind("ALT + Tab", hl.dsp.window.bring_to_top())
hl.bind(mainMod .. " + A", hl.dsp.global("quickshell:toggleLauncher"))
hl.bind(mainMod .. " + escape", hl.dsp.global("quickshell:togglePowerMenu"))
hl.bind(mainMod .. " + W", hl.dsp.global("quickshell:toggleOverview"))
hl.bind(
	"Next",
	hl.dsp.exec_cmd(
		'sh -c \'FILE=~/Pictures/$(date +%Y-%m-%d_%H-%M-%S).png; REGION=$(slurp) && sleep 0.1 && grim -g "$REGION" "$FILE" && wl-copy < "$FILE" && notify-send "Screenshot" "Saved and copied to clipboard"\''
	)
)
hl.bind(
	"f12",
	hl.dsp.exec_cmd(
		'sh -c \'FILE=~/Pictures/$(date +%Y-%m-%d_%H-%M-%S).png; REGION=$(slurp) && sleep 0.1 && grim -g "$REGION" "$FILE" && wl-copy < "$FILE" && notify-send "Screenshot" "Saved and copied to clipboard"\''
	)
)
hl.bind("SHIFT + Next", hl.dsp.exec_cmd("sh -c '~/.config/hypr/ocr.sh'"))
hl.bind("SHIFT + f12", hl.dsp.exec_cmd("sh -c '~/.config/hypr/ocr.sh'"))
hl.bind("SUPER + L", hl.dsp.global("quickshell:triggerSessionLock"))
hl.bind("SHIFT + ALT +  0", hl.dsp.exec_cmd("sh -c '~/.config/quickshell/mshell/scripts/gsr-toggle.sh'"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("killall qs"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("sh ~/.config/quickshell/mshell/launch.sh"))
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + s", hl.dsp.workspace.toggle_special(""))
hl.bind(mainMod .. " + SHIFT + s", hl.dsp.window.move({ workspace = "special", follow = false }))
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1, follow = false }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2, follow = false }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3, follow = false }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4, follow = false }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5, follow = false }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6, follow = false }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7, follow = false }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8, follow = false }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	mainMod .. " + Up",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	mainMod .. " + Down",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true, repeating = true })
hl.bind(mainMod .. " + Right", hl.dsp.exec_cmd("brightnessctl s 5%+"), { locked = true, repeating = true })
hl.bind(mainMod .. " + Left", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true, repeating = true })
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("Prior", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("f11", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("copyq toggle"))
hl.bind("XF86Calculator", hl.dsp.exec_cmd("galculator"), { locked = true })
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(
	mainMod .. " + mouse_down",
	hl.dsp.exec_cmd(
		"hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor | awk '/^float.*/ {print $2 + 0.5}')"
	)
)
hl.bind(
	mainMod .. " + mouse_up",
	hl.dsp.exec_cmd(
		"hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor | awk '/^float.*/ {print $2 - 0.5}')"
	)
)
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.exec_cmd("hyprctl keyword cursor:zoom_factor 1"))
hl.bind(
	mainMod .. " + mouse_down",
	hl.dsp.exec_cmd(
		"hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor | awk '/^float.*/ {print $2 + 0.5}')"
	)
)
hl.bind(
	mainMod .. " + mouse_up",
	hl.dsp.exec_cmd(
		"hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor | awk '/^float.*/ {print $2 - 0.5}')"
	)
)
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.exec_cmd("hyprctl keyword cursor:zoom_factor 1"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("/usr/local/bin/niflveil minimize"))
hl.bind(mainMod .. " + CTRL + N", hl.dsp.exec_cmd("/usr/local/bin/niflveil restore-last"))

-- Autostart

-- Env vars

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("NVD_BACKEND", "direct")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("XCURSOR_SIZE", "21")
hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")

-- Decorations and animations

hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.0 }, { 0.1, 1.0 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.1, 1.0 }, { 0.1, 1.0 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.5, 0 }, { 0.99, 0.99 } } })
hl.curve("layerOut", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.animation({
	leaf = "windowsIn",
	enabled = true,
	speed = 7,
	bezier = "winIn",
	style = "slide",
})
hl.animation({
	leaf = "windowsOut",
	enabled = true,
	speed = 3,
	bezier = "smoothOut",
	style = "slide",
})
hl.animation({
	leaf = "windowsMove",
	enabled = true,
	speed = 7,
	bezier = "winIn",
	style = "slide",
})
hl.animation({
	leaf = "workspacesIn",
	enabled = true,
	speed = 8,
	bezier = "winIn",
	style = "slide",
})
hl.animation({
	leaf = "workspacesOut",
	enabled = true,
	speed = 8,
	bezier = "winOut",
	style = "slide",
})
hl.animation({
	leaf = "layersIn",
	enabled = true,
	speed = 10,
	bezier = "winIn",
	style = "slide",
})
hl.animation({
	leaf = "layersOut",
	enabled = true,
	speed = 3,
	bezier = "layerOut",
	style = "popin 50%",
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.gesture({
	fingers = 3,
	direction = "down",
	action = function()
		hl.exec_cmd("/usr/local/bin/niflveil minimize")
	end,
})

hl.gesture({
	fingers = 3,
	direction = "up",
	action = function()
		hl.exec_cmd("/usr/local/bin/niflveil restore-last")
	end,
})

hl.gesture({
	fingers = 4,
	direction = "down",
	action = "close", -- "close" is a built-in gesture string
})

hl.gesture({
	fingers = 4,
	direction = "up",
	action = function()
		hl.exec_cmd("hyprctl dispatch global quickshell:toggleLauncher")
	end,
})

hl.window_rule({
	name = "windowrule-1",
	match = {
		class = ".*",
	},
	suppress_event = "maximize",
})

hl.window_rule({
	name = "windowrule-2",
	match = {
		class = "^$",
		title = "^$",
		xwayland = 1,
		float = 1,
		fullscreen = 0,
		pin = 0,
	},
	no_focus = true,
})

hl.window_rule({
	name = "windowrule-3",
	match = {
		class = "^(yad)$",
	},
	float = true,
	size = "1100 600",
})

hl.window_rule({
	name = "windowrule-4",
	match = {
		class = "^(xdg-desktop-portal-gtk)$",
	},
	float = true,
})

hl.window_rule({
	name = "windowrule-5",
	match = {
		class = "^(com.github.hluk.copyq)",
	},
	float = true,
	size = "1100 600",
	center = true,
	animation = "popin 90%",
})

hl.window_rule({
	name = "windowrule-6",
	match = {
		class = "^(discord)",
	},
	workspace = "2 silent",
})

hl.window_rule({
	name = "windowrule-7",
	match = {
		class = "^(zen)",
	},
	workspace = "1 silent",
})

hl.window_rule({
	name = "windowrule-8",
	match = {
		class = "^(steam)",
	},
	workspace = "4 silent",
})

hl.window_rule({
	name = "windowrule-9",
	match = {
		title = "^(Friends List)",
	},
	float = true,
})

hl.window_rule({
	name = "windowrule-10",
	match = {
		class = "^(md.obsidian.Obsidian)",
	},
	workspace = "3 silent",
})

hl.window_rule({
	name = "windowrule-11",
	match = {
		class = "^(codium)",
	},
	workspace = "4 silent",
})

hl.window_rule({
	name = "windowrule-12",
	match = {
		class = "^com.github.th-ch.youtube-music$",
	},
	workspace = "5 silent",
})

hl.window_rule({
	name = "windowrule-13",
	match = {
		title = "^(Picture-in-Picture)",
	},
	float = true,
	move = "(1280) (35)",
})

hl.layer_rule({
	name = "layerrule-1",
	match = {
		namespace = "selection",
	},
	no_anim = true,
})

hl.window_rule({
	name = "windowrule-14",
	match = {
		class = "^(nm-connection-editor)",
	},
	float = true,
	size = "1000 550",
})

hl.window_rule({
	name = "windowrule-15",
	match = {
		class = ".*pavucontrol.*",
	},
	float = true,
	size = "1260 715",
	center = true,
	workspace = "active",
})

hl.window_rule({
	name = "windowrule-16",
	match = {
		class = "^(blueberry.py)$",
	},
	size = "1100 600",
	float = true,
	center = true,
})

hl.window_rule({
	name = "windowrule-18",
	match = {
		class = "^(org.gnome.FileRoller)$",
	},
	float = true,
	size = "1100 600",
	center = true,
})

hl.window_rule({
	name = "windowrule-19",
	match = {
		class = "^(Godot)$",
	},
	float = true,
	size = "1100 600",
	center = true,
})

hl.window_rule({
	name = "windowrule-20",
	match = {
		class = "^(org.prismlauncher.PrismLauncher)$",
	},
	workspace = "6 silent",
	float = true,
	size = "1000 550",
	center = true,
})

hl.window_rule({
	name = "windowrule-21",
	match = {
		class = "^(eu.betterbird.Betterbird)$",
	},
	workspace = "7 silent",
})

hl.window_rule({
	name = "windowrule-22",
	match = {
		class = "^(twintaillauncher)$",
	},
	workspace = "6 silent",
	float = true,
	center = true,
})

hl.window_rule({
	name = "windowrule-23",
	match = {
		class = "^(org.qbittorrent.qBittorrent)$",
	},
	float = true,
	size = "1165 655",
	center = true,
})

hl.window_rule({
	name = "windowrule-24",
	match = {
		class = "^(net.lutris.Lutris)$",
	},
	workspace = "6 silent",
	float = true,
	size = "1165 655",
	center = true,
})

hl.layer_rule({
	name = "layerrule-3",
	match = {
		namespace = "quickshell:expose",
	},
	dim_around = true,
	blur = true,
})

hl.layer_rule({
	name = "layerrule-qs",
	match = {
		namespace = "^(quickshell).*",
	},
	no_anim = true,
})

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 7,
		border_size = 0,
		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
	},
	decoration = {
		rounding = 20,
		active_opacity = 1,
		inactive_opacity = 1,
		shadow = {
			enabled = true,
			color = "rgba(00000000)",
			color_inactive = "rgba(00000000)",
		},
		blur = {
			enabled = true,
			size = 3,
		},
	},
	animations = {
		enabled = true,
	},
	dwindle = {
		--pseudotile = true
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = true,
		focus_on_activate = true,
	},
	-- Input and gestures stuff
	input = {
		kb_layout = "us",
		accel_profile = "flat",
		follow_mouse = 1,
		sensitivity = 0.5,
		touchpad = {
			natural_scroll = false,
			disable_while_typing = true,
		},
	},
	cursor = {
		inactive_timeout = 3,
		hide_on_key_press = true,
	},
	gestures = {
		workspace_swipe_distance = 700,
		workspace_swipe_cancel_ratio = 0.2,
		workspace_swipe_min_speed_to_force = 5,
		workspace_swipe_direction_lock = true,
		workspace_swipe_direction_lock_threshold = 10,
		workspace_swipe_create_new = true,
	},
	-- Window rules
})

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
	hl.exec_cmd("systemctl --user start opentabletdriver")
	hl.exec_cmd("copyq")
	hl.exec_cmd("hyprsunset -t 5000")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("awww img ~/.config/hypr/wallpaper.jpg")
	hl.exec_cmd("discord")
	hl.exec_cmd("kdeconnect-indicator")
	hl.exec_cmd("zen-browser")
	hl.exec_cmd("sh ~/.config/quickshell/mshell/launch.sh")
	hl.exec_cmd('gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-mocha-dark-cursors"')
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 21")
	hl.exec_cmd("hyprctl setcursor catppuccin-mocha-dark-cursors 21")
end)
