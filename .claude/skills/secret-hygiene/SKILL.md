---
name: secret-hygiene
description: Keep API keys, tokens, passwords, and other secrets out of the four surfaces an agent touches — terminal and session output, the frontend bundle, `.ai/` memory files, and git history on GitHub. Use whenever a command might print a credential (env, .env, curl -v, docker inspect, kubectl get secret, app logs), when adding a key or config value to frontend code, before every commit and before every handoff, and whenever a secret may have leaked. Triggers: "read the .env", "print the env vars", "what's the API key", "add this key to the frontend", "VITE_ variable", "it's only a dev key", "commit this", "push it", or a credential turning up in command output, in a diff, or in a file.
---

# Secret Hygiene

One rule, four surfaces: **the agent may use a credential, and may never show it, ship it, write it down, or push it.**

| Surface | Who can see it | Rule |
|---|---|---|
| Terminal & session output | Anyone the output is pasted to — tickets, chat, AI context, scrollback | Never print a raw secret; mask before output |
| Frontend bundle | The entire internet | Public config only, never a secret |
| `.ai/sessions/` + `.ai/decisions/` | Everyone with repo access, forever | Masked labels only |
| Git history on GitHub | Everyone with repo access, plus forks, mirrors, caches | Never commit a secret; rotate if one lands |

The last two are owned by the `pii-redaction` and `no-agent-push` skills. This skill owns the first two and ties all four together, because a secret that leaks on one surface is compromised regardless of what the other three do.

## Terminal and session output

The session transcript is a log. It gets copy-pasted into tickets, chat threads, and the next agent's context. Treat it as a public channel, not a private scratchpad.

- **Never print a raw secret to the terminal.** Not once, not "just to check the format", not "I'll show it and remove it".
- The value is almost never what the task needs. What the task needs is the *name* of a variable, whether it exists, its shape (prefix, length), or where it lives.
- When output would contain a secret, run the safe form of the command instead of the leaky one.
- A secret in the output is a leak in the transcript, not a private note. The scrollback, the log, and any pasted copy persist.

| Instead of | Run | You get |
|---|---|---|
| `cat .env` | `grep -E '^[A-Z0-9_]+=' .env \| cut -d= -f1` | variable names only |
| `cat .env` | `sed -E 's/=([^=]*)$/=<REDACTED>/' .env` | names, values masked |
| `env` / `printenv` | `env \| cut -d= -f1` | names only |
| `env` | `env \| sed -E 's/=.*/=<REDACTED>/'` | values masked |
| `curl -v ...` | `curl -sS -o /dev/null -w '%{http_code}\n' ...` | status only — `-v` prints `Authorization` and cookies |
| `docker inspect <c>` | `docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' <c> \| cut -d= -f1` | env var names in the container |
| `kubectl get secret -o yaml` | `kubectl get secrets` | names only (base64 is still a secret) |
| `node -e 'console.log(process.env)'` | `node -e 'console.log(Object.keys(process.env))'` | names only |
| app logs / stack traces with a DSN | `... \| sed -E 's#://[^@]*@#://<REDACTED>@#g'` | DSN with the credentials stripped |
| `git log -p` over a secret-bearing commit | `git log --oneline` | no diff content |

For output the agent did not write itself — logs, test fixtures, HTTP dumps, `docker logs`, `kubectl logs` — pipe it through a mask first:

```bash
| sed -E 's/([A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|PASSWD|PWD|CREDENTIAL)[A-Za-z0-9_]*=)[^[:space:]]*/\1<REDACTED>/g'
```

That masks `...=value` for any variable whose name ends in `KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `PWD`, or `CREDENTIAL`. It is a backstop, not a pass — check the shape of the output before deciding it is safe.

Also:

- Never print a credential embedded in a URL (`https://user:pass@host/…`) — strip the userinfo first.
- Never put a raw secret in an agent reply, a commit message, a PR body, an issue, or a task description.
- If the user asks "what's the API key in my `.env`?" — tell them the file and the variable to read, and let them read it. Do not print it.
- "It's only a dev key" and "just this once" are not exceptions. A dev key in a transcript is still a key; a staging key in a bundle is still a bundle.

### If a secret is already in the output

1. Say it plainly: which kind of value, which command produced it, and that it must be rotated. **Never re-quote the value** — not in full, not partially, not "just the last four characters".
2. Do not re-run the command to confirm it, and do not paste the leaked output into the session file, a commit message, or a PR.
3. Rotation is the fix. Deleting the line, clearing scrollback, or editing the transcript does not unprint it — the scrollback, the system log that captured it, and every pasted copy survive.
4. Note the incident in the session file with the kind, the source, and the rotation, in words only.

## No keys in the frontend

The frontend bundle is world-readable; treat the frontend as incapable of holding a secret. The full rule lives in the `security-rbac-zero-trust` skill. The mechanics:

