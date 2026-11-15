# Secret hygiene skill

- **Date:** 2026-11-07 02:01
- **Developer:** chrporter22 (agent session)
- **Topic:** security

## Request

Add a skill that keeps API keys out of the terminal output for the session, out of the frontend, out of session/decision memory files, and out of anything pushed to GitHub. Add an "ask before reading `.env` files" rule to the security skill. The user also sent the marker string `LITELLM ESCALATE`, which a prior session recorded as a stray marker to ignore — it was ignored here.

## What was done

New skill `repo-template/.claude/skills/secret-hygiene/SKILL.md`. One rule across four surfaces — a credential may be used, never shown, shipped, remembered, or pushed:

1. **Terminal and session output** — a leaky-command/safe-command table (`cat .env`, `printenv`, `curl -v`, `docker inspect`, `kubectl get secret -o yaml`, `process.env` dumps → names-only or masked forms), a `sed` mask pipeline for output the agent did not write, and a "if it already printed" procedure (say the kind and the source, never re-quote, rotate).
2. **Frontend bundle** — public config only, `VITE_*`/`NEXT_PUBLIC_*`/`REACT_APP_*`/`PUBLIC_*`/`EXPO_PUBLIC_*` are published at build time, plus `rg` checks over frontend source and the built `dist/`.
3. **`.ai/` memory** — masked labels only, via the `pii-redaction` labels; a value that leaked into the transcript never gets copied into memory.
4. **GitHub** — `.gitignore` coverage, a three-step pre-push scan (`git ls-files` for secret files, `git grep` for secret prefixes, `git diff --cached` read line by line), no `git add -A` / `git add -f`, and the "already committed means rotate" procedure. A pre-flight checklist closes the skill.

Edited `repo-template/.claude/skills/security-rbac-zero-trust/SKILL.md`:

- New section **Ask before reading secret files** — the agent asks before opening `.env`, `*.pem`, `*.key`, `credentials.json`, `.npmrc`, `secrets/`, and reads names/shapes rather than values; no ask needed for `*.example`/`*.sample`/public config.
- Intro now states the two handling rules on top of the four pillars.
- Frontend section points at `secret-hygiene` for the `VITE_*` inlining detail; review checklist gained a *Secret access* line.

Cross-references: `pii-redaction` now points at the terminal-output rule and the ask-before-`.env` rule; `no-agent-push` now requires the secret scan to be run and shown in the handoff.

Plumbing: `repo-template/AGENTS.md` gained a mandatory **No Secrets in the Terminal** section; `repo-template/CLAUDE.md` points at the new skill; the root `README.md` lists the skill and gained a "Secrets leak outward, not just inward" section describing all four surfaces.

## Notable findings

- The four surfaces were already partly covered — `pii-redaction` owned memory, `no-agent-push` owned the push boundary, `security-rbac-zero-trust` owned the frontend. The genuinely uncovered one was the terminal/session transcript, so the new skill leads with that and ties the other three together instead of duplicating their rules.
- The session transcript is the quietest leak: unlike a committed file it never triggers a secret scanner, and unlike a pushed secret it is not permanent — but it gets pasted into tickets and chat, so "it was only printed" is not a defence.
- "Ask before reading `.env`" is stronger than "mask what you read": most tasks need the variable name and presence, never the value, so the ask defaults to a non-disclosing read.
- Running the new skill's own scan over this repo surfaced one pre-existing hit: the `pii-redaction` example embedded a partial Stripe key prefix, which its own masking table forbids ("never write … any partial prefix/suffix"). It was masked to `<REDACTED:API_KEY>` so the tree now scans clean and the example still shows the mistake.
- Strict YAML parsing rejects the `description:` frontmatter of every skill in this repo (the `Triggers:` clause contains a colon-space inside an unquoted scalar). The new skill keeps the existing convention rather than diverging.

## Open threads

- Changes were committed locally in b0a339b ("security updates"). The branch was merged into main via fast-forward. The user owns the push.
- `rules-site/index.html` embeds a stale snapshot of `README.md`/`AGENTS.md` and only lists the `repo-memory` skill. It was left alone — it is a presentation artifact that already lagged the template, and refreshing it is a separate job.
- If the user wants the terminal-output rule enforced mechanically (a wrapper that pipes every command through the mask), that is a separate design decision — the skill currently specifies behavior, not tooling.
