# Manual SSH to the M6 Mac Mini from the live ISO

- **Date:** 2026-11-15 19:33
- **Developer:** agent session
- **Topic:** dotfiles

## Request

On the live ISO bootstrap (`arch_live_iso_setup.sh`), the user wants to set up SSH to the Mac Mini by hand rather than via the auto-written `~/.ssh/config` template + `~/bin/mm` shim. The script should add the openssh tools (already in `install_live_prereqs`), print the manual setup steps the user runs themselves, and leave `~/.ssh/config` for them to edit.

The user also sent the marker string `LITELLM EXECUTE` — same stray-marker family as `LITELLM ESCALATE`. Ignored.

## What was done

`arch_live_iso_setup.sh` was edited to drop the auto-SSH helper while keeping the openssh client install intact:

- Removed `write_ssh_helper()` entirely (the function that wrote `~/.ssh/config` and the `~/bin/mm` shim).
- Removed the `write_ssh_helper` call from `main()`.
- Removed the `SSH helper` section from `report_status()`.
- Replaced the `NEXT STEPS` block with manual SSH setup commands: `ssh-keygen -t ed25519`, `ssh-copy-id user@mac-mini.local`, `ssh user@mac-mini.local`, plus a note that the user can optionally add a `Host mm` shortcut to `~/.ssh/config` themselves.

The script shrank from 350 to 297 lines. README's Arch Live ISO section was updated to remove the `mm` shim reference and to point at the manual setup.

## Verification

All checks ran inside Docker (the host has no Arch toolchain per the docker-testing skill):

- `bash -n arch_live_iso_setup.sh` on `bash:5.2` — syntax clean.
- `shellcheck -x arch_live_iso_setup.sh` on `koalaman/shellcheck:stable` — no warnings.
- Dry-run smoke test on `archlinux:latest` with `HOME=/tmp/testhome`: every install step still reported as a planned action; the dry-run no longer mentions `~/.ssh`, `~/.ssh/config`, or `~/bin/mm`; the `NEXT STEPS` block correctly shows the manual `ssh-keygen` / `ssh-copy-id` / `ssh user@mac-mini.local` commands; no writes, no installs.

## Open threads

- A new decision file `2026-11-15--live-iso-manual-ssh.md` records the reversal of the SSH-helper part of the prior live-ISO decision.
- Nothing was committed or pushed; per `no-agent-push`, the user pushes.
