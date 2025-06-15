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
