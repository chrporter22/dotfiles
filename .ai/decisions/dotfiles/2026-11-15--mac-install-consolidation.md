# Consolidate macOS installs into one script

- **Date:** 2026-11-15
- **Decided by:** user
- **Topic:** dotfiles

## Decision

The macOS setup ships as a single installer, `data_sci_install_mac.sh`. The second macOS script (`arch_setup_mac.sh`) is removed.

The one installer covers both intents — system tooling and the data-science stack — with a trimmed package list that installs only what macOS does not already provide:

- Kept as the system layer: Homebrew, core CLI utilities, language toolchains, Alacritty, Skim with a translucent background, Docker Desktop, Firefox, VS Code, MacTeX, and the Nerd Fonts.
- Kept as the data layer: PostgreSQL, MySQL, Redis, numeric libraries (GSL, OpenBLAS, HDF5, NetCDF), nmap, and the Python data stack.
- Dropped because macOS or the Xcode Command Line Tools already provide them: curl, unzip, zip, xz, openssl, sqlite, clang.
- Dropped as not needed on this machine: Ruby, iTerm2, password managers, third-party window managers and launchers, and the multimedia toolchain.
- Starship is not installed; its dotfile folder has no consumer in the shell configuration.

The Python data-science packages live in an isolated virtual environment managed by `uv` rather than a user-site install.

## Why

- Two macOS scripts had drifted into near-duplicates with divergent package lists, so the same tool was present in one and missing from the other. One script removes that failure mode.
- macOS ships much of the generic system tooling already; installing it again through Homebrew adds time and version conflict risk without benefit.
- The data-science work needs an isolated Python environment. Installing into the system interpreter conflicts with Homebrew Python's managed-environment protections, and a dedicated environment keeps the system interpreter clean.
- One terminal (Alacritty) and one Python environment per machine keeps a single configuration surface to maintain.

## Supersedes / relates to

- Reverses the "two distinct intents / two scripts" part of `2026-11-14--mac-mini-install-setup.md`; the tooling rules from that decision (Homebrew, Alacritty, Skim, Stow, Docker Desktop) still stand.
- Confirms the Alacritty-only terminal rule: iTerm2 is not installed.
