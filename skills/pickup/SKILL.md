---
name: pickup
description: >
  Resume work from handoff document. Find most relevant handoff doc for current
  workspace, or list all for user to choose. Load context into conversation so
  fresh agent can continue seamlessly. TRIGGER when: "pick up", "resume",
  "continue where we left off", "load handoff", "what was I working on",
  "pickup the handoff", or references prior session work.
argument-hint: "[optional: path to specific handoff file]"
---

# pickup: Resume from Handoff

Inverse of `/handoff`. Find and load handoff doc so session can continue prior work with full context.

---

## Phase 1: Locate Handoff Documents

Argument looks like file path → use directly, skip to Phase 2.

Otherwise scan:

1. List markdown files in OS temp dir (`$TMPDIR` on macOS, `/tmp` on Linux) matching `*handoff*` (case-insensitive)
2. Check current workspace root for `*handoff*.md`
3. Sort by modification time, newest first

**No handoff docs found:** Tell user — suggest `/handoff` in prior session. Stop.

---

## Phase 2: Select Right Document

### Auto-select (single match or clear best match)

Auto-select when ONE true:
- Only one handoff doc exists
- Most recent handoff doc references this project's directory path or repo name

Tell user which file picked and why:
```
Found handoff: /tmp/handoff-my-project-2026-05-27.md (most recent, matches current repo).
Loading context...
```

### Prompt user (multiple candidates, no clear winner)

List all found handoff docs via `AskUserQuestion`:
- Show filename, modification date, first-line summary (read line 1–3 of each)
- Let user pick one

---

## Phase 3: Read and Load Context

Read selected handoff file completely. Output structured context briefing:

```
## Handoff Context Loaded

**Source:** {filepath}
**Created:** {file modification date}

### Prior Work Summary
{Extract the summary/situation section from the handoff doc}

### Key Decisions & State
{Extract decisions made, current state, blockers, open questions}

### Artifacts & References
{List all referenced files, PRs, issues, plans — verify each path still exists}

### Suggested Next Steps
{Extract the "what's next" or "suggested skills" section}
```

**Verification rules:**
- Every file path in handoff → check exists. Flag missing: `⚠ Referenced file not found: {path} — may have been moved or deleted`
- Every branch mentioned → `git branch --list {name}` to confirm
- Skill suggestions → verify available in current environment

---

## Phase 4: Offer to Continue

After loading context:

> Context loaded. Ready to continue — proceed with suggested next steps, or different direction?

If handoff suggested skills:
> Handoff suggests: `/me-craft`, `/security-review`. Want me to invoke one?

---

## Edge Cases

| Situation | Action |
|-----------|--------|
| Stale (>7 days old) | Warn: "Handoff is {N} days old — references may be outdated." |
| References different repo | Warn: "Handoff was for {repo}, you're in {current}. Proceed anyway?" |
| Contains redacted secrets | Note: "Some values redacted. May need to re-provide credentials." |
| File path argument missing | Error: "File not found: {path}. Check path and try again." |

---

## Composing with Other Skills

After loading context, suggest next skill based on handoff state:

| Handoff contains | Suggest |
|------------------|---------|
| Confirmed plan, ready to execute | `/me-craft` (TDD cycles) or `/prp-implement` (validation loops) or `/feature-dev` (architecture-aware) |
| Vague idea, no plan yet | `/plan` (single-PR) or `/prp-plan` (deep codebase analysis) or `/blueprint` (multi-session) |
| Problem statement, no spec | `/prp-prd` (interactive PRD) or `/product-capability` (PRD→SRS) |
| Plan exists but untested against domain | `/grill-with-docs` (stress-test against docs/ADRs) |
| Implementation needed, unknown ecosystem | `/search-first` (find existing tools before coding) |

Read-only — never modifies handoff file or project files.
