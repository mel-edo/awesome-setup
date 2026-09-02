# mshell dots - Hyprland Rice

<img src="https://img.shields.io/github/stars/MeledoJames/awesome-setup?color=b4befe&labelColor=1e1e2e&style=for-the-badge" align="right" />

### This was made on a 1920x1080 display

https://github.com/mel-edo/awesome-setup/assets/90543784/25acfe82-682d-4f04-9ef8-c2461703d929

---

### Screenshots
 
![a](/images/1.png?raw=true)
![b](/images/2.png?raw=true)
![b](/images/3.png?raw=true)
![b](/images/4.png?raw=true)
![b](/images/5.png?raw=true)

---

- **Window Manager:** [Hyprland](https://github.com/hyprwm/Hyprland)
- **Terminal:** [alacritty](https://github.com/alacritty/alacritty)
- **Shell:** [zsh](https://www.zsh.org/)
- **Desktop shell / bar:** [Quickshell](https://github.com/quickshell-mirror/quickshell)
- **Color theming:** [matugen](https://github.com/InioX/matugen)
- **System fetch:** [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- **Cursor theme:** [catppuccin-dark](https://github.com/catppuccin/cursors)
- **Folder theme:** [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) with [Catppuccin folder colors](https://github.com/catppuccin/papirus-folders)
- **GTK theme:** [catppuccin](https://github.com/catppuccin/gtk)
- **QT theme:** [catppuccin with kvantum](https://github.com/catppuccin/Kvantum)

---

## Configuration you need to change
 
This rice is tuned to my machine. You'll want to edit these.
 
| File | What to change |
|---|---|
| `config/quickshell/mshell/scripts/calendar/weather.sh` | `API_KEY` and `CITY`. Get from [openweathermap.org](https://openweathermap.org/api) |
| `config/hypr/settings.json` → `wallpaperDir` | Add path to your wallpaper dir. Wallpaper picker looks in your wallpaper dir by default and also picks up Wallpaper Engine wallpapers if you have those. |
| `config/hypr/hyprland.lua` → `hl.monitor(...)` | `output = ""`, `mode = "1920x1080@120"` | Blank output matches your first/only monitor; set it explicitly and adjust the mode/refresh rate for multi-monitor setups. |
| `config/hypr/hyprland.lua` → env vars | `NVD_BACKEND`, `LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`. Modify according to your [hardware](https://wiki.hypr.land/Nvidia/) |
| `config/hypr/hypridle.conf` | Modify lock, suspend timers |
 
---
 
## Install Instructions
 
### Required programs
 
(For yay on Arch Linux)
 
```
yay -S --needed hyprland hypridle hyprpicker quickshell-git matugen cava awww grim slurp wl-clipboard tesseract playerctl brightnessctl 
```

#### Optional Programs

```
copyq, hyprsunset, fastfetch, mpv, polkit-gnome, pokemon-colorscripts-git, gpu-screen-recorder, catppuccin-cursors-mocha, catppuccin-gtk-theme-mocha
```
 
### Manual method
 
1. `git clone -b Hyprland https://github.com/mel-edo/awesome-setup mshell-dots`
2. Backup your `~/.config` folder (or create it if it doesn't exist)
3. `cp -r ~/mshell-dots/config/* ~/.config`
4. `cp -r ~/mshell-dots/fonts/* ~/.local/share/fonts`
5. `fc-cache -v -f`
6. `cp ~/mshell-dots/.zprofile ~/mshell-dots/.zshrc ~/`
7. Go through **Configuration you need to change** above before launching
8. mshell launches automatically via Hyprland's autostart. Run it manually using launch script - `~/.config/quickshell/mshell/launch.sh`
---
 
## Autostart
 
Runs on Hyprland startup. Change as you wish
 
1. `dbus-update-activation-environment`
2. polkit-gnome auth agent
3. `hyprsunset -t 5000`
4. `hypridle`
5. `awww-daemon`
6. `discord`, `zen-browser`
7. `kdeconnect-indicator`
8. `launch.sh` - Starts the Quickshell desktop shell 
9. Applies `catppuccin-mocha-dark-cursors`
 
---
 
## Keybinds
 
`mainMod` = **SUPER**
 
| Keybind | Action |
|---|---|
| `SUPER + Return` | Open terminal (alacritty) |
| `SUPER + Q` | Close window |
| `SUPER + F` | Toggle fullscreen |
| `SUPER + E` | Open file manager (nemo) |
| `SUPER + Space` | Toggle floating, resize + center |
| `ALT + Tab` | Cycle to next window / bring to top |
| `SUPER + A` | Toggle launcher |
| `SUPER + Escape` | Toggle power menu |
| `SUPER + W` | Toggle overview |
| `SUPER + L` | Lock screen |
| `SUPER + Z` / `SUPER + X` | Kill / relaunch quickshell |
| `SUPER + 1–8` | Focus workspace 1–8 |
| `SUPER + Shift + 1–8` | Move window to workspace 1–8 |
| `SUPER + S` / `SUPER + Shift + S` | Toggle special workspace / move window to it |
| `SUPER + mouse:272 / mouse:273` | Drag / resize window using left and right click |
| `Next` (PgDn) / `F12` | Screenshot region → saved + copied to clipboard |
| `Shift + Next` / `Shift + F12` | OCR screenshot region → copied to clipboard (tesseract) |
| `Shift + Alt + 0` | Toggle screen recording (`gsr-toggle.sh`) |
| `SUPER + V` | Toggle clipboard manager (copyq) |
| `SUPER + P` | Color picker (hyprpicker) |
| `SUPER + N` / `SUPER + Ctrl + N` | Minimize / restore last window [niflveil](https://github.com/Mauitron/NiflVeil) |
| `SUPER + Up/Down` or volume keys | Volume +/- 5% |
| `SUPER + Left/Right` or brightness keys | Brightness +/- 5% |
| `XF86Audio(Mute/MicMute)` | Toggle mute / mic mute |
| `XF86Audio(Next/Prev/Play/Pause)`, `Prior`, `F11` | Media controls (playerctl) |
| `XF86Calculator` | Open galculator |
| `SUPER + scroll` | Adjust cursor zoom |
| 3-finger swipe horizontal | Switch workspace |
| 3-finger swipe down / up | Minimize / restore [niflveil](https://github.com/Mauitron/NiflVeil) |
| 4-finger swipe down | Close window |
| 4-finger swipe up | Toggle launcher |
 
> `niflveil` is a window-minimizer for Hyprland by [Mauitron](https://github.com/Mauitron/NiflVeil), not included in this repo. It needs to be built and installed separately:
> ```
> git clone https://github.com/Mauitron/NiflVeil.git
> cd NiflVeil/niflveil
> cargo build --release
> sudo cp target/release/niflveil /usr/local/bin/
> ```
> Go through it's repo for more info!
 
---
 
## Window & layer rules
 
| App / match | Behavior |
|---|---|
| zen (browser) | → workspace 1 |
| discord | → workspace 2 |
| Obsidian | → workspace 3 |
| codium, steam | → workspace 4 |
| youtube-music | → workspace 5 |
| PrismLauncher, twintaillauncher, Lutris | → workspace 6 , floating & centered |
| Betterbird | → workspace 7 |
| yad, copyq, nm-connection-editor, pavucontrol, blueberry, file-roller, Godot, qBittorrent | Floating, fixed size, centered |
| Picture-in-Picture windows | Floating, pinned to position (1280, 35) |
| "Friends List" (Steam) | Floating |
| Empty-class/title XWayland floats | No focus (suppresses stray ghost windows) |
| All windows | Maximize event suppressed |
| `quickshell:expose` layer | Blurred + dimmed background |
| `quickshell:*` layers, `selection` layer | No animation |
 
---
 
### Sources of inspiration:

- [caelestia](https://github.com/caelestia-dots/shell)
- [Rexcrazy804](https://github.com/Rexcrazy804/Zaphkiel)
- [Devvvmn](https://github.com/Devvvmn/ActivSpot)
---

### Star History:

<a href="https://www.star-history.com/#mel-edo/awesome-setup&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=mel-edo/awesome-setup&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=mel-edo/awesome-setup&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=mel-edo/awesome-setup&type=Date" />
 </picture>
</a>
