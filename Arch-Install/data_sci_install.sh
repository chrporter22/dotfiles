#!/bin/bash

DRY_RUN=false
SKIPPED_LOG="$HOME/install_skipped_packages.log"
ERROR_LOG="$HOME/install_errors.log"

# Parse command-line argument
if [[ $1 == "--dry-run" ]]; then
    DRY_RUN=true
    echo "Dry run mode enabled. No changes will be made."
    > "$SKIPPED_LOG"
    > "$ERROR_LOG"
fi

# Check if command exists
is_installed() {
    command -v "$1" >/dev/null 2>&1
}

# Install system packages only if not already present (with logging)
install_package() {
    local pkgs_to_install=()
    for pkg in "$@"; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            echo "→ Queuing $pkg for installation..."
            pkgs_to_install+=("$pkg")
        else
            echo "✔ $pkg already installed, skipping."
            echo "$pkg" >> "$SKIPPED_LOG"
        fi
    done

    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        if $DRY_RUN; then
            echo "🔍 Would install: ${pkgs_to_install[*]}"
        else
            sudo pacman -S --noconfirm --needed "${pkgs_to_install[@]}" 2>>"$ERROR_LOG"
        fi
    fi
}

# Call main function to run entire setup script
main() {
    install_yay
    start_installation
    install_uv
    install_dotfiles      # dotfiles first
    install_plugins       # then plugin installation
    install_quarto_from_git  # build from git and install node.js and npm
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
    echo -e "Checking for available updates..."

    if ! sudo pacman -Qu | grep -q .; then
        echo "System is already up to date."
    else
        echo "Updates available. Proceeding with cautious system upgrade..."
        sudo pacman -Syu --noconfirm
    fi

    echo -e "Checking and installing required packages..."
    install_package \
        base-devel git neovim tmux zathura zathura-pdf-poppler \
        ttf-jetbrains-mono-nerd ttf-font-awesome stow curl wget \
        vim htop fastfetch ripgrep fzf \
        r docker github-cli\
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
    local target="$HOME/.dotfiles"

    if [[ ! -d "$target" ]]; then
        git clone https://github.com/chrporter22/dotfiles.git "$target"
    fi

    cd "$target" || exit
    stow --target="$HOME" vim tmux zathura bashrc nvim
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

install_quarto_from_git() {
    local QUARTO_DIR="$HOME/dev/quarto-cli"
    local QUARTO_BIN="$HOME/.local/bin/quarto"

    if [[ -x "$QUARTO_BIN" ]]; then
        echo "✔ Quarto already installed at $QUARTO_BIN, skipping."
        echo "quarto" >> "$SKIPPED_LOG"
        return
    fi

    echo "→ Installing Quarto CLI from GitHub..."

    install_package nodejs npm

    if [[ ! -d "$QUARTO_DIR" ]]; then
        git clone https://github.com/quarto-dev/quarto-cli.git "$QUARTO_DIR"
    fi

    cd "$QUARTO_DIR" || exit 1

    ./configure.sh 2>>"$ERROR_LOG"

    if [[ ! -x "$QUARTO_BIN" ]]; then
        echo "❌ Quarto build failed or binary not found at $QUARTO_BIN" >> "$ERROR_LOG"
        return 1
    fi

    echo "✔ Quarto CLI installed successfully to $QUARTO_BIN"
}

prompt_reboot() {
    echo -e "\nInstallation successful. Reboot now? (Y/n)"
    read -r reboot
    if [[ $reboot == "Y" || $reboot == "y" ]]; then
        reboot
    fi
}

main
