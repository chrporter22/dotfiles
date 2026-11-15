#!/usr/bin/env zsh

# =============================================
# MACOS INSTALLER — M6 Mac Mini Studio
# ---------------------------------------------
# Single macOS installer: system tooling + data science.
# Homebrew formulas and casks, GNU Stow dotfiles,
# uv-managed Python virtualenv for the data stack.
# Terminal: Alacritty. PDF viewer: Skim (translucent).
# Container runtime: Docker Desktop.
# =============================================

DRY_RUN=false
SKIPPED_LOG="$HOME/install_skipped_packages.log"
ERROR_LOG="$HOME/install_errors.log"
SKIM_BUNDLE_ID="net.sourceforge.skim-app.skim"
VENV_DIR="$HOME/.venvs/data-science"

case "$1" in
    --dry-run)
        DRY_RUN=true
        echo "Dry run mode enabled. No changes will be made."
        > "$SKIPPED_LOG"
        > "$ERROR_LOG"
        ;;
    -h|--help)
        echo "Usage: $0 [--dry-run]"
        echo "  --dry-run  Print planned actions without changing the machine"
        exit 0
        ;;
esac

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

find_brew() {
    if [[ -x /opt/homebrew/bin/brew ]]; then
        echo "/opt/homebrew/bin/brew"
    elif [[ -x /usr/local/bin/brew ]]; then
        echo "/usr/local/bin/brew"
    elif is_installed brew; then
        command -v brew
    fi
}

install_brew() {
    local brew_bin
    brew_bin="$(find_brew)"

    if [[ -z "$brew_bin" ]]; then
        if $DRY_RUN; then
            echo "Would install Homebrew..."
        else
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>>"$ERROR_LOG"
            brew_bin="$(find_brew)"
        fi
    else
        echo "Homebrew already installed at $brew_bin, skipping."
        echo "brew" >> "$SKIPPED_LOG"
    fi

    if [[ -n "$brew_bin" ]]; then
        eval "$("$brew_bin" shellenv)"
    fi
}

install_package() {
    local pkgs_to_install=()
    for pkg in "$@"; do
        if brew list "$pkg" &>/dev/null; then
            echo "$pkg already installed, skipping."
            echo "$pkg" >> "$SKIPPED_LOG"
        else
            echo "Queuing formula $pkg..."
            pkgs_to_install+=("$pkg")
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
        if brew list --cask "$cask" &>/dev/null; then
            echo "$cask already installed, skipping."
            echo "$cask" >> "$SKIPPED_LOG"
        else
            echo "Queuing cask $cask..."
            casks_to_install+=("$cask")
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

    if $DRY_RUN; then
        echo "Would write Skim defaults: SKPaperMode = 1 (Translucent)"
        return
    fi

    if ! brew list --cask skim &>/dev/null; then
        echo "Skim not installed yet — skipping transparency config."
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
    if xcode-select -p &>/dev/null; then
        echo "Xcode Command Line Tools already installed, skipping."
        echo "xcode-select" >> "$SKIPPED_LOG"
        return
    fi

    if $DRY_RUN; then
        echo "Would run: xcode-select --install"
        return
    fi

    echo "Installing Xcode Command Line Tools..."
    xcode-select --install 2>>"$ERROR_LOG" || true

    echo "Waiting for the Command Line Tools install to finish..."
    local waited=0
    while ! xcode-select -p &>/dev/null; do
        if (( waited >= 300 )); then
            echo "Timed out waiting for Command Line Tools — continuing." >&2
            echo "Timed out waiting for Xcode Command Line Tools" >> "$ERROR_LOG"
            break
        fi
        sleep 10
        (( waited += 10 ))
    done
}

install_core() {
    echo "Installing core CLI tools..."
    install_package \
        git wget stow \
        htop fastfetch ripgrep fzf tmux \
        tree jq gh
}

install_languages() {
    echo "Installing language toolchains..."
    install_package \
        cmake make go rustup nodejs npm \
        python r \
        pipx uv

    if is_installed rustup; then
        run_or_print rustup default stable
    fi
}

install_terminal() {
    echo "Installing terminal and fonts..."
    install_cask alacritty
    install_cask font-jetbrains-mono-nerd font-font-awesome font-fira-code-nerd
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
        visual-studio-code
}

