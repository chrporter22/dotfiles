# Arch live ISO thin-shell bootstrap

- **Date:** 2026-11-15
- **Decided by:** user
- **Topic:** dotfiles

## Decision

Add a third Arch installer, `arch_live_iso_setup.sh`, alongside the existing `data_sci_install.sh` and `deploy_arch_tools.sh`. The new script is a post-boot bootstrap for the official Arch live ISO running on the HP 8 GB laptop, which acts as a thin SSH frontend to the M6 Mac Mini.

The script is idempotent and re-runnable: the live environment is non-persistent, so on every boot the user runs the script (after connecting WiFi with `iwctl` and installing `git`). The script clones or pulls the dotfiles repo, stows the i3 + terminal + SSH toolchain, writes `~/.xinitrc` with `exec i3`, writes a `~/.ssh/config` template with a `Host mm` placeholder plus a `~/bin/mm` shim, and enables NetworkManager and Docker if systemd is running.

Packages installed (no data-science stack on this machine):

- Live prereqs: git, stow, openssh, sudo, vim, neovim, tmux, alacritty, htop, fastfetch, ripgrep, fzf, tree, jq, gh
- Xorg + display: xorg-server, xorg-xinit, xorg-apps, xclip, xdotool, maim, arandr, libxcb, xorg-xrandr, kbd, xorg-xrdb, brightnessctl
- WM + desktop: i3-gaps, i3status, polybar, rofi, dmenu, picom, feh, dex, xss-lock, i3lock, xdg-utils, dbus, dbus-x11
- Audio: pulseaudio, pulseaudio-alsa, alsa-utils, pulseaudio-jack, pulseaudio-equalizer, pavucontrol
- Bluetooth + network tray: bluez, bluez-utils, blueman, networkmanager, network-manager-applet
- Fonts: ttf-jetbrains-mono-nerd, ttf-font-awesome, ttf-firacode-nerd, ttf-meslo-nerd
- Containers: docker

Stowed packages: i3, picom, polybar, rofi, alacritty, xresources, backgrounds, nvim, tmux.

The script does not touch WiFi (manual before invocation), does not install the data-science stack, and does not install `archiso`-specific tooling for building a custom ISO. The existing two Arch scripts and the macOS installer are unchanged.

## Why

- The HP laptop's only role is to be a thin frontend for SSHing into the M6 Mac Mini, so the heavy data-science stack belongs on the Mac Mini, not on the live ISO.
- Live ISO is non-persistent by design, so the script must be re-runnable on every boot and must clone (or pull) the dotfiles repo each time rather than relying on a stable checkout.
- Stow from the cloned repo reuses every existing config in the repo (i3 keybindings, picom transparency, tmux, nvim, polybar, rofi catppuccin theme, wallpapers), so the local experience matches the installed Arch setups.
- WiFi on the live ISO requires interactive `iwctl`; automating it would add a credential-handling surface for no real benefit.
- The `mm` shim gives a single command to reach the Mac Mini once the user fills in the placeholder `~/.ssh/config`, keeping the connection path explicit and version-controlled.

## Supersedes / relates to

- Adds a third installer alongside `data_sci_install.sh` (installed Arch data science) and `deploy_arch_tools.sh` (installed Arch system tools); does not modify them.
- Shares stow conventions with the macOS installer (`data_sci_install_mac.sh`).
- README gained a new top section describing the live ISO flow.
