---
name: pickup
description: >
  Resume work from a handoff document. Finds the most relevant handoff doc for the current
  workspace, or lists all available handoffs for the user to choose. Loads context into the
  conversation so a fresh agent can continue seamlessly. TRIGGER when: user says "pick up",
  "resume", "continue where we left off", "load handoff", "what was I working on",
  "pickup the handoff", or references a prior session's work.
argument-hint: "[optional: path to a specific handoff file]"
---

# pickup: Resume from Handoff

Inverse of `/handoff`. Finds and loads a handoff document so this session can continue prior work
with full context.

---

## Phase 1: Locate Handoff Documents

If the user passed an argument that looks like a file path, use it directly — skip to Phase 2.

Otherwise, scan for handoff docs:

1. List markdown files in the OS temp directory (`$TMPDIR` on macOS, `/tmp` on Linux)
   matching pattern `*handoff*` (case-insensitive)
2. Also check the current workspace root for any `*handoff*.md` files
3. Sort results by modification time, newest first

**If no handoff docs found:** Tell the user — suggest running `/handoff` in a prior session first.
Stop here.

---

## Phase 2: Select the Right Document

### Auto-select (single match or clear best match)

Auto-select when ONE of these is true:
- Only one handoff doc exists
- The most recent handoff doc references this project's directory path or repo name

When auto-selecting, tell the user which file you picked and why:
```
Found handoff: /tmp/handoff-my-project-2026-05-27.md (most recent, matches current repo).
Loading context...
```

### Prompt user (multiple candidates, no clear winner)

List all found handoff docs as a numbered selection using `AskUserQuestion`:
- Show filename, modification date, and first-line summary (read line 1–3 of each)
- Let user pick one

---

## Phase 3: Read and Load Context

Read the selected handoff file completely. Then output a structured context briefing to the
conversation using this format:

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
- For every file path mentioned in the handoff → check it exists. Flag any missing paths:
  `⚠ Referenced file not found: {path} — may have been moved or deleted`
- For every branch mentioned → run `git branch --list {name}` to confirm it exists
- For skill suggestions → verify each skill is available in the current environment

---

## Phase 4: Offer to Continue

After loading context, ask:

> Context loaded. Ready to continue — want to proceed with the suggested next steps,
> or do you have a different direction?

If the handoff doc suggested specific skills, mention them:
> The handoff suggests using: `/me-craft`, `/security-review`. Want me to invoke one?

---

## Edge Cases

| Situation | Action |
|-----------|--------|
| Handoff doc is stale (>7 days old) | Warn: "This handoff is {N} days old — some references may be outdated." |
| Handoff references a different repo | Warn: "This handoff was for {repo}, but you're in {current}. Proceed anyway?" |
| Handoff doc contains redacted secrets | Note: "Some values were redacted in the handoff. You may need to re-provide credentials." |
| File path argument doesn't exist | Error: "File not found: {path}. Check the path and try again." |

---

## Composing with Other Skills

- After pickup loads context, user typically invokes an execution skill (`/me-craft`, `/plan`, etc.)
- If the handoff doc contains a plan, suggest `/me-craft` to execute it
- If it contains open questions or ambiguity, suggest `/plan` or `/grill-with-docs` first
- This skill is read-only — it never modifies the handoff file or any project files
