---
name: security-rbac-zero-trust
description: Design and review code under RBAC + zero-trust, with row-level security in the database and zero secrets in the frontend bundle. Use whenever adding or modifying auth, permissions, roles, API endpoints that touch user data, multi-tenant queries, env/secret handling, or any code that decides who can do what. Triggers: "add a role", "who can access this", "tenant isolation", "this endpoint returns user data", "store an API key", "set up RLS", "is this behind auth", writing route handlers, writing database policies, adding a new permission, reviewing a PR for access control.
---

# Security: RBAC, Zero Trust, No Frontend Keys, Postgres RLS

The whole stack assumes the network is hostile, the client is untrusted, and the database user is not "ours". Every layer enforces access on its own; if one layer fails, the next still denies.

Four rules, no exceptions:

1. **RBAC** — every action is permitted by an explicit role check. Default deny.
2. **Zero trust** — every request re-authenticates and re-authorizes. No implicit trust from prior requests, network location, or "logged in earlier".
3. **No keys in the frontend** — secrets, service tokens, master encryption keys, DB passwords, third-party API keys, and signing keys never appear in frontend code, frontend env, frontend bundles, or anything shipped to a browser.
4. **RLS in the database** — Postgres Row-Level Security is the last line. Application code without an enforceable policy is a bug.

Two handling rules sit on top of the four: secret files are read only after asking the user (see *Ask before reading secret files*), and no secret ever reaches the terminal, the frontend bundle, `.ai/` memory, or a push (see the `secret-hygiene` skill).

## RBAC

Roles are coarse (`admin`, `editor`, `viewer`, plus project-specific roles). Permissions are fine-grained and assigned to roles, not users directly. Never check a user's id; check the role's permissions.

- One source of truth: a `permissions` matrix keyed by `<resource>:<action>` (`users:read`, `users:invite`, `billing:update`, `report:export`, ...). A role is a set of these.
- Enforce at the boundary — in route handlers and orchestrators — **before** any business logic reads or writes.
- Default deny: a permission that is not explicitly granted is denied. New endpoints require a decision on the matrix; do not assume "open by default".
- Role changes take effect on the next request; do not bake role info into JWTs longer than their short expiry, and always re-check against the source of truth on sensitive operations.
- Audit log every authorization failure, every role change, and every grant/revoke.
- Never use role hierarchy in code (e.g. `if (user.role === 'admin')`). Check a specific permission (`can(user, 'users:invite')`).

## Zero trust

The client proves who it is **on every request**. The server re-validates and re-decides. No "logged in" state is assumed from a previous hop.

