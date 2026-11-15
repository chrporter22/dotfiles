# Mac install script review

- **Date:** 2026-11-15 17:25
- **Developer:** agent session
- **Topic:** dotfiles

## Request

Review the two macOS install scripts (`arch_setup_mac.sh`, `data_sci_install_mac.sh`) because they are duplicative. Desired end state: one script — the data science mac install — that also covers the system tools (Alacritty, Skim, Docker), trimmed to only what macOS does not already provide.

The user also sent the marker string `LITELLM ESCALATE` — the same stray marker recorded in the 2026-11-14 mac-install session. Ignored.

## What was done

`data_sci_install_mac.sh` is now the single macOS installer; `arch_setup_mac.sh` was deleted. `README.md` gained a short macOS install section.

Package list applied (user-approved): core CLI (`git wget stow htop fastfetch ripgrep fzf tmux tree jq gh`), toolchains (`cmake make go rustup nodejs npm python r pipx uv`), data libraries (`gsl openblas hdf5 netcdf`), databases and network (`postgresql mysql redis nmap`), editors (`vim neovim`), casks (`alacritty skim docker firefox visual-studio-code mactex` plus the three Nerd Fonts).

Removed as redundant with macOS / Xcode CLT: `curl`, `unzip`, `zip`, `xz`, `openssl`, `sqlite`, `clang`. Removed as unwanted: `ruby`, `iTerm2`, password managers, third-party window managers and launchers, multimedia toolchain, deprecated `python-setuptools` and `python-virtualenv`. Starship was dropped at the user's request — the repo's starship dotfile has no consumer in the shell configuration, so it was dropped from both the package list and the stow list.

Bug fixes applied to the installer:

- Homebrew detection now probes `/opt/homebrew/bin/brew` and `/usr/local/bin/brew` before falling back to `PATH`, so the installer no longer re-runs on a machine that already has Homebrew but no shell profile loaded.
- The Homebrew bootstrap call is now guarded by dry-run mode (it previously ran for real during `--dry-run`).
- Skim transparency configuration now reports what it would write during `--dry-run`; the "is Skim installed" check used to run first and always suppressed the message.
- The Python data stack installs into an isolated `uv` virtual environment at `~/.venvs/data-science` instead of `pip install --user` against a PEP 668 externally-managed interpreter.
- `report_status` fallback messages now print correctly (the `||` previously bound to `head`, never to the failing command).
- `install_dotfiles` no longer exits the whole script when the clone fails; it logs and returns. Stow runs in a subshell so the script's working directory is unchanged.
- Plugin clones (lazy.nvim, TPM) are dry-run guarded.
- The Xcode Command Line Tools install now waits for completion (bounded) so compiler-dependent Homebrew formulas do not race it.
- Added `--help` usage output.

## Notable findings

- The two scripts shared roughly 250 identical lines while their package lists had drifted apart, which is the real cost of the duplication rather than the shared boilerplate itself.
- Homebrew's Python is PEP 668 externally-managed, so `ensurepip --upgrade` and `pip install --upgrade pip` fail there as well; a virtual environment is the only clean route for the data stack.
- macOS already ships `sqlite3` (at `/usr/bin/sqlite3`), `curl`, `unzip`, `zip`, `xz` and an `openssl` binary, and the Xcode Command Line Tools supply `clang` and `make` (GNU make 3.81, which is why Homebrew `make` is kept).
- macOS has no built-in port scanner; `ping`, `traceroute`, `netstat` and `tcpdump` do not cover what nmap does, so nmap was kept.
- `iTerm2` was being installed by `arch_setup_mac.sh` even though the 2026-11-14 decision named Alacritty as the only terminal. Removed.

## Verification

All checks ran inside Docker (`zshusers/zsh:5.9`), never on the host:

- `zsh -n data_sci_install_mac.sh` — syntax clean.
- Dry run with no Homebrew present: every install and clone step reported as a planned action, Skim defaults and virtual-environment creation reported correctly, no network calls and no writes outside the container's temporary `HOME`.
- Dry run with a stubbed Homebrew: detected the existing install at the Apple-Silicon prefix, skipped an already-installed formula and an already-installed cask, and recorded both in the skipped-package log.

ShellCheck was not run: it does not parse zsh and produces false positives on these scripts.

## Open threads

- The 2026-11-14 decision file records "two distinct intents" and "Alacritty (not iTerm2)". The consolidation reverses the first part, so `2026-11-15--mac-install-consolidation.md` records the reversal and the new package policy.
- Nothing was pushed; the user pushes.
