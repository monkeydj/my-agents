---
name: me-code
description: >
  Personalized incremental coding workflow skill that orchestrates the full development cycle per project.
  TRIGGER this skill whenever the user provides requirements, a ticket, a spec, or a PRD and wants to
  start implementing — even if they don't say "me-coding" explicitly. Activate for phrases like:
  "implement this", "code this up", "let's build this feature", "start coding based on the ticket",
  "here's the spec, let's go", "follow my coding workflow", "build it", "implement the requirements".
  Also trigger when the user pastes a Jira/Linear/GitHub issue and expects you to begin development.
  This skill enforces branch safety, persists a plan (via save-plan skill or memory), implements
  changes with language-server and domain skills, runs tests, and commits + pushes with
  conventional messages including ticket IDs.
---

# me-coding: Personalized Incremental Coding Workflow

This skill is your full development cycle orchestrator — from reading a ticket or spec through to
pushing a clean, tested commit on the right branch. It keeps a persistent plan, respects branch
safety rules, and composes with language-specific and domain skills.

Work through the phases in order. Mark each phase done before moving on.

---

## Phase 0: Branch Safety (Always First)

Run `git branch --show-current` before touching any code.

| Current branch     | What to do                                                                                        |
|--------------------|---------------------------------------------------------------------------------------------------|
| `main` or `master` | Stop. Ask the user for a branch name. Based on the intent, suggest a prefix: `feat/`, `fix/`, `chore/`, or `migration/`. Create and switch to the new branch once confirmed. |
| `release-*`        | Switch to `main`/`master` first, then apply the same rule above.                                |
| Anything else      | Continue to Phase 1.                                                                             |

**Hard constraint:** Never push to `main`, `master`, or any `release-*` branch at any point.

---

## Phase 1: Review & Analyze

Read everything the user has provided: tickets, specs, PRDs, Jira issues, inline requirements,
linked files. If the user referenced something without pasting it, ask for it.

Identify and note:
- **Type of change:** feature, bug fix, refactor, chore, or data migration
- **Affected scope:** which files, modules, services, or APIs are likely involved
- **Constraints:** performance requirements, backward compatibility, framework-specific rules
- **Data migration flag:** if this is a migration, tests will be skipped in Phase 4

If anything is ambiguous or underspecified, ask now — it's cheaper to clarify before planning
than to backtrack mid-implementation.

---

## Phase 2: Craft & Persist the Development Plan

Break the work into ordered, concrete tasks. Think through dependencies — what has to happen
before what. Identify which files need to change and roughly how.

**Plan format to produce:**

```
# Plan: [Feature/Fix Name]

## Context
[1-2 sentences on what and why]

**Ticket:** [ID if provided, e.g., BP-1234]
**Type:** feat | fix | chore | refactor | migration

## Implementation Steps

### 1. [First concrete task]
- Files: [list affected files/modules]
- Notes: [anything non-obvious]

### 2. [Second task]
...

## Test Strategy
[unit | integration | e2e | skip — and why]

## Critical Files
[Key files that will be read or modified]
```

**Persist the plan** — use whichever mechanism is available, in this order:
1. **`save-plan` skill** (preferred) — write the plan to `~/.claude/plans/<kebab-title>.md`,
   then invoke `/save-plan` to archive it to the Obsidian vault with proper frontmatter and TODOs.
   Add the ticket ID as a tag (e.g., `/save-plan bp-1234`).
2. **Serena memory** — call `mcp__serena__write_memory` with name `plan-<ticket-id>` if
   `save-plan` is not available.
3. **TaskCreate** — at minimum, create tasks for each implementation step so progress is tracked.

After persisting, present the plan to the user and **wait for confirmation** before implementing.
This is the most important pause in the workflow — alignment here prevents expensive rework.

---

## Phase 3: Implement Changes

Execute the confirmed plan, task by task. As you work:

**Activate relevant skills** for this session if they are available:

| Condition                                    | Skill to activate                          |
|----------------------------------------------|--------------------------------------------|
| Project uses Python                          | `pyright-lsp`                              |
| Project uses Go                              | `gopls-lsp`                                |
| Project uses Rust                            | `rust-analyzer-lsp`                        |
| Project uses Java/Kotlin (JVM)               | `jdtls-lsp` or `kotlin-lsp`               |
| Project uses C/C++                           | `clangd-lsp`                               |
| Project uses Ruby                            | `ruby-lsp`                                 |
| Project uses PHP                             | `php-lsp`                                  |
| Building UI components or frontend pages     | `frontend-design`                          |
| Integrating with Claude API / Anthropic SDK  | `claude-api`                               |

Read surrounding code before writing new code — match the project's naming conventions, error
handling style, and patterns. Don't introduce patterns that are foreign to the codebase.

Mark each implementation task as completed in the persisted plan as you finish it.

---

## Phase 4: Add Tests

**Skip this phase entirely if:**
- The change is a **data migration**, OR
- No testing framework can be detected in the project

Otherwise, add tests appropriate to the change:

| Test type      | When to add                                                     |
|----------------|-----------------------------------------------------------------|
| Unit           | Pure functions, utilities, business logic, isolated components  |
| Integration    | Service boundaries, database interactions, API clients          |
| E2E            | User-facing flows — only if an E2E framework already exists     |

Find existing test files near the code you changed and mirror their structure exactly — file
naming, import style, assertion patterns. Don't introduce a new testing style into a project
that already has conventions.

---

## Phase 5: Run Tests & Fix Failures

Run the full test suite. If you don't know the test command, check in order:
- `package.json` → `scripts.test`
- `Makefile` → `test` target
- `pytest.ini` / `pyproject.toml` / `setup.cfg` for pytest
- `go test ./...` for Go projects
- `cargo test` for Rust
- Ask the user if still unclear

Fix failures and re-run until the suite is green. Don't commit until all tests pass.

---

## Phase 6: Commit

Use **conventional commits** with the ticket ID in the scope position:

```
<type>([TICKET-ID]): <short imperative description>

[optional body — explain the why, not the what]
```

**Types:** `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `migration`

**Examples:**
```
feat([BP-1234]): add rate limiting middleware to API gateway
fix([BP-5678]): handle null response from payment provider
chore([BP-9012]): upgrade deps to address CVE-2024-1234
migration([BP-3456]): add user_preferences column to accounts table
refactor([BP-7890]): extract auth logic into dedicated service
```

If no ticket ID was provided, use a descriptive scope: `feat(auth): ...`

Stage files intentionally — name them explicitly rather than using `git add .`. Don't
accidentally include env files, secrets, or unrelated changes.

---

## Phase 7: Push

Push to the current branch. Confirm it is not `main`, `master`, or `release-*` first.

```bash
git push -u origin <current-branch>
```

Report back: branch name, what was pushed, and any next steps (e.g., open a PR).

---

## Working Style
- Always create a task list using TaskCreate when working on complex multi-step tasks to track progress.

## Composing with Other Skills

This skill is the workflow backbone — it sets the process and enforces the rules. Domain skills
do the specialized work within Phase 3. They are not in conflict; they layer naturally.

- If `frontend-design` is active, defer to its patterns when writing UI code in Phase 3
- If a language server skill is active, use its tools (type lookup, symbol navigation, diagnostics)
  to validate types and find references before and after writing code
- After implementation, you may invoke `simplify` during Phase 5 if the user asks for a
  code quality pass before committing

The goal of this skill is a clean, tested, well-described commit on the right branch — every time.
