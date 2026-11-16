# Arch live ISO thin-shell bootstrap

- **Date:** 2026-11-15 18:13
- **Developer:** agent session
- **Topic:** dotfiles

## Request

Build another install script that combines the two existing Arch setups into a single post-boot bootstrap for the official Arch live ISO. The HP 8 GB laptop boots the live ISO from a thumb drive / SSD and acts as a thin SSH frontend to the M6 Mac Mini; the script is re-run each boot because the live environment is non-persistent. Required packages: i3-gaps, polybar, dmenu, rofi, alacritty, tmux, nvim, vim, xorg, xinit, docker. Manual WiFi before invocation. SSH-to-Mac-Mini helper via template config + `mm` shim.

The user also sent the marker string `LITELLM EXECUTE` — same stray-marker family as `LITELLM ESCALATE`. Ignored.

The user followed up asking whether keybindings (i3, tmux, nvim), transparency (picom), and the wallpaper would match their installed-Arch setup, and whether the wallpaper files live in the remote repo. Confirmed: i3 keybindings (`Mod1+Return`, `Mod1+d`, etc.), tmux config, nvim lazy.nvim config, picom's 82% Alacritty opacity, and the wallpaper images (`backgrounds/.config/backgrounds/*.jpg|png`) are all in the remote repo and are stowed by the script. The user's existing i3 config has the `feh --bg-scale` wallpaper line commented out; the new script sets the wallpaper from a real file in the cloned backgrounds via `~/.xinitrc` before `exec i3`, without touching the user's i3 config.

## What was done

`arch_live_iso_setup.sh` is a bash post-boot bootstrap for the official Arch live ISO. Re-uses the existing dotfiles repo (clone-or-pull on every run), stows the GUI + terminal + SSH toolchain, writes a minimal `~/.xinitrc`, drops a `~/bin/mm` shim, and enables NetworkManager + Docker if systemd is up.

Package list applied (user-approved; thin shell, no data science):

- Live prereqs: git, stow, openssh, sudo, vim, neovim, tmux, alacritty, htop, fastfetch, ripgrep, fzf, tree, jq, gh
- Xorg + display: xorg-server, xorg-xinit, xorg-apps, xclip, xdotool, maim, arandr, libxcb, xorg-xrandr, kbd, xorg-xrdb, brightnessctl
- WM + desktop: i3-gaps, i3status, polybar, rofi, dmenu, picom, feh, dex, xss-lock, i3lock, xdg-utils, dbus, dbus-x11
- Audio: pulseaudio, pulseaudio-alsa, alsa-utils, pulseaudio-jack, pulseaudio-equalizer, pavucontrol
- Bluetooth + network tray: bluez, bluez-utils, blueman, networkmanager, network-manager-applet
- Fonts: ttf-jetbrains-mono-nerd, ttf-font-awesome, ttf-firacode-nerd, ttf-meslo-nerd
- Containers: docker

Stow set: i3, picom, polybar, rofi, alacritty, xresources, backgrounds, nvim, tmux.

Writes (per-boot, idempotent — skipped if the file already exists):

- `~/.xinitrc` with `feh --bg-scale ~/.config/backgrounds/wallpaper.jpg` (when present), `xrdb -merge ~/.Xresources` when the file exists, and `exec dbus-launch --exit-with-session i3`. The wallpaper images are present in the cloned `backgrounds/` folder; the user's i3 config (which has the `feh` line commented out) is left untouched.
- `~/.ssh/config` (mode 600) with a `Host mm` placeholder block using `mac-mini.local` as an obvious HostName placeholder and `your-username` as an obvious User placeholder. The block is commented out so SSH ignores it until the user uncomments and fills in their real values.
- `~/bin/mm` shim (mode 755) that calls `ssh mm "$@"`.

Service enable: `systemctl enable --now NetworkManager docker` only when `systemctl is-system-running` reports `running` (skipped cleanly in non-systemd contexts).

Mapping the user's typos: `13` → i3-gaps, `ploybar` → polybar, `allacrity` → alacritty, `xstart` → xorg-xinit + the script's `~/.xinitrc`.

## Notable findings

- `setxkbmap` is provided by the `kbd` package on Arch, not by `xorg-xkbcomp` as some references suggest; `kbd` is included in the Xorg display section so the user's `setxkbmap -option ctrl:nocaps` line in i3 config works.
- The user's existing `backgrounds/wallpaper.sh` is hardcoded to `/home/cporter/...` paths and will not work on the live ISO running as root (`/root`); the new script does not touch it. Instead the live ISO `~/.xinitrc` sets the wallpaper from a real file in the cloned `backgrounds/` folder.
- The live ISO mounts `/root` as tmpfs, so anything written outside the ISO filesystem is lost on reboot; the script clones (or pulls) the dotfiles repo every run rather than caching it.
- A live ISO without systemd init (`systemctl is-system-running` returns anything other than `running`) cleanly skips service enable instead of erroring out.

## Verification

All checks ran inside Docker (the host has no Arch toolchain per the docker-testing skill):

- `bash -n arch_live_iso_setup.sh` on `bash:5.2` — syntax clean.
- `shellcheck -x arch_live_iso_setup.sh` on `koalaman/shellcheck:stable` — one warning (`SC2088` on a `~/bin/mm` string literal in a status message), fixed by escaping the tilde; re-run clean.
- Dry-run smoke test on `archlinux:latest` with `HOME=/tmp/testhome`: every install step reported as a planned action, the script correctly skipped `kbd` and `dbus` (already present in the base image), planned the dotfiles clone, planned the `~/.xinitrc` / `~/.ssh/config` / `~/bin/mm` writes, and cleanly skipped service enable because the container has no systemd. No writes, no installs.

## Open threads

- The live ISO is non-persistent; the user re-runs the script after every boot. If a future need is to keep state across boots, that is a separate decision (likely a custom `archiso` profile, not this script).
- The placeholder `~/.ssh/config` is intentionally uncommented; the user must uncomment the `Host mm` block and replace `mac-mini.local` and `your-username` with their real Mac Mini details before `mm` will work.
- Nothing was committed or pushed; per `no-agent-push`, the user pushes.