- Public config ships: Firebase web config, publishable keys (`pk_…`), public map tile URLs.
- Backend-only, always: Stripe secret keys, LLM provider API keys, SendGrid, Maps server keys, DB connection strings, service-to-service tokens, `APP_ENCRYPTION_KEY`, OAuth client secrets.
- `VITE_*`, `NEXT_PUBLIC_*`, `REACT_APP_*`, `PUBLIC_*`, `EXPO_PUBLIC_*` are inlined into the bundle at build time. A secret behind one of those prefixes is a published secret.
- Never `import.meta.env.<SECRET>` in client code, never an endpoint that returns the server's env, never a key in a query string (query strings land in logs, referrers, and browser history).
- The frontend calls the backend for anything privileged. The backend holds the secret and authenticates the caller.

Verify before the change ships:

```bash
# secret-ish names in frontend env files and source
rg -n --hidden -g '!node_modules' -g '!.env.example' \
  '(VITE|NEXT_PUBLIC|REACT_APP|PUBLIC_|EXPO_PUBLIC)_[A-Z0-9_]*(KEY|SECRET|TOKEN|PASSWORD)' frontend/

# known secret prefixes in frontend source
rg -n --hidden -g '!node_modules' \
  '(sk_live_|sk_test_|AIza[0-9A-Za-z_-]{20,}|ghp_|github_pat_|xox[baprs]-|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)' frontend/

# the built bundle
rg -n '(sk_live_|AIza[0-9A-Za-z_-]{20,}|-----BEGIN)' frontend/dist/
```

A key that reached the bundle is public. Rotate it first, then remove it — removing the code does not unpublish the old bundle (CDN caches, browser caches, shipped artifacts), and rotation is the only fix.

## No keys in session memory or decisions

`.ai/sessions/` and `.ai/decisions/` are committed and pushed, so what lands there is permanent public history.

- Masked labels only, per `pii-redaction`: `<REDACTED:API_KEY>`, `<REDACTED:SECRET>`, `<REDACTED:PASSWORD>`, `<REDACTED:DB_URL>`, `<REDACTED:MASTER_KEY>`.
- Record the *name* of the credential, where it lives, and how it is rotated. Never the value.
- A decision file is business language. A credential does not belong in one at all — not raw, not masked — unless the decision is literally about that credential.
- The terminal rule applies here too: a value that leaked into the transcript must not be copied into memory. Memory gets the masked label.
- Before writing: re-read the draft hunting for `key`, `token`, `secret`, `password`, `://`, `@`. Before committing: `git diff --cached .ai/` and read the added lines.

## No keys ever pushed to GitHub

The agent never pushes — see the `no-agent-push` skill. But "the user pushes" is not "the user pushes secrets". The agent's job is to hand over a tree that is clean, and to prove it.

- `.gitignore` covers `.env`, `.env.*` (keep `!.env.example`), `*.pem`, `*.key`, `*.p12`, `*.pfx`, `credentials.json`, `.npmrc`, `secrets/`.
- Run the pre-push scan and show the result in the handoff:

  ```bash
  # 1. no secret file tracked
  git ls-files | rg '(^|/)\.env($|\.)|\.(pem|key|p12|pfx|keystore)$|credentials\.json$|(^|/)secrets/'

  # 2. no secret prefixes anywhere in the tree
  git grep -nIE '(sk_live_|sk_test_|AIza[0-9A-Za-z_-]{20,}|ghp_|github_pat_|xox[baprs]-|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.)' -- . ':(exclude)*.example' ':(exclude)*.sample'

  # 3. read the staged diff line by line
  git diff --cached
  ```

  Expected: (1) lists nothing except `*.example` files, (2) has no hits, (3) contains no raw credential.
- Never `git add -A` or `git commit -a` on a repo with `.ai/` active — stage reviewed paths.
- Never `git add -f .env` or `git add -f secret.key`. The ignore rule is not an obstacle to route around.
- Never commit a key "so the user can see it in the diff". Describe the change; the user can read their own `.env`.

### If a secret got committed

1. Stop. It is compromised: the commit is in history, possibly pushed, possibly cached.
2. Tell the user which kind of credential, which file, and that rotation is required. Do not quote the value.
3. Rotation is the fix. Rewriting history (`git filter-repo`) and force-pushing is cleanup, not a fix, and is user-only — the agent does not rewrite pushed history. Forks, mirrors, and GitHub's cached views need GitHub support.
4. Mask the value in the working tree and note the incident in the session file. The session file is a history record — never silently rewrite it to hide the incident.

## Pre-flight checklist

Before every commit and every handoff:

- [ ] `git diff --cached` read line by line — no raw credential.
- [ ] No secret file tracked (`git ls-files` scan above).
- [ ] Frontend source and `dist/` free of secret prefixes (skip if the repo has no frontend).
- [ ] This session's terminal output held no raw secret, and nothing leaked was pasted into the transcript.
- [ ] `.ai/` files use masked labels.
- [ ] Every credential is referenced by name, location, and rotation path only.

## Scope

Applies to every session, every repo, every branch. Sits on top of `pii-redaction` (memory masking), `no-agent-push` (the push boundary), and `security-rbac-zero-trust` (frontend keys, secret-file access). The agent may hold credentials in order to do the work; it may never display, bundle, remember, or push them.
