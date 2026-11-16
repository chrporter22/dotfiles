# Mac install script — alacritty transparency

- **Date:** 2026-11-15 21:54
- **Developer:** agent session
- **Topic:** dotfiles

## Request

Review `data_sci_install_mac.sh` and add alacritty transparency on macOS. Do not change the dotfile's `alacritty.toml` or `catppuccin-mocha.toml` — set it up from the install script. Note: macOS has no i3wm, so alacritty has to provide its own transparency (Arch uses picom).

`LITELLM ESCALATE` marker is the same stray string recorded in earlier sessions — ignored.

## Plan (user-approved)

- Add `setup_alacritty_transparency()` that writes `~/.config/alacritty/macos.toml` containing the `[window]` block and an import of the existing dotfile config. macos.toml is a sibling of the stow-managed `alacritty.toml`; stow does not own it, so the dotfile repo stays unchanged.
- Set `ALACRITTY_CONFIG=$HOME/.config/alacritty/macos.toml` via `~/.zshrc` (idempotent append).
- Call from `main()` after `install_dotfiles`.
- Extend `report_status()` to surface the macos.toml path and the active `[window]` settings.
- Update NEXT STEPS to call out the Finder/Dock `launchctl setenv` requirement.
- Two minor fixes rolled in: `install_brew` writes the skipped-log entry after `eval` succeeds; `report_status` reuses `find_brew` instead of `is_installed brew` so it can report on a Homebrew that's installed but not on the script subshell's PATH.

## What was done

`data_sci_install_mac.sh` only — no other files in the dotfile repo touched (the existing alacritty.toml and catppuccin-mocha.toml are byte-identical to before; verified with `git diff alacritty/` showing clean).

- **New `setup_alacritty_transparency()`** (~57 lines) — guards on `brew list --cask alacritty`; under dry-run it prints what it would write; otherwise writes `~/.config/alacritty/macos.toml` containing a `general.import` of the stow-managed `alacritty.toml` plus `[window] opacity = $ALACRITTY_OPACITY (default 0.85), blur = true`. The file lives in `$HOME/.config/alacritty/`, which stow does not own (the dotfile repo path is `alacritty/.config/alacritty/`, a different directory from the user's home). Appends `export ALACRITTY_CONFIG=...` to `~/.zshrc` only if `ALACRITTY_CONFIG=` isn't already present.
- **`install_brew` fix** — skipped-log entry now written after `eval "$brew_bin" shellenv"` succeeds, via an `already_installed` flag, instead of unconditionally before the eval.
- **`report_status` fix** — `is_installed brew` replaced with `find_brew` so the summary stays accurate when Homebrew is installed at `/opt/homebrew/bin/brew` but not on PATH in the script's subshell.
- **`report_status` extension** — new "Alacritty macOS overlay" section reports the macos.toml path, the active `opacity`/`blur` values, and whether the `ALACRITTY_CONFIG` export is present in `~/.zshrc`.
- **`main()`** — `setup_alacritty_transparency` called after `install_dotfiles`, so the stow-managed config exists before the overlay is written.
- **NEXT STEPS** — added step 5 documenting the new shell prompt / `launchctl setenv` / LaunchAgent for Finder-launched Alacritty.

## Notable findings

- macOS GUI launches of Alacritty inherit env vars from `launchd`, not the shell. `~/.zshrc` alone isn't enough for Finder/Dock launches. Documented in NEXT STEPS — the script intentionally does NOT auto-install a LaunchAgent (too invasive), but the user can drop `~/Library/LaunchAgents/local.alacritty-env.plist` to make it persistent across reboots.
- Alacritty's import chain handles our setup cleanly: `macos.toml` → imports `alacritty.toml` → imports `catppuccin-mocha.toml`. Imports are processed depth-first before the parent config is finalised, so macos.toml's `[window]` block is the final word and overrides anything in the dotfile's window section (the dotfile currently has none, so this is future-proofing).
- Stow only creates symlinks for files it knows about (`alacritty/.config/alacritty/alacritty.toml` and `catppuccin-mocha.toml`). A new file at `~/.config/alacritty/macos.toml` does not conflict with stow; `stow --restow` will not touch it. The header comment in the generated macos.toml calls this out.
- The unquoted heredoc `<<EOF` does command substitution on backticks; the original draft of the comment line referenced `` `stow --restow` `` and on macOS that would have evaluated to an empty string (since `stow --restow` without further args is a no-op). Escaped the backticks as `` \` `` to keep them literal in the generated file. Caught during verification.

## Verification

All checks ran inside Docker (`zshusers/zsh:5.9`), never on the host:

- `zsh -n data_sci_install_mac.sh` — syntax clean.
- `--dry-run` with a clean `HOME` (no brew, no alacritty, no dotfiles): every install and clone step reported as a planned action; `setup_alacritty_transparency` correctly skipped (alacritty cask not installed); Skim and dotfile steps also skipped per their guards; `report_status` showed "Homebrew not found" against the empty stub list.
- `--dry-run` with stubbed brew claiming all formulas/casks installed and a pre-populated `~/.dotfiles`: stow produced real symlinks for `~/.config/alacritty/{alacritty.toml,catppuccin-mocha.toml}`; the transparency overlay was correctly reported as "Would write Alacritty macOS overlay" with the right import path, opacity 0.85, blur true, and the right `~/.zshrc` export.
- Real (non-dry-run) run with the same stubbed setup: `~/.config/alacritty/macos.toml` was actually written with the literal backticks intact; `~/.zshrc` got a single `export ALACRITTY_CONFIG=...` line; Skim defaults were recorded against the stub `defaults` command.
- Idempotency: second real run printed "ALACRITTY_CONFIG already set in ~/.zshrc, leaving alone." and the `.zshrc` still contained exactly one `export ALACRITTY_CONFIG=...` line.

ShellCheck was not run: it does not parse zsh and produces false positives on these scripts.

## Open threads

- The 2026-11-14 mac-mini decision confirms Alacritty as the only terminal. This change extends that — Alacritty now also self-provides transparency that Arch gets from picom. No reversal.
- GUI-launches-from-Finder still need a manual `launchctl setenv` or a LaunchAgent; the install script intentionally does not author one. If we want Finder-launched Alacritty translucent out of the box, that would be a follow-up that adds the LaunchAgent.
- Nothing was pushed; the user pushes.
