---
name: shield
description: Audit a codebase's security across 20 checks (secrets, auth, injection, crypto, headers, dependencies). Reports every check as pass / fail / not-applicable with file:line evidence, proposes framework-idiomatic fixes, scores the result 0-100, and writes shield-report.md. Use when asked to audit security, check for vulnerabilities, run /shield, or harden a project.
---

Audit a codebase for security weaknesses and propose fixes. Shield is **report + proposed-fixes only**: it scans, scores, and writes `shield-report.md` and changes nothing in the target repo.

## The check surface

Run **all 20 checks**. Each reports one of **pass** / **fail** / **not-applicable**, with `file:line` evidence for every fail.

**Critical** (5): Hide API keys, Purge secrets from Git, Enforce server-side auth, Hash passwords, Parameterize queries.

**High** (9): Expose only public DB key, Enable row-level security, Encrypt sensitive data, Lock record access, Block field tampering, Secure session cookies, Validate all input, Escape user content, Force HTTPS.

**Medium** (6): Rate limit login, Add bot protection, Restrict file uploads, Trim API responses, Add security headers, Scan dependencies.

## Steps

### 1. Detect stack and scope

- Infer the stack from manifests: `package.json`, `Gemfile`, `pyproject.toml`, `requirements.txt`, `go.mod`, `Cargo.toml`, `composer.json`, `*.csproj`, `pom.xml`. Note frameworks, ORM, DB, auth, and web-server idioms you'll judge the checks against.
- **Scan scope**: the repo's non-excluded files. Skip `.git/`, `node_modules/`, vendored/third-party dirs, lockfiles, build/minified output, and coverage output. The `.git` **history** is only scanned by the Purge-secrets check; everything else walks working-tree files.
- Read `CONTEXT.md` and `docs/adr/` if they exist (they define the domain so your findings speak the project's language).

### 2. Dispatch the clusters in parallel

Divide the 20 checks into four clusters and dispatch each to its own sub-agent in parallel. Each gets: the stack + scope from step 1, its cluster's check list with severity and applicability rules, and the instructions to report evidence as `file:line` plus concrete proposed fixes. The sub-agents do the browsing; your context stays lean.

- **Cluster A — Identity & secrets** (4): Hide API keys, Purge secrets from Git, Hash passwords, Enforce server-side auth.
- **Cluster B — Data & persistence** (6): Parameterize queries, Expose only public DB key, Enable row-level security, Encrypt sensitive data, Lock record access, Block field tampering.
- **Cluster C — Web & transport** (6): Secure session cookies, Force HTTPS, Add security headers, Rate limit login, Add bot protection, Trim API responses.
- **Cluster D — Input & dependencies** (4): Validate all input, Escape user content, Restrict file uploads, Scan dependencies.

Each sub-agent must return, per check in its cluster: status (pass/fail/not-applicable), `file:line` evidence for fails, and a proposed fix shaped to the discovered stack (see the per-check reference below).

### 3. Collect, verify, dedupe

- Merge the four cluster results into one table of 20.
- Spot-check any surprising fail before reporting it: read the cited line to confirm the finding is real, not a false positive.
- Collapse duplicate evidence (e.g. one leaked key surfaced by two checks) onto a single finding.

### 4. Score

Severity weights: **critical=4, high=2, medium=1**. Score over **applicable items only** (skip not-applicable):

```
score = round( 100 * (sum of weights of passed applicable items) / (sum of weights of all applicable items) )
```

### 5. Write the report

Print the full report to the terminal **and** write the identical `shield-report.md` to the scanned repo root. Structure:

1. **Score** — numeric 0–100, derived above.
2. **Scan header** — repo path, date, detected stack, list of exclusions applied.
3. **Item table** — all 20 checks: item | severity | status | evidence (`file:line`) | proposed fix (one line).
4. **Priority actions** — the fails ordered by severity, then by ease of fix. Each: what, why, the exact `file:line` targets, and the proposed before/after edit (framework-idiomatic code where determinable, concrete prose guidance otherwise). Mark irreversibles and infra-only items (Purge secrets from Git, Bot protection, Row-level security) as requiring human execution.

**Completion criteria**: all 20 checks have a status; every fail has `file:line` evidence verified against the file; the score is computed over applicable items only; `shield-report.md` exists at the repo root and matches the terminal output.

## Per-check reference

Judge each check in the idioms of the detected stack. N/A rules and fix shapes below.

### Hide API keys (critical) — always applicable
Look for hardcoded secrets: raw keys/tokens/passwords in source, config, `.env` committed to the repo, seed scripts, or frontend-bundled `NEXT_PUBLIC_*`/VITE_/client-only values. Fix: move to env vars/secrets manager; reference via config; for frontend keys, move usage server-side.

### Purge secrets from Git (critical) — always applicable
Search the **git history** (`git log -p`, `git log -S` for known key patterns, the `.git` packed objects) for committed secrets beyond the working tree. Fix: `git filter-repo` / `git-filter-branch` per an OWASP incident doc; rotate the leaked key regardless. **Report-only; human executes.**

### Enforce server-side auth (critical) — applicable when an auth layer exists
Verify authorization runs on the server for every protected route/API, not only in the client. Look for client-only redirects guarding routes, missing middleware, or trust of client-supplied roles. Fix: server-side auth/guard middleware on the route; drop client-side-only checks.

### Hash passwords (critical) — applicable when a user/password model exists
Look for plaintext or reversible storage (raw columns, MD5/SHA-1, base64), or manual unsalted hashing. Fix: bcrypt/argon2/scrypt via the stack's canonical lib (bcrypt, `argon2`, `django`'s PBKDF2) with a per-user salt; never log or return the hash.

