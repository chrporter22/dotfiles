#!/usr/bin/env bash

# =============================================
# ARCH LIVE ISO SETUP — thin-shell bootstrap
# ---------------------------------------------
# Run after booting the official Arch live ISO
# on a thumb drive / SSD. Idempotent; safe to
# re-run each boot (the live environment is not
# persistent). Installs the i3 desktop stack —
# i3-gaps, polybar, rofi, dmenu, alacritty,
# tmux, neovim, docker — clones the dotfiles
# repo and stows it. Does NOT install the data
# science stack: this machine is a thin shell
# that SSHes into the M6 Mac Mini for work.
#
# Manual prerequisites:
#     iwctl station wlan0 connect <SSID> --passphrase <PSK>
#     pacman -Sy git
#     git clone <repo-url> ~/.dotfiles
#     bash ~/.dotfiles/arch_live_iso_setup.sh
# =============================================

DOTFILES_REPO="https://github.com/chrporter22/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
STOW_PACKAGES=(i3 picom polybar rofi alacritty xresources backgrounds nvim tmux)

DRY_RUN=false
SKIPPED_LOG="$HOME/install_skipped_packages.log"
ERROR_LOG="$HOME/install_errors.log"

case "$1" in
    --dry-run)
        DRY_RUN=true
        echo "Dry run mode enabled. No changes will be made."
        : > "$SKIPPED_LOG"
        : > "$ERROR_LOG"
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

pacman_cmd() {
    if (( EUID == 0 )); then
        pacman "$@"
    else
        sudo pacman "$@"
    fi
}

run_or_print() {
    if $DRY_RUN; then
        echo "Would run: $*"
    else
        "$@" 2>>"$ERROR_LOG"
    fi
}

install_package() {
    local pkgs_to_install=()
    for pkg in "$@"; do
        if pacman -Qq "$pkg" &>/dev/null; then
            echo "$pkg already installed, skipping."
            echo "$pkg" >> "$SKIPPED_LOG"
        else
            echo "Queuing $pkg for installation..."
            pkgs_to_install+=("$pkg")
        fi
    done

    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        if $DRY_RUN; then
            echo "Would install: ${pkgs_to_install[*]}"
        else
            pacman_cmd -S --noconfirm --needed "${pkgs_to_install[@]}" 2>>"$ERROR_LOG"
        fi
    fi
}

keyring_init() {
    if $DRY_RUN; then
        echo "Would run: pacman -Sy archlinux-keyring"
        return
    fi
    echo "Refreshing archlinux-keyring..."
    pacman_cmd -Sy --noconfirm archlinux-keyring 2>>"$ERROR_LOG" || true
}

install_live_prereqs() {
    echo "Installing live prereqs..."
    install_package \
        git stow openssh sudo \
        vim neovim tmux alacritty \
        htop fastfetch ripgrep fzf tree jq gh
}

install_xorg_stack() {
    echo "Installing Xorg + display tools..."
    install_package \
        xorg-server xorg-xinit xorg-apps \
        xclip xdotool maim arandr libxcb xorg-xrandr \
        kbd xorg-xrdb brightnessctl
}

install_wm_desktop() {
    echo "Installing WM + desktop stack..."
    install_package \
        i3-gaps i3status \
        polybar rofi dmenu picom \
        feh dex xss-lock i3lock \
        xdg-utils dbus dbus-x11
}

install_audio() {
    echo "Installing audio..."
    install_package \
        pulseaudio pulseaudio-alsa alsa-utils \
        pulseaudio-jack pulseaudio-equalizer pavucontrol
}

install_network_tray() {
    echo "Installing Bluetooth + network tray..."
    install_package \
        bluez bluez-utils blueman \
        networkmanager network-manager-applet
}

install_fonts() {
    echo "Installing Nerd Fonts..."
    install_package \
        ttf-jetbrains-mono-nerd ttf-font-awesome \
        ttf-firacode-nerd ttf-meslo-nerd
}

install_containers() {
    echo "Installing docker..."
    install_package docker
}

