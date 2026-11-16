# Arch live ISO: SSH into the Mac Mini is set up manually

- **Date:** 2026-11-15
- **Decided by:** user
- **Topic:** dotfiles

## Decision

The Arch live ISO bootstrap script (`arch_live_iso_setup.sh`) no longer auto-writes a `~/.ssh/config` template or a `~/bin/mm` shim. OpenSSH is still installed by the script (it is part of the live prereqs), and the script's `NEXT STEPS` block now prints the manual setup commands (`ssh-keygen`, `ssh-copy-id`, `ssh user@mac-mini.local`) so the user can set up the connection by hand.

## Why

- The user prefers to type the SSH commands themselves rather than rely on an auto-written config with placeholder values that does not connect until edited by hand.
- A template config with placeholder host/user is more friction than it saves: the user has to edit it before `ssh mm` works anyway, and editing can race the next boot's re-run.
- Printing the manual commands in `NEXT STEPS` keeps the connection path discoverable at run time without committing any host, user, or key material to the repo.

## Supersedes / relates to

- Reverses the SSH-helper part of `2026-11-15--arch-live-iso-thin-shell.md` (the `~/.ssh/config` template and `~/bin/mm` shim). The rest of that decision — package lists, stow set, xinitrc, service enable, non-persistence — still stands.
- No changes to the macOS installer (`data_sci_install_mac.sh`) or the installed-Arch scripts (`data_sci_install.sh`, `deploy_arch_tools.sh`).
