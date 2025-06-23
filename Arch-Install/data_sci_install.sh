#!/bin/bash

# Check if a command exists
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Install system packages only if not already present
install_package() {
    for pkg in "$@"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            sudo pacman -S --noconfirm "$pkg"
        else
            echo "$pkg already installed, skipping."
        fi
    done
}

# Call main function to run entire setup script
main() {
    install_yay
    start_installation
    install_uv
    install_dotfiles      # dotfiles first
    install_plugins       # then plugin installation
    prompt_reboot
}

install_yay() {
    if ! is_installed yay; then
        git clone https://aur.archlinux.org/yay.git
        cd yay || exit
        makepkg -si --noconfirm
        cd ..
    else
        echo "yay already installed, skipping."
    fi
}

start_installation() {
    sudo pacman -Syu --noconfirm
    install_package \
        base-devel git neovim tmux zathura zathura-pdf-poppler \
        ttf-jetbrains-mono-nerd ttf-font-awesome stow curl wget \
        vim htop fastfetch ripgrep fzf lsd quarto-cli \
        r docker gh \
        texlive-core texlive-bin texlive-latex texlive-latexextra texlive-formatsextra
}

install_uv() {
    if ! is_installed uv; then
        cargo install --git https://github.com/astral-sh/uv uv
        export PATH="$HOME/.cargo/bin:$PATH"
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    else
        echo "uv already installed, skipping."
    fi
}

install_dotfiles() {
    if [[ ! -d "$HOME/dotfiles" ]]; then
        git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
    fi
    cd ~/dotfiles || exit
    stow vim tmux zathura bashrc nvim
}

install_plugins() {
    # Lazy.nvim (Neovim plugin manager)
    local nvim_lazy_path="$HOME/.local/share/nvim/lazy/lazy.nvim"
    if [[ ! -d "$nvim_lazy_path" ]]; then
        git clone https://github.com/folke/lazy.nvim.git "$nvim_lazy_path"
    else
        echo "Lazy.nvim already installed, skipping."
    fi

    # Vundle (classic Vim plugin manager)
    if [[ ! -d ~/.vim/bundle/Vundle.vim ]]; then
        git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
    else
        echo "Vundle already installed, skipping."
    fi
    vim +PluginInstall +qall
    [[ -f ~/.vimrc ]] && source ~/.vimrc

    # Tmux Plugin Manager (TPM)
    if [[ ! -d ~/.tmux/plugins/tpm ]]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    else
        echo "TPM already installed, skipping."
    fi

    if is_installed tmux; then
        tmux new-session -d -s temp_plugin_session "~/.tmux/plugins/tpm/bin/install_plugins"
        sleep 2
        tmux kill-session -t temp_plugin_session
    fi
}

prompt_reboot() {
    echo -e "\nInstallation successful. Reboot now? (Y/n)"
    read -r reboot
    if [[ $reboot == "Y" || $reboot == "y" ]]; then
        reboot
    fi
}

main
