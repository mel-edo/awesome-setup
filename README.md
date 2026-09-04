# mshell dots

https://github.com/mel-edo/awesome-setup/assets/90543784/25acfe82-682d-4f04-9ef8-c2461703d929

---

<table>
  <tr>
    <td width="38%" valign="top">
      <h4>Hyprland Rice</h4>
      <p>Made on a 1920x1080 display</p>
      <ul>
        <li><b>Wallpapers from:</b> <a href="https://www.artstation.com/aenamiart">ArtStation</a> & <a href="https://store.steampowered.com/app/431960/Wallpaper_Engine/">Wallpaper Engine</a></li>
        <li><b>Window Manager:</b> <a href="https://github.com/hyprwm/Hyprland">Hyprland</a></li>
        <li><b>Terminal:</b> <a href="https://github.com/alacritty/alacritty">alacritty</a></li>
        <li><b>Shell:</b> <a href="https://www.zsh.org/">zsh</a></li>
        <li><b>Desktop shell / bar:</b> <a href="https://github.com/quickshell-mirror/quickshell">Quickshell</a></li>
        <li><b>Color theming:</b> <a href="https://github.com/InioX/matugen">matugen</a></li>
        <li><b>System fetch:</b> <a href="https://github.com/fastfetch-cli/fastfetch">fastfetch</a></li>
        <li><b>Cursor theme:</b> <a href="https://github.com/catppuccin/cursors">catppuccin-dark</a></li>
        <li><b>Folder theme:</b> <a href="https://github.com/PapirusDevelopmentTeam/papirus-icon-theme">Papirus</a> with <a href="https://github.com/catppuccin/papirus-folders">Catppuccin folder colors</a></li>
        <li><b>GTK theme:</b> <a href="https://github.com/catppuccin/gtk">catppuccin</a></li>
        <li><b>QT theme:</b> <a href="https://github.com/catppuccin/Kvantum">catppuccin with kvantum</a></li>
      </ul>
    </td>
    <td width="62%" valign="top" align="center">
      <a href="images/1.png"><img src="images/1.png" width="48%" /></a>
      <a href="images/2.png"><img src="images/2.png" width="48%" /></a>
      <a href="images/3.png"><img src="images/3.png" width="48%" /></a>
      <a href="images/4.png"><img src="images/4.png" width="48%" /></a>
    </td>
  </tr>
</table>

---

## Configuration you need to change
 
You'll want to edit these.
 
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
7. Go through [**Configuration you need to change**](#configuration-you-need-to-change) above before launching
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
 
## Keybinds & Rules
 
All keybindings, touchpad gestures, and window/layer rules are documented in **[KEYBINDS.md](KEYBINDS.md)**.
 
| Keybind | Action |
|---|---|
| `SUPER + Return` | Open terminal (`alacritty`) |
| `SUPER + A` | Toggle launcher |
| `SUPER + Space` | Toggle floating, resize + center |
| `SUPER + Q` | Close window |
| `SUPER + W` | Toggle overview |
| `SUPER + Escape` | Toggle power menu |
 
> For the complete list of shortcuts, media controls, gestures, and window/layer rules, see **[KEYBINDS.md](KEYBINDS.md)**.
 
---
 
## Previous Rices

### Lavender (AwesomeWM)

<table>
  <tr>
    <td width="38%" valign="top">
      <h4>Catppuccin Lavender themed Rice</h4>
      <ul>
        <li><b>Branch:</b> <a href="https://github.com/mel-edo/awesome-setup/tree/Lavender"><code>Lavender</code></a></li>
        <li><b>Window Manager:</b> <a href="https://github.com/awesomeWM/awesome">AwesomeWM</a></li>
        <li><b>Bar:</b> <a href="https://github.com/polybar/polybar">Polybar</a></li>
        <li><b>Compositor:</b> <a href="https://github.com/pijulius/picom">picom-pijulius</a></li>
        <li><b>Wallpaper:</b> <a href="https://www.artstation.com/artwork/4Xa124">ArtStation</a></li>
      </ul>
    </td>
    <td width="62%" valign="top" align="center">
      <a href="https://raw.githubusercontent.com/mel-edo/awesome-setup/Lavender/images/1.png"><img src="https://raw.githubusercontent.com/mel-edo/awesome-setup/Lavender/images/1.png" width="48%" /></a>
      <a href="https://raw.githubusercontent.com/mel-edo/awesome-setup/Lavender/images/2.png"><img src="https://raw.githubusercontent.com/mel-edo/awesome-setup/Lavender/images/2.png" width="48%" /></a>
      <a href="https://raw.githubusercontent.com/mel-edo/awesome-setup/Lavender/images/3.png"><img src="https://raw.githubusercontent.com/mel-edo/awesome-setup/Lavender/images/3.png" width="48%" /></a>
      <a href="https://raw.githubusercontent.com/mel-edo/awesome-setup/Lavender/images/4.png"><img src="https://raw.githubusercontent.com/mel-edo/awesome-setup/Lavender/images/4.png" width="48%" /></a>
    </td>
  </tr>
</table>

### Mauve (AwesomeWM)

<table>
  <tr>
    <td width="38%" valign="top">
      <h4>Catppuccin Mauve themed Rice</h4>
      <ul>
        <li><b>Branch:</b> <a href="https://github.com/mel-edo/awesome-setup/tree/Mauve"><code>Mauve</code></a></li>
        <li><b>Window Manager:</b> <a href="https://github.com/awesomeWM/awesome">AwesomeWM</a></li>
        <li><b>Wallpaper:</b> <a href="https://www.artstation.com/artwork/4bX4eY">ArtStation</a></li>
      </ul>
    </td>
    <td width="62%" valign="top" align="center">
      <a href="https://raw.githubusercontent.com/mel-edo/awesome-setup/Mauve/images/1.png"><img src="https://raw.githubusercontent.com/mel-edo/awesome-setup/Mauve/images/1.png" width="48%" /></a>
      <a href="https://raw.githubusercontent.com/mel-edo/awesome-setup/Mauve/images/2.png"><img src="https://raw.githubusercontent.com/mel-edo/awesome-setup/Mauve/images/2.png" width="48%" /></a>
    </td>
  </tr>
</table>

---
 
### Sources of inspiration:

- [caelestia](https://github.com/caelestia-dots/shell)
- [Rexcrazy804](https://github.com/Rexcrazy804/Zaphkiel)
- [Devvvmn](https://github.com/Devvvmn/ActivSpot)
---

### Star History:

<img src="https://img.shields.io/github/stars/MeledoJames/awesome-setup?color=b4befe&labelColor=1e1e2e&style=for-the-badge" align="right" />

<a href="https://www.star-history.com/#mel-edo/awesome-setup&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=mel-edo/awesome-setup&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=mel-edo/awesome-setup&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=mel-edo/awesome-setup&type=Date" />
 </picture>
</a>
