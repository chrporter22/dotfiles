#!/bin/bash

# Arch Linux i3 Data Science Install (Nvim Tmux, Zathura; Catppuccin / Rose-pine colorscheme)
# Language support: Pyhton, R, bash, marckdown, sql, c, c_sharp, rust, lua, latex, html,
# Source: https://www.github.com/chrporter22/dotfiles
# Author: Christian J. Porter


# Main function to handle installation process
main() {
    start_installation
    prompt_reboot
}


# Function to prompt for reboot
prompt_reboot() {
    echo -e "Installation successful. Do you want to reboot? (Y/n)"
    read reboot

    if [[ $reboot == "Y" || $reboot == "y" ]]; then
        reboot
    fi
}


# Function to install system packages
install_sys_packages() {
    sudo pacman -Syu --needed base-devel neovim vim github-cli fastfetch firefox git wget curl htop feh flatpak ueberzug atool poppler imagemagick highlight zathura-pdf-poppler pacman-contrib  bluez bluez-utils 
}


# Function to install AUR helper
install_yay() {
    git clone https://aur.archlinux.org/yay.git
    cd yay || exit
    makepkg -si --noconfirm
    cd ..
}

# Function to install Xorg (window server/manager)
install_xorg() {
    sudo pacman -Syu xorg maim xclip xdotool picom libxcb arandr 
    yay -S networkmanager-dmenu-git xbanish ttf-firacode-nerd
}
