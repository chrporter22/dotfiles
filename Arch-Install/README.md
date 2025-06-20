# Arch - Install
* Network Manager
```
```
* Grub
```
```
* Enable Systemctl
```
```
# Post - Install
* pulseaudio
```
sudo pacman -S pulseaudio pulseaudio-equalizer pulseaudio-jack
sudo pacman -S alsa-utils  # run the command alsamixer
sudo pacman -S pulseaudio pulseaudio-alsa
```

* bluez bluez-utils
```

```
* curl
```

```
* wget
```

```
* git
```
sudo pacman -S git
```

# System Tools
+ i3, Rofi, Polybar Theme:  inpsired by [https://guthub.com/Typecraft-dev/dotfiles]
+ Zathura Theme: [https://github.com/GideonWolfe/Zathura-Pywal]
* fastfetch
```
sudo pacman -S htop
```

* htop
```
sudo pacman -S htop
```

* Alactritty
```
sudo pacman -S alacritty
sudo pacman -S ttf-jetbrains-mono-nerd
fc-list | grep "JetBrainsMono"
sudo pacman -S lsd
sudo pacman -S cmatrix
```


* i3-wm
```
sudo pacman -S i3-wm i3lock i3status dmenu
sudo pacman -S xorg-xrandr xorg-xinit
sudo pacman -S xorg-server
sudo pacman -S xf86-input-libinput  # Touchpad Support
sudo pacman -S i3-gaps
````

* GNU Stow
```
pacman -S stow
```

* Rofi
```
sudo pacman -S rofi 
```

* Picom
```
sudo pacman -S picom 
```

* Polybar
```
sudo pacman -S polybar
```

* Ripgep
```
sudo pacman -S ripgrep
```

* fzf
```
sudo pacman -S fzf
```

* feh
```
sudo pacman -S feh
```

* Zathura 
    + A lightweight customizable pdf viewer with Vim-like keybindings.
    + A Pywal color scheme for Zathura
```
sudo pacman -S zathura zathura-pdf-poppler
git clone https://github.com/GideonWolfe/Zathura-Pywal
```

# Data Science Tools
* Pyhton3
* R 
* Github CLI
```
sudo pacman -S github-cli
```
* Vim
* Neovim
* Tmux
* Juypter Lab
* Quarto CLI
* Docker
    + Containers for deployment and tooling management for project environment 
```
```
* uv
    + Lighweight rust based python package & tool manager
```


