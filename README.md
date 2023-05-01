# Config files for AwesomeWM

<img src="https://img.shields.io/github/stars/MeledoJames/awesome-setup?color=b4befe&labelColor=1e1e2e&style=for-the-badge" align="right" />

### This was made on a 1920x1080 display 

Wallpaper - [ArtStation](https://www.artstation.com/artwork/4Xa124)

---

## [Images for the finished rice](#final-images)

- **Window Manager:** [awesome-git](https://github.com/awesomeWM/awesome)
- **Terminal:** [alacritty](https://github.com/alacritty/alacritty)
- **Shell:** [zsh](https://www.zsh.org/)
- **Bar:** [polybar](https://github.com/polybar/polybar)
- **Compositor:** [pijulius-picom](https://github.com/pijulius/picom)
- **Editor:** [neovim(nvchad)](https://github.com/NvChad/NvChad)
- **Browser:** [firefox](https://www.mozilla.org/en-US/firefox)
- **Firefox CSS:** [Cascade](https://github.com/andreasgrafen/cascade)
- **File Manager:** [nemo](https://github.com/linuxmint/nemo)
- **Application Launcher:** [adi1090x's rofi](https://github.com/adi1090x/rofi)
- **SDDM theme:** [Sugar Candy theme for SDDM](https://www.opendesktop.org/p/1312658/)
- **Color scheme:** [Catppuccin](https://github.com/catppuccin/catppuccin)
- **Startpage:** [Chevron](https://github.com/kholmogorov27/chevron)

---

## Install Instructions:

List of the required programs for this rice

(For yay in Arch Linux)

```
yay -S --needed awesome-git polybar picom-pijulius-git alacritty betterlockscreen catppuccin-gtk-theme-mocha conky logo-ls lxappearance neovim neofetch papirus-icon-theme feh sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg
```

### Manual Method:

Thanks to [ka1ry](https://github.com/ka1ry) for testing on different hardware!

>Proceed with caution

1. ``` git clone https://github.com/MeledoJames/awesome-setup ```
2. Backup your .config folder or make it if it doesen't already exist
3. ``` cp -r ~/awesome-setup/config/* ~/.config ```
4. ``` cp -r ~/awesome-setup/fonts/* ~/.local/share/fonts ```
5. ``` fc-cache -v -f ```
6. ``` sudo cp -r ~/.config/sddm/sugar-candy /usr/share/sddm/themes/ ```
7. ``` sudo cp -r ~/.config/sddm/sddm.conf /etc/ ```

> You can view all keybindings in awesomewm using Mod + s

> Check ```.config/awesome/autorun.sh``` and lines 623 - 630 in ```.config/awesome/rc.lua``` for startup programs. Modify to your liking

> Theme your remaining apps from the [Catppuccin Github](https://github.com/catppuccin/catppuccin)

---

### Missing Icons in polybar?

> Missing Brightness Icon - [Backlight](https://github.com/polybar/polybar/wiki/Module:-backlight) and [xbacklight](https://github.com/polybar/polybar/wiki/Module:-xbacklight) modules

> Missing Battery Icon - You probably don't have a battery in which case you can remove the battery module from line 85 of ```.config/polybar/config.ini```

> Missing Network Icon - [Polybar network wiki](https://github.com/polybar/polybar/wiki/Module:-network)

---

## Final Images

![a](/images/1.png?raw=true)

![b](/images/2.png?raw=true)

![c](/images/3.png?raw=true)

![d](/images/4.png?raw=true)

![e](/images/5.png?raw=true)

![f](/images/6.png?raw=true)

![g](/images/7.png?raw=true)
---

### Sources of inspiration:

- [rklyz](https://github.com/rklyz/MyRice)
- [janleigh](https://github.com/janleigh/dotfiles)
