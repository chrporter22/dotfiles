# macOS install setup for new M6 Mac Mini Studio

- **Date:** 2026-11-14
- **Decided by:** user
- **Topic:** dotfiles

## Decision

For the new M6 Mac Mini Studio (base model), add two fresh macOS install scripts alongside the existing Arch Linux scripts. They merge the two Arch setups (`data_sci_install.sh` and `deploy_arch_tools.sh`) into single macOS workflows, one for data science and one for general system tools.

Tooling rules on macOS:

- Package manager: Homebrew.
- Terminal: Alacritty (not iTerm2 / Terminal2).
- PDF viewer: Skim, with a translucent background so it matches the rest of the theme. Zathura is not used on macOS.
- Dotfiles: GNU Stow manages symlinks.
- Container runtime: Docker Desktop.
- Both scripts install the full set of merged tools — every CLI / language / font / GUI app from the existing Arch setups that has a macOS equivalent.

The existing two Arch scripts stay untouched.

## Why

- One Mac Mini machine, two distinct intents (data-science work vs. general system). Mirroring the two existing Arch scripts keeps the mental model the same on both operating systems.
- Alacritty is already configured in the repo's `alacritty/` dotfile folder, so reusing it keeps a single terminal experience across machines. iTerm2 would mean a second config surface.
- Skim is the macOS-native PDF viewer. Translucent mode mirrors the role `zathura-pywal` plays on Arch (transparent PDF over a themed desktop) without needing XQuartz.
- Homebrew is the standard for macOS CLI tooling; the merged package list comes directly from the existing pacman installs.
- Stow and Docker are non-negotiable parts of the existing setup, so they are explicit in the new scripts.
- Keeping the Arch scripts unchanged means the existing Raspberry Pi / ThinkPad workflow is unaffected — the mac scripts are additive only.

## Supersedes / relates to

- Builds on the tool lists in `data_sci_install.sh` and `deploy_arch_tools.sh` at the repo root.
- Aligns with the dotfile layout under `alacritty/`, `nvim/`, `tmux/`, `starship/`, which the new scripts symlink into `$HOME` via stow.