### Parameterize queries (critical) — applicable when a SQL/data layer exists
Look for string-built SQL: f-string/concatenation/interpolation into query text, `query()`, `raw()`; distinguish safe drivers that auto-parameterize. Fix: prepared statements / query builders / ORM parameter binding.

### Expose only public DB key (high) — applicable when a DB/client layer exists
Look for admin/root/superuser credentials in app config or a full-access client where a scoped read-only or application role exists. Fix: least-privilege role/credentials for the app; move admin creds to a secrets manager.

### Enable row-level security (high) — applicable when a SQL DB exists
Look for SQL DBs (Postgres RLS, or equivalent per-tenant filtering) whose tables expose rows across tenants without a tenant filter in queries or RLS policy. Fix: enable RLS (e.g. Postgres `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`) and add policies; or enforce tenant scoping in the query layer. **Report-only; human executes migration.**

### Encrypt sensitive data (high) — always applicable
Look for sensitive fields (PII, tokens, payment data) stored or transmitted in plaintext where encryption is expected. Fix: encrypt at rest (app-layer AES-GCM or DB-level TDE) and always TLS in transit; key management via secrets manager.

### Lock record access (high) — not applicable when no auth/user model or no data store exists
Look for object-level access gaps: endpoints that fetch by id without checking the requester owns/has rights to the record, e.g. missing `WHERE user_id = ?` ownership checks. Fix: ownership/ACL check server-side before returning or mutating the record.

### Block field tampering (high) — applicable when an auth/user model exists
Look for mass-assignment: APIs that accept and persist client-supplied fields (roles, `isAdmin`, `price`, `status`) via request body binding without an allowlist. Fix: DTOs/whitelists of settable fields; strip role/permission fields from input.

### Secure session cookies (high) — applicable when a web/server surface exists
Look for session/auth cookies lacking `HttpOnly`, `Secure`, `SameSite`, or set from a non-HTTPS origin. Fix: set `HttpOnly; Secure; SameSite=Lax/Strict` (and `__Host-` prefix where supported) in the stack's session config.

### Validate all input (high) — always applicable
Look for server endpoints accepting unvalidated input: missing schema/type checks on body/query/params, unchecked `req.body` fields, numbers/IDs not type-checked. Fix: schema-validate every input surface (zod/joi/pydantic/serialize params) with an allowlist, rejecting or coercing unknowns.

### Escape user content (high) — always applicable
Look for user content rendered unescaped into HTML/attributes/JS/SQL: template `{{{ }}}`/`|safe`/`html_safe`/`innerHTML`, raw string interpolation. Fix: auto-escaping render calls, context-aware escaping, or a sanitizer for rich content; never flag safe-by-default frameworks unless overridden.

### Force HTTPS (high) — applicable when a web/server surface exists
Look for no TLS enforcement: `http://` links/redirects, missing HTTP→HTTPS redirect middleware, HSTS header absent, or mixed active content. Fix: HSTS + HTTPS redirect middleware/edge rule; replace hardcoded http URLs.

### Rate limit login (medium) — applicable when a web/server surface exists
Look for login/auth endpoints without throttling: no attempt cap, no lockout/backoff, unbounded brute-force surface. Fix: rate limit the auth routes (per-IP + per-account backoff/attempt cap) via the stack's middleware or an edge rate limiter.

### Add bot protection (medium) — applicable when a web/server surface exists
Look for forms/endpoints that accept scripted traffic with no bot mitigation (Turnstile, CAPTCHA, WAF bot rules). Fix: add Turnstile/CAPTCHA or edge bot management on public forms. **Report-only; external service, human executes.**

### Restrict file uploads (medium) — always applicable
Look for upload endpoints accepting any file: no size cap, no extension/MIME allowlist, files served from the same origin or written with a user-controlled name/path. Fix: allowlist extensions+MIME, size cap, random server-generated filenames, scan/validate content.

### Trim API responses (medium) — applicable when a web/server surface exists
Look for JSON/serialized responses over-fetching: returning whole model objects (or the entity's DB rows) where a projection/DTO hides password hashes, API keys, or internal fields. Fix: response DTOs/projection that omit sensitive fields before serialization.

### Add security headers (medium) — applicable when a web/server surface exists
Look for responses missing `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `X-Frame-Options`/`frame-ancestors`, `Referrer-Policy`. Fix: a middleware/edge rule adding the full header set; align CSP with the app's actual inline/script needs.

### Scan dependencies (medium) — always applicable
Run the package manager's audit against the lockfile (`npm audit`, `pip-audit`, `bundle audit`, `cargo audit`, `govulncheck`, `dotnet list package --vulnerable`). Report the count/severity of known CVEs. Fix: bump vulnerable packages to patched versions; fallback to the lockfile's resolved versions when the audit tool isn't runnable. **Report what the audit reports; do not invent CVEs.**