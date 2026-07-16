# CLAUDE.md — Global Agent Rules

---

## 1. Clarification vs Action

Act immediately on tasks that are clear enough to start. Do not ask
clarifying questions before beginning if the intent is unambiguous.

**Ask only when:**
- The task has two or more genuinely different valid interpretations that
  would produce meaningfully different outcomes
- A destructive or irreversible action is involved and scope is unclear
  (e.g. "clean up the database" — which one? which records?)
- A required input is completely missing and cannot be reasonably inferred

**Never ask about:**
- Stylistic preferences that can be inferred from existing code in the repo
- Things already answerable by reading the codebase or context
- Implementation details you can decide yourself

When you do need to clarify, ask the single most important question only.
Do not bundle multiple questions. Do not ask permission to proceed.

**When you make an assumption to move forward, state it once, briefly:**
```
Assuming X — proceeding. Let me know if you meant Y instead.
```

---

## 2. Document Compression — Confluence & GitLab

Never reason directly over raw Confluence or GitLab content longer than
~2,000 words. Always compress first, reason after.

Two modes are available. Choose based on whether the PostToolUse hook
is active in the current session (check `.claude/settings.json`).

---

### Mode A — Inline Compression (Sonnet, always available)

Use when the hook is not active. Compress the document yourself before
reasoning over it.

**Step 1 — Choose extraction method:**

| Situation | Method |
|-----------|--------|
| Need to understand the document generally | Summary |
| Have a specific question to answer | Q&A |
| Need specific metadata fields | Fields |
| Spec, decisions list, or meeting notes | Key points |
| GitLab source file, need specific function/class | Code extraction |

**Step 2 — Produce the compressed block, then reason only over it:**

Summary — 3–5 sentences, plain prose:
```
[Compressed — mode: summary, original: ~4,200 words, source: Confluence/Deploy-Guide]
The payments service deploys via GitHub Actions every Friday at 17:00 UTC.
Rollbacks trigger automatically when error rate exceeds 5% over 2 minutes.
The platform team owns incident response; on-call rotation is in PagerDuty.
```

Q&A — extract only what answers the question, 2–3 sentences:
```
[Compressed — mode: qa, question: "what triggers a rollback?", source: Confluence/Deploy-Guide]
Rollbacks trigger automatically when error rate exceeds 5% over a 2-minute
window, or manually via /rollback in #incidents. No approval gate for automatic rollbacks.
```

Fields — compact JSON, null for missing fields:
```
[Compressed — mode: fields, source: Confluence/Service-Spec]
{"owner": "platform-team", "status": "production", "oncall": "PagerDuty/payments", "last_updated": "2025-01"}
```

Key points — max 8 bullets, max 15 words each:
```
[Compressed — mode: keypoints, source: Confluence/ADR-042]
- Payments DB migrates to Postgres 16 in Q2
- No downtime expected; blue-green cutover planned
- Rollback window is 48 hours post-migration
- Owner: @dbteam, reviewer: @platform
```

Code extraction — signature + body only:
```
[Compressed — mode: code, target: "PaymentProcessor.process()", source: gitlab/payments/processor.py]
# PaymentProcessor.process() — main entry point
def process(self, payment: Payment) -> Result:
    ...
```

**Step 3 — Discard the raw content.** Do not reference it again.

---

### Mode B — Automatic Hook Compression (Haiku via API)

Active when `.claude/settings.json` contains a PostToolUse hook. When active,
tool results from Confluence/GitLab arrive already compressed — you can tell
because they are prefixed with `[Compressed — mode: ...]`.

When Mode B is active, skip Mode A entirely.

To activate Mode B, add to `.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "mcp__atlassian__.*|mcp__gitlab__.*",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/scripts/compress.py --mode summary"
          }
        ]
      }
    ]
  }
}
```

Override the compression mode for a focused session by editing the `--mode`
flag before starting:
```bash
# Q&A session:  --mode qa --question "your question"
# Code review:  --mode summary
# Find a func:  --mode code --target "ClassName.method()"
```

---

### Source-specific notes

**Confluence:**
- Page properties/metadata are already small — do not compress them, use as-is.
- Pages > 50,000 chars: split at heading boundaries, compress each section,
  combine the compressed blocks.

