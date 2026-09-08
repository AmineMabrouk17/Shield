<img src="Logo.png" alt="Shield" width="200" align="right">

# Shield

A stack-agnostic security-audit skill that scans any codebase against **20 checks** — secrets, auth, injection, crypto, headers, and dependencies — reports each one as **pass / fail / not-applicable** with `file:line` evidence, proposes framework-idiomatic fixes, and scores the result **0–100**.

**Shield is report + proposed-fixes only.** It never modifies the target codebase. It scans, scores, writes `shield-report.md`, and leaves the edits to you.

## Install

One command from this repo's root:

```bash
./scripts/install.sh
```

This symlinks `~/.agents/skills/shield` to this repo's `.agents/skills/shield`, making `/shield` available in **any** project with zero per-project setup. Re-run it anytime — it's idempotent, and `FORCE=1` re-points an existing symlink.

## Usage

In any project you want to audit:

```
/shield
```

Shield auto-detects the stack from manifests (`package.json`, `Gemfile`, `pyproject.toml`, `go.mod`, …), runs the checks against the working tree, and writes the same report to the terminal and to `shield-report.md` at the project root.

## The 20 checks

| Severity | Checks |
| -------- | ------ |
| **Critical** (5) | Hide API keys · Purge secrets from Git · Enforce server-side auth · Hash passwords · Parameterize queries |
| **High** (9) | Expose only public DB key · Enable row-level security · Encrypt sensitive data · Lock record access · Block field tampering · Secure session cookies · Validate all input · Escape user content · Force HTTPS |
| **Medium** (6) | Rate limit login · Add bot protection · Restrict file uploads · Trim API responses · Add security headers · Scan dependencies |

Checks that don't apply to the detected stack report **not-applicable** (no web surface → no session-cookie/HTTPS checks; no SQL layer → no parameterized-query/RLS checks; no auth model → no password-hashing checks).

## How it works

1. **Detect stack & scope** — infer the stack from manifests; skip `.git/`, `node_modules/`, vendored code, lockfiles, build output, and coverage. The `.git` history is scanned only by the Purge-secrets check.
2. **Dispatch in parallel** — four sub-agents cover Identity & secrets, Data & persistence, Web & transport, Input & dependencies.
3. **Collect & verify** — merge results, spot-check surprising findings against the file, collapse duplicate evidence.
4. **Score** — severity-weighted (critical 4 / high 2 / medium 1) over applicable items only.
5. **Report** — score, scan header, 20-item table, and a priority action list ordered by severity then ease of fix. Items that require human execution (Purge secrets from Git, Row-level security, Bot protection) are explicitly marked.

## Output

`shield-report.md` at the scanned repo root:

```
Score: 78

## Scan header
repo: my-project        date: 2026-09-08        stack: Node 20 / Express / Postgres

## Item table
| Check                  | Severity | Status | Evidence          | Proposed fix              |
|------------------------|----------|--------|-------------------|---------------------------|
| Parameterize queries   | critical | fail   | src/db.js:42      | Use prepared statements   |
| ...

## Priority actions
1. [critical] Hash passwords — src/auth.js:17 — migrate to bcrypt with per-user salt
```

## Development

- `SKILL.md` — the full skill: workflow, scoring, and the per-check reference. Single self-contained file by design.
- `scripts/install.sh` — the one-command installer.

Edits to the skill are live in every project instantly, because the global install is a symlink back to this repo.