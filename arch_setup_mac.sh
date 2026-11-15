#!/usr/bin/env zsh

# =============================================
# ARCH SETUP — macOS (M6 Mac Mini Studio)
# ---------------------------------------------
# System tools installer: Homebrew, Alacritty,
# Skim (with translucent PDF view), Docker,
# stow, and full set of CLI/GUI tools.
# No Zathura on Mac — Skim replaces it.
# =============================================

DRY_RUN=false
SKIPPED_LOG="$HOME/install_skipped_packages.log"
ERROR_LOG="$HOME/install_errors.log"
SKIM_BUNDLE_ID="net.sourceforge.skim-app.skim"

if [[ $1 == "--dry-run" ]]; then
    DRY_RUN=true
    echo "Dry run mode enabled. No changes will be made."
    > "$SKIPPED_LOG"
    > "$ERROR_LOG"
fi

is_installed() {
    command -v "$1" >/dev/null 2>&1
}

run_or_print() {
    if $DRY_RUN; then
        echo "Would run: $*"
    else
        "$@" 2>>"$ERROR_LOG"
    fi
}

install_brew() {
    if ! is_installed brew; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>>"$ERROR_LOG"
    else
        echo "Homebrew already installed, skipping."
        echo "brew" >> "$SKIPPED_LOG"
    fi

    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

install_package() {
    local pkgs_to_install=()
    for pkg in "$@"; do
        if ! brew list "$pkg" &>/dev/null; then
            echo "Queuing formula $pkg..."
            pkgs_to_install+=("$pkg")
        else
            echo "$pkg already installed, skipping."
            echo "$pkg" >> "$SKIPPED_LOG"
        fi
    done

    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        if $DRY_RUN; then
            echo "Would install formulas: ${pkgs_to_install[*]}"
        else
            brew install "${pkgs_to_install[@]}" 2>>"$ERROR_LOG"
        fi
    fi
}

install_cask() {
    local casks_to_install=()
    for cask in "$@"; do
        if ! brew list --cask "$cask" &>/dev/null; then
            echo "Queuing cask $cask..."
            casks_to_install+=("$cask")
        else
            echo "$cask already installed, skipping."
            echo "$cask" >> "$SKIPPED_LOG"
        fi
    done

    if [[ ${#casks_to_install[@]} -gt 0 ]]; then
        if $DRY_RUN; then
            echo "Would install casks: ${casks_to_install[*]}"
        else
            brew install --cask "${casks_to_install[@]}" 2>>"$ERROR_LOG"
        fi
    fi
}

setup_skim_transparency() {
    echo "Configuring Skim for translucent PDF view..."

    if ! brew list --cask skim &>/dev/null; then
        echo "Skim not installed yet — skipping transparency config."
        return
    fi

    if $DRY_RUN; then
        echo "Would write Skim defaults: SKPaperMode = 1 (Translucent)"
        return
    fi

    defaults write "$SKIM_BUNDLE_ID" SKPaperMode -int 1
    defaults write "$SKIM_BUNDLE_ID" SKPaperTranslucent -bool YES
    defaults write "$SKIM_BUNDLE_ID" SKBackgroundMode -int 1

    if is_installed killall; then
        killall Skim 2>/dev/null || true
    fi

    echo "Skim configured. Reopen PDFs to see the translucent background."
}

install_xcode_tools() {
    if ! xcode-select -p &>/dev/null; then
        echo "Installing Xcode Command Line Tools..."
        run_or_print xcode-select --install
    else
        echo "Xcode Command Line Tools already installed, skipping."
        echo "xcode-select" >> "$SKIPPED_LOG"
    fi
}

sys_prep() {
    echo "Installing system essentials..."
    install_package \
        git curl wget stow \
        htop fastfetch ripgrep fzf tmux \
        tree jq xz zip unzip \
        openssh gh \
        nmap redis sqlite
}

install_languages() {
    echo "Installing language toolchains..."
    install_package \
        clang cmake make go rustup nodejs npm \
        python python-setuptools python-virtualenv pipx \
        r ruby

    if is_installed rustup; then
        run_or_print rustup default stable
    fi
}

install_terminal() {
    echo "Installing terminal and fonts..."
    install_cask alacritty
    install_cask font-jetbrains-mono-nerd font-font-awesome font-fira-code-nerd
    install_package starship
}

install_pdf_viewers() {
    echo "Installing PDF viewers..."
    install_cask skim
    setup_skim_transparency
}

install_apps() {
    echo "Installing applications..."
    install_cask \
        docker \
        firefox \
        rectangle \
        hammerspoon \
        alfred \
        1password \
        bitwarden \
        visual-studio-code \
        iterm2
}

install_multimedia() {
    echo "Installing multimedia tools..."
    install_package ffmpeg imagemagick ghostscript
    install_cask vlc handbrake
}

install_latex() {
    echo "Installing LaTeX (MacTeX)..."
    install_cask mactex
}

install_editors() {
    echo "Installing editors..."
    install_package vim neovim
}

install_dotfiles() {
    local target="$HOME/.dotfiles"

    if [[ ! -d "$target" ]]; then
        git clone https://github.com/chrporter22/dotfiles.git "$target"
    fi

    cd "$target" || exit
    stow --target="$HOME" alacritty nvim tmux starship 2>>"$ERROR_LOG"
}

install_plugins() {
    local nvim_lazy_path="$HOME/.local/share/nvim/lazy/lazy.nvim"
    if [[ ! -d "$nvim_lazy_path" ]]; then
        git clone https://github.com/folke/lazy.nvim.git "$nvim_lazy_path"
    else
        echo "Lazy.nvim already installed, skipping."
    fi

    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    else
        echo "TPM already installed, skipping."
    fi

    echo "After setup, run tmux and press Prefix + I to install plugins."
}

report_status() {
    echo -e "\n===== INSTALLATION SUMMARY ====="

    echo -e "\nArchitecture:"
    uname -m

    echo -e "\nInstalled Brew Formulas:"
    brew list 2>/dev/null | head -40 || echo "None"

    echo -e "\nInstalled Brew Casks:"
    brew list --cask 2>/dev/null | head -40 || echo "None"

    echo -e "\nInstalled Dotfiles:"
    ls "$HOME/.dotfiles" 2>/dev/null || echo "Dotfiles directory missing."

    echo -e "\nSkim transparency settings:"
    defaults read "$SKIM_BUNDLE_ID" 2>/dev/null | grep -E "(SKPaper|SKBackground)" || echo "Not yet set."

    echo -e "\nPackages Skipped:"
    sort "$SKIPPED_LOG" 2>/dev/null | uniq || echo "None"

    echo -e "\nErrors (if any):"
    if [[ -s "$ERROR_LOG" ]]; then
        cat "$ERROR_LOG"
    else
        echo "No installation errors logged."
    fi
}

main() {
    install_xcode_tools
    install_brew
    sys_prep
    install_languages
    install_terminal
    install_pdf_viewers
    install_apps
    install_multimedia
    install_latex
    install_editors
    install_dotfiles
    install_plugins
    report_status

    echo -e "\n===== NEXT STEPS ====="
    echo "1. Open Skim once so the defaults take effect, then reopen PDFs."
    echo "2. Launch Docker Desktop from Applications to finish setup."
    echo "3. Open tmux and press Prefix + I to install tmux plugins."
}

main