install_data_science() {
    echo "Installing data science libraries and databases..."
    install_package \
        gsl openblas hdf5 netcdf \
        postgresql mysql redis \
        nmap

    setup_python_venv
}

setup_python_venv() {
    echo "Setting up Python data science stack in $VENV_DIR..."

    if [[ ! -d "$VENV_DIR" ]]; then
        if $DRY_RUN; then
            echo "Would create virtual environment: $VENV_DIR"
        else
            uv venv "$VENV_DIR" 2>>"$ERROR_LOG"
        fi
    else
        echo "Virtual environment already exists, skipping creation."
        echo "venv:data-science" >> "$SKIPPED_LOG"
    fi

    if $DRY_RUN; then
        echo "Would install Python packages into $VENV_DIR: numpy pandas scipy matplotlib seaborn scikit-learn jupyterlab"
        return
    fi

    local python_bin="$VENV_DIR/bin/python"

    if [[ ! -x "$python_bin" ]]; then
        echo "Virtual environment Python missing at $python_bin — skipping packages." >&2
        echo "Virtual environment Python missing at $python_bin" >> "$ERROR_LOG"
        return
    fi

    uv pip install --python "$python_bin" \
        numpy pandas scipy matplotlib seaborn scikit-learn jupyterlab 2>>"$ERROR_LOG"
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
        if $DRY_RUN; then
            echo "Would clone dotfiles into $target"
            return
        fi
        git clone https://github.com/chrporter22/dotfiles.git "$target" 2>>"$ERROR_LOG"
    fi

    if [[ ! -d "$target" ]]; then
        echo "Dotfiles clone failed — skipping stow." >&2
        echo "Dotfiles clone failed" >> "$ERROR_LOG"
        return
    fi

    (cd "$target" && stow --target="$HOME" nvim tmux alacritty) 2>>"$ERROR_LOG"
}

install_plugins() {
    local nvim_lazy_path="$HOME/.local/share/nvim/lazy/lazy.nvim"
    if [[ ! -d "$nvim_lazy_path" ]]; then
        if $DRY_RUN; then
            echo "Would clone lazy.nvim into $nvim_lazy_path"
        else
            git clone https://github.com/folke/lazy.nvim.git "$nvim_lazy_path" 2>>"$ERROR_LOG"
        fi
    else
        echo "Lazy.nvim already installed, skipping."
    fi

    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        if $DRY_RUN; then
            echo "Would clone TPM into $HOME/.tmux/plugins/tpm"
        else
            git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" 2>>"$ERROR_LOG"
        fi
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
    if is_installed brew; then
        brew list 2>/dev/null | head -40
    else
        echo "Homebrew not found."
    fi

    echo -e "\nInstalled Brew Casks:"
    if is_installed brew; then
        brew list --cask 2>/dev/null | head -40
    else
        echo "Homebrew not found."
    fi

    echo -e "\nPython data science environment:"
    if [[ -x "$VENV_DIR/bin/python" ]]; then
        echo "$VENV_DIR"
        "$VENV_DIR/bin/python" --version 2>/dev/null
    else
        echo "Not created ($VENV_DIR)."
    fi

    echo -e "\nInstalled Dotfiles:"
    ls "$HOME/.dotfiles" 2>/dev/null || echo "Dotfiles directory missing."

    echo -e "\nSkim transparency settings:"
    defaults read "$SKIM_BUNDLE_ID" 2>/dev/null | grep -E "(SKPaper|SKBackground)" || echo "Not yet set."

    echo -e "\nPackages Skipped:"
    if [[ -s "$SKIPPED_LOG" ]]; then
        sort "$SKIPPED_LOG" | uniq
    else
        echo "None"
    fi

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
    install_core
    install_languages
    install_terminal
    install_pdf_viewers
    install_apps
    install_data_science
    install_latex
    install_editors
    install_dotfiles
    install_plugins
    report_status

    echo -e "\n===== NEXT STEPS ====="
    echo "1. Open Skim once so the defaults take effect, then reopen PDFs."
    echo "2. Launch Docker Desktop from Applications to finish setup."
    echo "3. Activate the data science environment: source $VENV_DIR/bin/activate"
    echo "4. Open tmux and press Prefix + I to install tmux plugins."
}

main
