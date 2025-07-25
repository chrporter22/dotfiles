#!/bin/bash

# =============================================
# DOTFILES INSTALLER — x86_64 + ARM SUPPORT
# ---------------------------------------------
# Development Environment Setup:
#   - Installing packages only if missing
#   - Managing your dotfiles with `stow`
#   - Setting up Neovim/Tmux plugins, TPM, Zathura, etc.
#   - Detecting architecture (x86_64 or ARM64 for Raspberry Pi)
# 
# Pairs with headless Raspberry Pi 5 NVMe/SD deploy script,
# for dotfile parity across devices.
# =============================================

DRY_RUN=false
SKIPPED_LOG="$HOME/install_skipped_packages.log"
ERROR_LOG="$HOME/install_errors.log"
IS_ARM=false  # Will be set dynamically

# === Arch Detection ===
detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64)
            echo "Detected ARM64 (Raspberry Pi 5, etc.)"
            IS_ARM=true
            ;;
        armv7l)
            echo "Detected 32-bit ARM (older Pi boards)"
            IS_ARM=true
            ;;
        x86_64)
            echo "Detected x86_64 (ThinkPad, desktop, etc.)"
            IS_ARM=false
            ;;
        *)
            echo "Unknown architecture: $ARCH — proceeding cautiously..."
            IS_ARM=false
            ;;
    esac
}

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
            echo "Queuing $pkg for installation..."
            pkgs_to_install+=("$pkg")
        else
            echo "$pkg already installed, skipping."
            echo "$pkg" >> "$SKIPPED_LOG"
        fi
    done

    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        if $DRY_RUN; then
            echo "Would install: ${pkgs_to_install[*]}"
        else
            sudo pacman -S --noconfirm --needed "${pkgs_to_install[@]}" 2>>"$ERROR_LOG"
        fi
    fi
}

# Call main function to run entire setup script
main() {
    detect_architecture
    install_yay
    start_installation
    install_uv
    install_zathura_pywal     # install transparency-patched zathura frontend
    install_dotfiles      # dotfiles first
    install_plugins       # then plugin installation
    # install_quarto_from_git  # build from git and check for nodejs & npm
    # prompt_reboot
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
        r docker openssh nmap redis github-cli go rustup nodejs npm \
        texlive-core texlive-bin texlive-latex texlive-latexextra texlive-formatsextra

    echo -e "Setting up Rust stable toolchain..."
    rustup default stable

    echo -e "Verifying Node.js and npm versions..."
    node -v
    npm -v
}

install_uv() {
    if ! is_installed uv; then
        echo "Checking for Rust toolchain (cargo)..."
        install_package rust

        echo "Installing uv via cargo..."
        cargo install --git https://github.com/astral-sh/uv uv 2>>"$ERROR_LOG"

        export PATH="$HOME/.cargo/bin:$PATH"
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    else
        echo "uv already installed, skipping."
        echo "uv" >> "$SKIPPED_LOG"
    fi
}

install_dotfiles() {
    local target="$HOME/.dotfiles"

    if [[ ! -d "$target" ]]; then
        git clone https://github.com/chrporter22/dotfiles.git "$target"
    fi

    cd "$target" || exit
    stow --target="$HOME" vim tmux zathura nvim  # bashrc 
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
        echo "Quarto already installed at $QUARTO_BIN, skipping."
        echo "quarto" >> "$SKIPPED_LOG"
        return
    fi

    echo "Installing Quarto CLI from GitHub..."

    install_package nodejs npm

    if [[ ! -d "$QUARTO_DIR" ]]; then
        git clone https://github.com/quarto-dev/quarto-cli.git "$QUARTO_DIR"
    fi

    cd "$QUARTO_DIR" || exit 1

    ./configure.sh 2>>"$ERROR_LOG"

    if [[ ! -x "$QUARTO_BIN" ]]; then
        echo "Quarto build failed or binary not found at $QUARTO_BIN" >> "$ERROR_LOG"
        return 1
    fi

    echo "Quarto CLI installed successfully to $QUARTO_BIN"
}

install_zathura_pywal() {
    local ZPW_DIR="$HOME/dev/zathura-pywal"

    echo "Installing zathura-pywal for alpha transparency support..."

    if [[ -d "$ZPW_DIR" ]]; then
        echo "zathura-pywal repo already exists, pulling latest changes..."
        git -C "$ZPW_DIR" pull
    else
        git clone https://github.com/GideonWolfe/Zathura-Pywal.git "$ZPW_DIR"
    fi
    
    if [[ ! -d "$ZPW_DIR" ]]; then
        echo "Failed to clone zathura-pywal. Directory not found."
        exit 1
    fi

    cd "$ZPW_DIR" || exit 1

    if $DRY_RUN; then
        echo "Would run zathura-pywal setup script: ./install.sh"
    else
        # chmod +x install.sh
        ./install.sh --no-pywal 2>>"$ERROR_LOG"
    fi

    echo "zathura-pywal installed. Remember to use it with a compatible zathurarc config."
}

# prompt_reboot() {
#     echo -e "\nInstallation successful. Reboot now? (Y/n)"
#     read -r reboot
#     if [[ $reboot == "Y" || $reboot == "y" ]]; then
#         reboot
#     fi
# }

main