- Authenticate every request: short-lived bearer token in `Authorization`, validated server-side against the issuer on each call. No session cookies for API auth.
- Authorize every request against the current role and current tenant — even for cached responses.
- Pin and validate the tenant per request (the repo's `x-org-id` header for multi-tenant projects) on the server side. Do not trust the client's chosen tenant.
- Validate input at the boundary with zod (TS) or pydantic (Python). The schema is the contract; nothing past it runs untrusted values.
- Network segmentation is out of scope for the app, but in code: assume any service can be compromised, and add per-call auth between services (service tokens, mTLS) rather than trusting an internal network.
- Do not echo secrets, tokens, internal hostnames, or stack details in error responses. Use stable, generic error codes (`UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`) and log the detail server-side.

## Ask before reading secret files

The agent does not open a secret file on its own initiative — not `.env`, `.env.*`, `*.pem`, `*.key`, `credentials.json`, `.npmrc`, `id_rsa`, `secrets/`, `~/.aws/credentials`, `.docker/config.json`, or anything else whose contents are expected to be credentials. It asks the user first.

- Ask a specific, minimal question: which file, which variable, and what the agent actually needs to know — the name, whether it is set, the shape. Never the value.
- After approval, read the minimum: one variable, filtered, with the value masked. `grep -E '^API_KEY=' .env | sed -E 's/=.*/=<REDACTED>/'` confirms "set / not set" without exposing the secret.
- The normal outcome of the ask is that the agent proceeds with names, shapes, and existence checks. The value stays with the user.
- Approval to open one file is not approval to read every secret file, and never approval to print what is inside.
- Nothing read from a secret file goes into the session transcript, `.ai/` memory, commit messages, or PR bodies — masked labels only, per `pii-redaction`.
- The ask is not needed for files that hold no secret: `*.example`, `*.sample`, `*.template`, committed config schemas, public config, and docs.
- If the user says "just cat it", still mask the output before it reaches the terminal. The work almost never needs the raw value. See the `secret-hygiene` skill.

## No keys in the frontend

The frontend bundle is world-readable. Anything shipped there is effectively public. Treat the frontend as incapable of holding a secret.

What never lives in the frontend:

- Third-party API keys (Stripe, SendGrid, OpenAI, Maps, ...).
- Service-to-service tokens or shared secrets for backend-to-backend auth.
- Master encryption keys or any key material used for AES-GCM at rest.
- DB connection strings, internal service URLs, internal hostnames, OAuth client secrets.
- Long-lived bearer tokens. Use a short-lived exchange (Firebase Auth → custom JWT on the backend) and refresh server-side.

What the frontend does hold:

- Its public config (e.g. the Firebase Web SDK config, the publishable Stripe key, a public map tile URL).
- The short-lived session token received after the auth exchange, kept in memory or a non-extractable store; never written to `localStorage` for sensitive apps.

When the frontend needs to do something privileged (a Stripe refund, a SendGrid send, a DB write), it calls the backend. The backend holds the secret and authenticates the caller. Never proxy a key from the frontend and never embed one "because it's only the dev key".

The bundle is also a place secrets leak *out* of: a `VITE_*` value is inlined at build time, so `VITE_STRIPE_SECRET_KEY` publishes the secret. The grep checks for this live in the `secret-hygiene` skill.

## Postgres Row-Level Security (RLS)

Every multi-tenant table has RLS enabled and policies that the application user cannot bypass. The connection pool runs as a single role per request with the user's identity, and policies enforce tenant isolation at the database level. This is defense in depth: a missing `WHERE` clause in the app is a denial-of-service or worse, but it is not a data leak.

- Enable RLS on every tenant-scoped table: `ALTER TABLE <t> ENABLE ROW LEVEL SECURITY;` and `ALTER TABLE <t> FORCE ROW LEVEL SECURITY;`.
- Set a tenant key per request via `SET LOCAL app.current_org = '<org-id>';` inside the transaction. Policies read it via `current_setting('app.current_org')`.
- One policy per access pattern, default deny: a table without an explicit `USING`/`WITH CHECK` for a given role returns zero rows. Do not leave a permissive default policy.
- Indexes lead with the tenant key so policies don't kill performance: `(organization_id, deleted_at, ...)`.
- The app uses a non-superuser DB role with `BYPASSRLS` *off*. Superuser and migration roles bypass RLS — that is correct for migrations, wrong for the request path.
- Test bypass scenarios: log in as the request-time role, run the query without `WHERE organization_id`, confirm the result is still tenant-scoped by the policy. If it leaks, the policy is wrong.
- For soft-deleted rows (`deleted_at`), RLS adds the predicate, so app code can stay simple and still never return deleted rows by accident.

## Review checklist

When reviewing a change for security posture, walk this list:

- **RBAC:** new endpoint declares the permission it requires; the matrix is updated; the check runs before any read/write; failure is logged.
- **Zero trust:** the request authenticates a token; the token is re-validated; the tenant header is validated server-side; input passes schema validation before use.
- **No frontend keys:** no secret-looking string in `frontend/**` or any code that builds the bundle. Env files used by the frontend contain only public values. Build artifacts have no secrets (grep the dist).
- **RLS:** new tenant-scoped tables have RLS enabled and policies; existing tables touched by the change still pass the bypass test; indexes lead with the tenant key.
- **Logging:** auth failures and permission denials are logged with `{ requestId, userId, action }`; no tokens or passwords are logged.
- **Secret access:** the agent asked before opening any `.env` or key file, and used only names and masked values from it.
- **Secrets:** any secret read from env is consumed server-side only; rotation is documented; raw values are never written to `.ai/` (see `pii-redaction`) and never printed to the terminal (see `secret-hygiene`).

## Anti-patterns to refuse

- "Trust the frontend to send the user id" — always read it from the verified token.
- "It's an internal service, no auth needed" — internal services authenticate too.
- "We'll add RLS later" — add it now, before the table holds real data.
- "Hard-code the role for testing, we'll fix it" — gate the test with a permission like everything else.
- "Just put the key in `VITE_*` so it gets baked in" — no. Frontend env is public.
- "Hide the secret in the bundle" — anything in the bundle is not a secret.

## Scope

Applies to every code change that touches auth, permissions, data access, secrets handling, or the request path. Sits on top of the engineering standards in `AGENTS.md` (structured logging, soft delete, multi-tenant keys) and the `pii-redaction` and `docker-testing` skills.
