# Keybinds & Window Rules

All default keybindings, touchpad gestures, and window/layer rules for my setup.

---

## Keybinds

`mainMod` = **SUPER**

### Applications & System

| Keybind | Action |
|---|---|
| `SUPER + Return` | Open terminal (`alacritty`) |
| `SUPER + A` | Toggle launcher |
| `SUPER + E` | Open file manager (`nemo`) |
| `SUPER + Escape` | Toggle power menu |
| `SUPER + W` | Toggle overview |
| `SUPER + L` | Lock screen |
| `SUPER + V` | Toggle clipboard manager (`copyq`) |
| `SUPER + P` | Color picker (`hyprpicker`) |
| `XF86Calculator` | Open calculator (`galculator`) |
| `SUPER + Z` / `SUPER + X` | Kill / relaunch quickshell |

### Window Management

| Keybind | Action |
|---|---|
| `SUPER + Q` | Close window |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + Space` | Toggle floating, resize + center |
| `ALT + Tab` | Cycle to next window / bring to top |
| `SUPER + mouse:272` | Drag window (left click) |
| `SUPER + mouse:273` | Resize window (right click) |
| `SUPER + N` / `SUPER + Ctrl + N` | Minimize / restore last window ([niflveil](https://github.com/Mauitron/NiflVeil)) |

### Workspaces

| Keybind | Action |
|---|---|
| `SUPER + 1–8` | Focus workspace 1–8 |
| `SUPER + Shift + 1–8` | Move window to workspace 1–8 |
| `SUPER + S` / `SUPER + Shift + S` | Toggle special workspace / move window to it |

### Screenshots & Recording

| Keybind | Action |
|---|---|
| `Next` (PgDn) / `F12` | Screenshot region → saved + copied to clipboard |
| `Shift + Next` / `Shift + F12` | OCR screenshot region → copied to clipboard (`tesseract`) |
| `Shift + Alt + 0` | Toggle screen recording (`gsr-toggle.sh`) |

### Media & Hardware Controls

| Keybind | Action |
|---|---|
| `SUPER + Up/Down` or volume keys | Volume +/- 5% |
| `SUPER + Left/Right` or brightness keys | Brightness +/- 5% |
| `XF86Audio(Mute/MicMute)` | Toggle mute / mic mute |
| `XF86Audio(Next/Prev/Play/Pause)`, `Prior`, `F11` | Media controls (`playerctl`) |
| `SUPER + scroll` | Adjust cursor zoom |

### Touchpad Gestures

| Gesture | Action |
|---|---|
| 3-finger swipe horizontal | Switch workspace |
| 3-finger swipe down / up | Minimize / restore ([niflveil](https://github.com/Mauitron/NiflVeil)) |
| 4-finger swipe down | Close window |
| 4-finger swipe up | Toggle launcher |

---

### Window Minimizer (`niflveil`)

> `niflveil` is a window-minimizer for Hyprland by [Mauitron](https://github.com/Mauitron/NiflVeil), not included in this repo. It needs to be built and installed separately:
>
> ```bash
> git clone https://github.com/Mauitron/NiflVeil.git
> cd NiflVeil/niflveil
> cargo build --release
> sudo cp target/release/niflveil /usr/local/bin/
> ```
> Check the [niflveil repository](https://github.com/Mauitron/NiflVeil) for more details.

---

## Window & Layer Rules

### Window Rules

| App / Match | Behavior |
|---|---|
| `zen` (browser) | → workspace 1 |
| `discord` | → workspace 2 |
| `Obsidian` | → workspace 3 |
| `codium`, `steam` | → workspace 4 |
| `youtube-music` | → workspace 5 |
| `PrismLauncher`, `twintaillauncher`, `Lutris` | → workspace 6, floating & centered |
| `Betterbird` | → workspace 7 |
| `yad`, `copyq`, `nm-connection-editor`, `pavucontrol`, `blueberry`, `file-roller`, `Godot`, `qBittorrent` | Floating, fixed size, centered |
| Picture-in-Picture windows | Floating, pinned to position `(1280, 35)` |
| `"Friends List"` (Steam) | Floating |
| Empty-class/title XWayland floats | No focus (suppresses stray ghost windows) |
| All windows | Maximize event suppressed |

### Layer Rules

| Layer / Match | Behavior |
|---|---|
| `quickshell:expose` layer | Blurred + dimmed background |
| `quickshell:*` layers | No animation |
| `selection` layer | No animation |
