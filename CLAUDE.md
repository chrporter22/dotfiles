# Repository Instructions

Read and follow `AGENTS.md` in this repo. It is the single source of truth for all agent rules here — workflow, code quality, and memory discipline. Do not skip it.

Also follow the `repo-memory` skill (`.claude/skills/repo-memory/SKILL.md`) for reading and writing `.ai/sessions/` and `.ai/decisions/` in every session.

`.ai/` is pushed to GitHub. Before writing any of it, follow the `pii-redaction` skill (`.claude/skills/pii-redaction/SKILL.md`): no keys, tokens, passwords, connection strings, usernames, names, emails, IPs, hostnames, or customer data in memory — masked labels only.

Never print a credential to the terminal or into the session transcript, never put one in the frontend bundle, and never let one reach a commit. Ask before reading `.env` or any secret file. Follow the `secret-hygiene` skill (`.claude/skills/secret-hygiene/SKILL.md`) for all four surfaces, and the `security-rbac-zero-trust` skill (`.claude/skills/security-rbac-zero-trust/SKILL.md`) for RBAC, zero trust, and frontend keys.

Run tests, builds, lint, and type checks in Docker only, per the `docker-testing` skill (`.claude/skills/docker-testing/SKILL.md`). Never install dependencies or toolchains on the local machine.
