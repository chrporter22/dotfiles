!/bin/bash

# Main function to handle installation process
main() {
    install_yay
    start_installation
    install_dotfiles
    install_plugins
    prompt_reboot
}

# Function to install AUR helper
install_yay() {
    git clone https://aur.archlinux.org/yay.git
    cd yay || exit
    makepkg -si --noconfirm
    cd ..
}

# Function to start installation
start_installation() {
    install_sys_packages
}

# Function to install system packages
install_sys_packages() {
    sudo pacman -Syu --needed \
        base-devel git neovim tmux zathura zathura-pdf-poppler \
        texlive-core texlive-latexextra ttf-font-awesome stow \
        curl wget vim htop fastfetch
}

# Function to clone dotfiles and stow them
install_dotfiles() {
    if [[ ! -d "$HOME/dotfiles" ]]; then
        git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
    fi
    cd ~/dotfiles || exit
    stow vim tmux zathura
}

# Function to install Vundle and TPM
install_plugins() {
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
    vim +PluginInstall +qall

    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    ~/.tmux/plugins/tpm/bin/install_plugins
}

# Function to prompt for reboot
prompt_reboot() {
    echo -e "Installation successful. Do you want to reboot? (Y/n)"
    read -r reboot
    if [[ $reboot == "Y" || $reboot == "y" ]]; then
        reboot
    fi
}

# Execute the script
main