clone_or_update_dotfiles() {
    echo "Syncing dotfiles into $DOTFILES_DIR..."
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        if $DRY_RUN; then
            echo "Would clone $DOTFILES_REPO into $DOTFILES_DIR"
            return
        fi
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR" 2>>"$ERROR_LOG" || {
            echo "Dotfiles clone failed." >&2
            echo "Dotfiles clone failed" >> "$ERROR_LOG"
            return
        }
    else
        if $DRY_RUN; then
            echo "Would pull $DOTFILES_DIR"
            return
        fi
        (cd "$DOTFILES_DIR" && git pull --ff-only 2>>"$ERROR_LOG") || true
    fi
}

stow_dotfiles() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        echo "Dotfiles directory missing — skipping stow." >&2
        return
    fi
    echo "Stowing: ${STOW_PACKAGES[*]}"
    for pkg in "${STOW_PACKAGES[@]}"; do
        if [[ ! -d "$DOTFILES_DIR/$pkg" ]]; then
            echo "$pkg not present in dotfiles repo, skipping." >&2
            continue
        fi
        if $DRY_RUN; then
            echo "Would stow: $pkg"
            continue
        fi
        (cd "$DOTFILES_DIR" && stow --target="$HOME" "$pkg" 2>>"$ERROR_LOG") || true
    done
}

write_xinitrc() {
    local xinitrc="$HOME/.xinitrc"

    if [[ -f "$xinitrc" ]]; then
        echo "$xinitrc already exists, skipping."
        echo "xinitrc" >> "$SKIPPED_LOG"
        return
    fi

    if $DRY_RUN; then
        echo "Would write $xinitrc (feh wallpaper, dbus-launch, exec i3)"
        return
    fi

    cat > "$xinitrc" <<'EOF'
#!/bin/sh
# Set wallpaper from the stowed backgrounds folder if present.
if [ -f "$HOME/.config/backgrounds/wallpaper.jpg" ]; then
    feh --bg-scale "$HOME/.config/backgrounds/wallpaper.jpg" &
fi

# Merge X resources (xrdb ships with xorg-xrdb).
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

# Start i3 inside a dbus session so nm-applet, blueman, etc. work.
exec dbus-launch --exit-with-session i3
EOF
    chmod +x "$xinitrc"
    echo "Wrote $xinitrc"
}

enable_services() {
    if ! is_installed systemctl; then
        echo "systemctl not available — skipping service enable."
        return
    fi

    if [[ "$(systemctl is-system-running 2>/dev/null)" != "running" ]]; then
        echo "systemd is not running (live ISO without init?) — skipping service enable."
        return
    fi

    if $DRY_RUN; then
        echo "Would: systemctl enable --now NetworkManager docker"
        return
    fi

    systemctl enable --now NetworkManager 2>>"$ERROR_LOG" || true
    systemctl enable --now docker 2>>"$ERROR_LOG" || true
}

report_status() {
    echo -e "\n===== INSTALLATION SUMMARY ====="

    echo -e "\nArchitecture:"
    uname -m

    echo -e "\nDotfiles:"
    if [[ -d "$DOTFILES_DIR" ]]; then
        ls "$DOTFILES_DIR"
    else
        echo "Dotfiles directory missing."
    fi

    echo -e "\nXinitrc:"
    if [[ -f "$HOME/.xinitrc" ]]; then
        echo "$HOME/.xinitrc present"
    else
        echo "missing"
    fi

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
    keyring_init
    install_live_prereqs
    install_xorg_stack
    install_wm_desktop
    install_audio
    install_network_tray
    install_fonts
    install_containers
    clone_or_update_dotfiles
    stow_dotfiles
    write_xinitrc
    enable_services
    report_status

    echo -e "\n===== NEXT STEPS ====="
    echo "1. startx                                 — start the i3 session"
    echo "2. SSH into the M6 Mac Mini (the script installed openssh for you):"
    echo "     a. ssh-keygen -t ed25519              — create a key (once per ISO)"
    echo "     b. ssh-copy-id user@mac-mini.local   — install the key on the Mac Mini"
    echo "     c. ssh user@mac-mini.local           — connect manually"
    echo "     Optional: edit ~/.ssh/config to add a Host mm block for shortcuts."
    echo "3. Inside i3: Mod1+Return for Alacritty, Mod1+d for Rofi, Mod1+Shift+e to exit"
}

main
