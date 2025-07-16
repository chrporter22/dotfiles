#!/bin/bash

# Arch Linux System tools install (Terminal Emulator; Windows Management; Compositor;
# Status Bar)
# Source: https://www.github.com/chrporter22/dotfiles
# Author: Christian J. Porter

# Launch installation
kickstart() {
    sys_prep
    xorg_stack
    wm_suite
    post_tools
    dotfile_link
    reboot_prompt
}

# Prompt to reboot
reboot_prompt() {
    echo -e "Installation complete. Reboot now? (Y/n)"
    read -r ans
    [[ $ans =~ ^[Yy]$ ]] && reboot
}

# System essentials
sys_prep() {
    sudo pacman -Syu --needed base-devel firefox \
        feh flatpak ueberzug \
        mtools atool \
        pacman-contrib bluez bluez-utils
}

# Xorg & display server components
xorg_stack() {
    sudo pacman -S --needed xorg-server xorg-xinit xclip xdotool maim \
        libxcb arandr ttf-firacode-nerd
}

# Window manager, compositor, launcher, bar
wm_suite() {
    sudo pacman -S --needed \
        i3-wm i3status i3-gaps \
        rofi \
        picom \       # Compositor for transparency and effects
        polybar \     # Customizable status bar
}

# Post-install system tools and terminal
post_tools() {
    # Audio
    sudo pacman -S --needed pulseaudio pulseaudio-equalizer pulseaudio-jack \
        pulseaudio-alsa alsa-utils

    # Terminal + Font
    sudo pacman -S --needed alacritty ttf-jetbrains-mono-nerd

    # Verify font installation
    fc-list | grep "JetBrainsMono"
}

# Symlink dotfiles using stow
dotfile_link() {
    sudo pacman -S --needed stow
    cd ~/dotfiles || exit
    stow i3 picom polybar rofi alacritty xresources backgrounds
}

kickstart
