# Config files for AwesomeWM

<img src="https://img.shields.io/github/stars/MeledoJames/awesome-setup?color=b4befe&labelColor=1e1e2e&style=for-the-badge" align="right" />

### This was made on a 1920x1080 display 

Wallpaper - [ArtStation](https://www.artstation.com/artwork/4Xa124)

---

## [Images of the finished rice](#final-images)

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

### List of the required programs for this rice

(For yay in Arch Linux)

```
yay -S --needed awesome-git polybar picom-pijulius-git alacritty betterlockscreen catppuccin-gtk-theme-mocha conky logo-ls lxappearance neovim neofetch papirus-icon-theme feh rofi xidlehook sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg
```

### Optional programs

1. zsh and ohmyzsh
2. brightnessctl
3. cool-retro-term with cmatrix used as a screensaver
4. neofetch
5. neovim
6. nemo (file manager)
7. redshift

### Manual Method:

Thanks to [ka1ry](https://github.com/ka1ry) for testing on different hardware!

> **Warning**
>
>Proceed with caution

1. ``` git clone https://github.com/MeledoJames/awesome-setup ```
2. Backup your .config folder or make it if it doesen't already exist
3. ``` cp -r ~/awesome-setup/config/* ~/.config ```
4. ``` cp -r ~/awesome-setup/fonts/* ~/.local/share/fonts ```
5. ``` fc-cache -v -f ```
6. ``` sudo cp -r ~/.config/sddm/sugar-candy /usr/share/sddm/themes/ ```
7. ``` sudo cp -r ~/.config/sddm/sddm.conf /etc/ ```
8. ``` systemctl enable betterlockscreen@$USER ```
9. ``` cp -r ~/awesome-setup/cmatrix.sh ~/awesome-setup/grubupdate.sh ~/awesome-setup/.xinitrc ~/awesome-setup/.Xresources ~/awesome-setup/.zprofile ~/awesome-setup/.zshrc ~/ ```

> You can view all keybindings in awesomewm using Mod + s

> Download the wallpaper from the artstation link and put it in your ``` ~/Downloads ```

> Change your latitude and longitude in ``` ~/.config/polybar/weather.py ``` on lines 80 and 81 and ``` ~/.config/redshift/redshift.conf ``` on lines 60 and 61

> Check ``` ~/.config/awesome/autorun.sh ``` and lines 623 - 630 in ``` ~/.config/awesome/rc.lua ``` for startup programs. Modify to your liking

> Theme your remaining apps from the [Catppuccin Github](https://github.com/catppuccin/catppuccin)

---

### Missing Icons in polybar?

> Missing Brightness Icon - [Backlight](https://github.com/polybar/polybar/wiki/Module:-backlight) and [xbacklight](https://github.com/polybar/polybar/wiki/Module:-xbacklight) modules

> Missing Battery Icon - You probably don't have a battery in which case you can remove the battery module from line 85 of ``` ~/.config/polybar/config.ini ```

> Missing Network Icon - [Polybar network wiki](https://github.com/polybar/polybar/wiki/Module:-network)

---

### Firefox userchrome css

1. cd into ~/.mozilla/firefox/(release).default-release/chrome (make chrome folder if it doesen't exist already)
2. copy files inside ~/awesome-setup/firefox/chrome to the folder in the above point
3. Install Tab center reborn extension -> More details here [Cascade](https://github.com/andreasgrafen/cascade#tab-center-reborn--vertical-tabs)

---

### Startpage

1. Install npm ``` yay -S npm ```
2. ``` sudo npm install http-server -g ```
3. run ``` http-server ~/.config/chevron/dist/ ``` and visit http://127.0.0.1:8080 in your browser
4. I've already added this command in autostart (check end of rc.lua)
5. If you're on firefox you can use [new tab override](https://addons.mozilla.org/en-US/firefox/addon/new-tab-override/) to change the new tab and home page
6. For more details -> [Chevron](https://github.com/kholmogorov27/chevron) 

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
---

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=MeledoJames/awesome-setup&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=MeledoJames/awesome-setup&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=MeledoJames/awesome-setup&type=Date" />
</picture>