**GitLab:**
- Source files → always `code` mode with an explicit target. Never summarise code.
- MR description + comments → `summary` or `qa`.
- `.gitlab-ci.yml` → `keypoints`: job names and their key steps only.
- Large diffs → `summary`: what changed and why, not the diff lines.

---

## 3. Code Style

### All languages

- Match style of existing code in the repo before applying these defaults.
- Explicit over clever. Readable by a teammate unfamiliar with the code.
- No commented-out code in commits.
- No `TODO` comments unless the task explicitly requires leaving one.

### Python

- Type hints on all function signatures.
- `pathlib.Path` over `os.path`.
- f-strings over `.format()` or `%`.
- `dataclasses` or `pydantic` for structured data — not plain dicts passed
  between functions.
- Raise specific exceptions. Never `except: pass`.
- Tests: `pytest`. Mirror source path:
  `src/payments/processor.py` → `tests/payments/test_processor.py`.

### TypeScript

- Strict mode on. No `any` without an explanatory comment.
- `interface` for public API shapes; `type` for unions and utilities.
- `const` by default. `let` only when reassignment is required. Never `var`.
- Named exports over default exports (except React components and Next.js pages).
- `async/await` over `.then()` chains.
- Expected failures: `Result`-style returns or typed error unions. `throw` only
  for genuinely unexpected states.
- Tests: `vitest`, co-located: `payments/processor.ts` → `payments/processor.test.ts`.

### JavaScript

- Same rules as TypeScript where applicable.
- JSDoc on public functions when TypeScript is unavailable.
- `===` always. Never `==`.

### Shell / Bash

- `#!/usr/bin/env bash` shebang. `set -euo pipefail` at the top of every script.
- `[[ ]]` over `[ ]` for conditionals.
- Quote all variable expansions: `"$VAR"`.
- `local` for all variables inside functions.
- Progress and status to stderr (`>&2`). Stdout is for consumable output only.

---

## 4. Git Discipline

### Commit messages — conventional commits

```
<type>(<scope>): <short summary, ≤72 chars, imperative mood>

[optional body, wrapped at 72 chars]

[optional footer: BREAKING CHANGE: ... or Closes #N]
```

**Types:** `feat` · `fix` · `chore` · `refactor` · `test` · `docs` · `ci` · `perf`

**Rules:**
- Imperative mood: "add X", not "added X" or "adds X".
- Scope is the module or service affected: `fix(payments): ...`
- One logical change per commit. No bundling of unrelated changes.
- No `--no-verify` unless explicitly instructed.

**Examples:**
```
feat(auth): add refresh token rotation
fix(payments): handle nil customer ID in processor
chore(deps): bump anthropic to 0.22.0
refactor(compress): extract mode dispatch to separate function
test(auth): add coverage for expired token edge case
```

### Branches

- Features: `feat/<short-description>`
- Bug fixes: `fix/<short-description>`
- Chores: `chore/<short-description>`
- Never commit to `main` or `master` directly unless explicitly told to.
- Branch from `main` unless the repo uses a different convention.

### Before committing

1. Run the project linter/formatter (`ruff`, `eslint`, `prettier`, etc.).
2. Run tests touching changed files at minimum.
3. Review the diff: remove debug logs, dead code, stray whitespace changes.

---

## 5. Error Handling and Retries

### Diagnose before fixing

Read the full error output before proposing a fix. Check the stack trace and
the line it points to. Do not guess from a partial error message.

### Retry policy

- Transient failure (network, rate limit, timeout): retry once after a brief
  wait. Log the retry.
- Second failure: stop, report clearly, ask how to proceed. Do not loop silently.
- Never retry on logic errors, validation failures, or 4xx responses (except 429).

### Reporting errors

State:
1. What you were trying to do
2. The exact error (message + relevant trace lines)
3. What you believe caused it
4. The fix you're about to apply — or a question if you're unsure

Do not hide errors or silently add fallbacks unless the task calls for it.

### Changing approach

If the same approach fails twice, stop and propose a different one. State
what you tried and why you think it didn't work. Do not repeat the same
attempt a third time.
