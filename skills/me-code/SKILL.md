---
name: me-code
description: >
  Personalized incremental coding workflow skill that orchestrates the full development cycle per project.
  TRIGGER this skill whenever the user provides requirements, a ticket, a spec, or a PRD and wants to
  start implementing — even if they don't say "me-code" explicitly. Activate for phrases like:
  "implement this", "code this up", "let's build this feature", "start coding based on the ticket",
  "here's the spec, let's go", "follow my coding workflow", "build it", "implement the requirements".
  Also trigger when the user pastes a Jira/Linear/GitHub issue and expects you to begin development.
  This skill enforces branch safety, tracks the plan via TaskCreate, implements
  changes with language-server and domain skills, runs tests, and commits + pushes with
  conventional messages including ticket IDs.
---

# me-code: Personalized Incremental Coding Workflow

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

> **Craftsman mindset:** A software craftsman understands that quality starts before the first line of code is written. Thorough analysis prevents expensive rework and ensures the final work is maintainable, testable, and valuable.

Read everything the user has provided: tickets, specs, PRDs, Jira issues, inline requirements,
linked files. If the user referenced something without pasting it, ask for it.

### Step 1: Understand the "What" and "Why"

Before touching any code, articulate in your own words:
- **What** is being built or fixed? (the explicit requirement)
- **Why** does this need to exist? (the underlying problem or value)
- **Who** will use this? (the user/customer perspective)

If you cannot explain the "why" clearly, ask the user. A craftsman never assumes intent — they seek to understand.

### Step 2: Map the Codebase

Use **contextplus MCP** for semantic codebase navigation when available. See [`rules/code-analysis.md`](rules/code-analysis.md) for the full tool reference.

If contextplus is not available, use `ls`, `grep`, `glob`, and file reads manually —
but prioritize semantic tools when available.

### Step 3: Analyze with Craftsmanship Principles

For each potential change, evaluate through the lens of Software Craftsmanship:

| Principle | Questions to Ask |
|-----------|------------------|
| **Well-Crafted** | Will this code be readable, testable, and extendable? Does it follow existing patterns? Will future developers understand it? |
| **Steadily Adding Value** | Does this solve the real problem? What are the downstream effects of this design choice? Is this sustainable? |
| **Community of Professionals** | Are there existing patterns I should match? Would a peer recognize this as idiomatic? |
| **Continuous Learning** | Am I learning something new about this codebase? Does this reveal any technical debt worth noting? |

### Step 4: Identify Scope with Reasoning

Document your findings with **explicit reasoning** for each decision. Challenge your assumptions:

- **Type of change:** feature | bug fix | refactor | chore | data migration
  - *Reasoning:* Why this classification matters for the workflow
- **Affected scope:** which files, modules, services, or APIs are likely involved
  - *Reasoning:* How you identified these (via contextplus tools or manual exploration)
- **Technical constraints:** performance, backward compatibility, framework-specific rules
  - *Reasoning:* Why these constraints exist and how they shape the implementation
- **Testing approach:** Can this be tested in isolation? What are the boundaries?
  - *Reasoning:* TDD-readiness assessment — can we write tests first?
- **Refactoring opportunities:** Does the existing code need cleanup before adding new behavior?
  - *Reasoning:* "Clean code first" principle — don't layer new mess on old mess
- **Data migration flag:** if this is a migration, tests will be skipped in Phase 4
  - *Reasoning:* Migration safety — why tests are inappropriate for schema changes

### Step 5: Risk Assessment

Before proceeding to Phase 2, identify:
- **Integration points:** What other systems/modules does this touch?
- **Breaking changes:** Could this affect existing consumers? (API, DB, contract)
- **Rollback strategy:** How would we undo this if it fails?
- **Edge cases:** What are the failure modes no one mentioned?
- **Spike consideration:** If uncertainty is high, should you prototype first before full implementation?

If anything is ambiguous or underspecified, ask now — it's cheaper to clarify before planning
than to backtrack mid-implementation. A craftsman clarifies before acting.

---

## Phase 2: Craft & Persist the Development Plan

> **Craftsman mindset:** A development plan is not just a checklist — it's a contract with future-you and your team. Each task should be intentional, each decision reasoned.

Break the work into ordered, concrete tasks. Think through dependencies — what has to happen
before what. Identify which files need to change and roughly how.

> **Scaling the plan:** For small, straightforward changes (e.g., one-file fix, simple feature), use a simplified version of this template. For complex changes involving multiple modules, refactoring, or uncertain paths, use the full structure below. If uncertainty is high, add a **Spike** task to prototype before committing to an approach.

### Plan Structure with Reasoning

Every decision in the plan must include **why** — not just what. This follows the craftsmanship principle of "well-crafted" communication:

```
# Plan: [Feature/Fix Name]

## Context
[1-2 sentences on what and why]

**Ticket:** [ID if provided, e.g., BP-1234]
**Type:** feat | fix | chore | refactor | migration

## Analysis Summary
- **Why this approach?** [Explain reasoning — e.g., "Using existing pattern X because..."]
- **What are the risks?** [List identified risks from Phase 1]
- **What constraints must be honored?** [Performance, backward compat, etc.]

## Implementation Steps

### 1. [First concrete task]
- **Files:** [list affected files/modules]
- **Reasoning:** [Why this task first? What dependencies does it establish?]
- **Craftsmanship notes:** [Any pattern matching, refactoring needs, or testability concerns]

### 2. [Second task]
- **Files:** [list affected files/modules]
- **Reasoning:** [Why this task follows the previous one]
- **Craftsmanship notes:** [Edge cases, error handling, or design considerations]

...

## Test Strategy
- **Type:** unit | integration | e2e | skip
- **Reasoning:** [Why this test approach? TDD-feasible? What boundaries are being tested?]
- **TDD consideration:** [Can we write tests first? If not, why not?]

## Code Quality Gates
- [ ] **Readability:** Will another developer understand this in 6 months?
- [ ] **Testability:** Can this be tested in isolation?
- [ ] **Extensibility:** Will future changes require rewriting this?
- [ ] **Error handling:** Are failure modes explicit and handled?
- [ ] **Consistency:** Does this match existing codebase patterns?

## Refactoring Opportunities (Optional)
- [Any cleanup identified during analysis that could be done alongside this change]
- **Reasoning:** [Why do this now vs. later? "If not now, when?" principle]

## Rollback Plan
- [How to undo this change if it fails in production]
- **Reasoning:** A craftsman thinks about reversibility — forward progress without a retreat path is reckless

## Critical Files
[Key files that will be read or modified — with brief notes on what aspect matters]
```

### Task Tracking

**Track the plan with TaskCreate** — create one task per implementation step immediately after
drafting the plan. Include the reasoning as task notes when possible. Always append these two fixed tasks at the end:

```
[ ] Commit changes (Phase 6)
[ ] Push to remote (Phase 7)
```

**Order tasks by dependency, not convenience.** The logical sequence matters more than what's easiest.

### Alignment Check

Present the plan to the user and **wait for confirmation** before implementing.
This is the most important pause in the workflow — alignment here prevents expensive rework.

**Before presenting, verify:**
1. Each task has a clear "done" state
2. Dependencies are explicit (Task B needs Task A first)
3. Test strategy is defensible
4. Risks are acknowledged, not hidden

A craftsman plans with the same care they write code.

---

## Phase 3: Implement Changes

> **Craftsman mindset:** Write code as if the next person maintaining it is a fellow professional who deserves clarity. Think before you type. Clean code is not a luxury — it's respect.

Execute the confirmed plan, task by task. As you work, follow the TDD rhythm when starting fresh:

1. **Red** — Write a failing test that describes the behavior you want
2. **Green** — Write the minimum code to make it pass
3. **Refactor** — Clean up, then move to the next task

**Pause and refactor before moving on.** If the code smells during implementation, fix it now — don't accumulate debt. After each task, review what you wrote:
- Does it match the plan?
- Does the plan still make sense?
- Run `run_static_analysis` before marking the task complete — clean code first.

If something unexpected surfaces, update the plan before continuing. A craftsman adapts without excuse.

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

**Python projects — detect and activate the virtual environment before running any tooling.**

Check in this order and use the first match:

| Signal | Activation |
|---|---|
| `poetry.lock` present | prefix all commands with `poetry run` (e.g., `poetry run pytest`) |
| `Pipfile` present | prefix all commands with `pipenv run` |
| `uv.lock` or `.python-version` + `uv` in PATH | prefix with `uv run` |
| `.venv/` or `venv/` directory present | `source .venv/bin/activate` (or `venv/bin/activate`) once, then run commands bare |
| `requirements*.txt` only, no manager | `source .venv/bin/activate` if the directory exists; otherwise warn the user that no venv was found and ask how they manage the environment |

Never invoke `python`, `pip`, `pytest`, `flask`, `django-admin`, or any project CLI tool as a
bare global command in a Python project — always go through the environment manager or activated venv.

**If contextplus MCP is available**, apply these rules. See [`rules/code-analysis.md`](rules/code-analysis.md) for the full tool reference:

- Reading a file for the first time → `get_file_skeleton` first
- Deleting or renaming any symbol → **Mandatory:** `get_blast_radius` first
- Modifying a shared utility/interface → `get_blast_radius` to see call sites
- After writing code → `run_static_analysis` to catch errors

`get_blast_radius` is a hard gate — if you skip it and orphan a call site, the tests will tell
you, but the error will be harder to trace. Run it before every structural change.

Read surrounding code before writing new code — match the project's naming conventions, error
handling style, and patterns. Don't introduce patterns that are foreign to the codebase.

> **Self-review before next task:** Before marking a task complete, run `run_static_analysis` 
and fix any issues. Then ask: "Would I be proud to show this to a peer?" If not, refactor first.

Mark each task as completed with TaskUpdate as you finish it.

---

## Phase 4: Add Tests

> **Craftsman mindset:** Tests are not an afterthought — they are the specification. Write tests that describe behavior, not implementation details. A test should read like documentation.

**Skip this phase entirely if:**
- The change is a **data migration**, OR
- No testing framework can be detected in the project

Otherwise, add tests appropriate to the change. Follow **Red-Green-Refactor**:
1. Write a failing test first (describe what you want)
2. Write the minimum code to make it pass
3. Refactor the test for readability

| Test type      | When to add                                                     |
|----------------|-----------------------------------------------------------------|
| Unit           | Pure functions, utilities, business logic, isolated components  |
| Integration    | Service boundaries, database interactions, API clients          |
| E2E            | User-facing flows — only if an E2E framework already exists     |

**Test quality principles:**
- Name tests to describe behavior, not implementation: `test_user_can_login` not `test_auth_module`
- Include edge cases and error paths, not just happy path
- Don't test framework internals — test behavior
- If a test is hard to write, the code might be hard to use — refactor the code first

Find existing test files near the code you changed and mirror their structure exactly — file
naming, import style, assertion patterns. Don't introduce a new testing style into a project
that already has conventions.

---

## Phase 5: Run Tests & Fix Failures

> **Craftsman mindset:** A failing test is a conversation. Read it carefully — it tells you something about the system. Don't guess. Trace, understand, then fix.

For Python projects, ensure the virtual environment is active before running any command
(see the environment detection table in Phase 3).

**Run static analysis first** to catch type errors and dead code. If contextplus is available, use `run_static_analysis`. Otherwise, run the native linter directly (see [`rules/code-analysis.md`](rules/code-analysis.md) for tool reference). Fix any issues before proceeding.

Run the full test suite. If you don't know the test command, check in order:
- `package.json` → `scripts.test`
- `Makefile` → `test` target
- `pytest.ini` / `pyproject.toml` / `setup.cfg` for pytest
- `go test ./...` for Go projects
- `cargo test` for Rust
- Ask the user if still unclear

**When tests fail:**
1. Read the failure message — understand what it's saying
2. Trace the stack — don't guess at the cause
3. Fix the root cause, not the symptom
4. If a test fails for an unrelated reason, fix the test — don't disable it
5. Never skip flaky tests — fix them or mark them as flaky

**Test isolation:** If tests interfere with each other, that's a code smell. Fix the test suite, don't reorder tests to hide the problem.

**Coverage watch:** If coverage drops significantly, ask: "What's no longer tested? Is that intentional?"

Fix failures and re-run until the suite is green. Don't commit until all tests pass.

---

## Phase 6: Commit

> **Mandatory.** This phase must run on every invocation. If tests are skipped (migration), commit
> immediately after Phase 3. Never stop the workflow here without a commit.

> **Craftsman mindset:** A commit is a unit of history. Make it meaningful. Don't pollute the timeline with WIP commits — squash before you push.

**Pre-commit review:** Before running `git commit`, review what you're actually committing:

```bash
git diff --staged
```

Ask yourself:
- Does this tell a coherent story?
- Is the commit message accurate?
- Are there any temp files, debug logs, or unintended changes?

Use **conventional commits** with the ticket ID in the scope position:

```
<type>(TICKET-ID): <short imperative description>

[optional body — explain the why, not the what]
```

**Types:** `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `migration`

**Examples:**
```
feat(BP-1234): add rate limiting middleware to API gateway
fix(GG-5678): handle null response from payment provider
chore(DRM-9012): upgrade deps to address CVE-2024-1234
migration(DATA-3456): add user_preferences column to accounts table
refactor(ARB-7890): extract auth logic into dedicated service
```

If no ticket ID was provided, use a descriptive scope: `feat(auth): ...`

Stage files intentionally — name them explicitly rather than using `git add .`. Don't
accidentally include env files, secrets, or unrelated changes.

**Squash WIP commits:** If you have commits like "WIP", "temp", or "fix typo", squash them before pushing. Clean history matters.

**Test files (from Phase 4) are staged in the same commit as the implementation.** A feature and
its tests are one logical unit — they belong together. Use a separate `test(...)` commit only when
adding or fixing tests for code that was already committed previously.

**Don't amend unless necessary.** If you've already pushed, don't amend — create a new commit.

---

## Phase 7: Push & Report MR

> **Mandatory.** Push immediately after committing. Do not wait for the user to ask. The workflow
> is not complete until the branch is on the remote.

> **Craftsman mindset:** Your work isn't done until it's visible to others. Make it easy for reviewers to understand what you did and why.

Push to the current branch. Confirm it is not `main`, `master`, or `release-*` first.

```bash
git push -u origin <current-branch>
```

**Self-review before MR exists:** Before creating the MR, review your diff one more time. This is the last chance to catch something before others see it.

After pushing, **always print the current branch name**. Then check for an existing MR on this branch:

- If an MR exists: print its URL prominently as the final output line.
- If no MR exists: **create a Draft MR automatically** using the GitLab MCP tool (`mcp__gitlab__create_merge_request`). Set `draft: true`. The user will open/ready it manually when ready. Print the newly created MR URL.

**Populate the MR description:** Don't leave it blank. Include:
- What this change does (summary)
- Why this change exists (context from Phase 1)
- How to test it (if not obvious)
- Any screenshots or demo steps for UI changes

Don't make reviewers hunt for context. A craftsman makes their work easy to review.

**End-of-workflow output format (always):**

```
Branch: <current-branch>
MR: <MR URL>
```

Never omit this block. It is the final line of the workflow.

---

---

## Technical Domain References

> **Craftsman mindset:** These references are guardrails, not blueprints. Apply judgment. If a reference conflicts with existing code, existing code wins — consistency within a codebase matters more than following an external pattern.

During **Phase 3**, detect which references apply to the current repo and read them before writing
any code. Match the existing code style first, then apply the referenced patterns where absent or
clearly needed.

**For external library/framework documentation:** Use Context7 to get up-to-date docs and code examples. See [`rules/code-analysis.md`](rules/code-analysis.md) for how to use Context7 CLI or skill.

**Detection — load references based on what you find in the repo:**

| Signal in repo | References to load |
|---|---|
| `manage.py` or `django` in `requirements*.txt` / `pyproject.toml` | Language — Python + Framework — Django |
| `flask` in `requirements*.txt` / `pyproject.toml` | Language — Python + Framework — Flask |
| `pyproject.toml`, `requirements*.txt`, or `*.py` files (no Django/Flask) | Language — Python |
| `package.json` with `"type": "module"` or CJS project, no frontend framework | Language — JavaScript / Node.js |
| Any of the above | Principles — Design Patterns + Principles — Error Handling (always) |

**Reference index:**

| Domain | File |
|---|---|
| Language — Python | [`references/language-python.md`](references/language-python.md) |
| Language — JavaScript / Node.js | [`references/language-javascript-nodejs.md`](references/language-javascript-nodejs.md) |
| Framework — Django | [`references/framework-django.md`](references/framework-django.md) |
| Framework — Flask | [`references/framework-flask.md`](references/framework-flask.md) |
| Principles — Design Patterns | [`references/principles-design-patterns.md`](references/principles-design-patterns.md) |
| Principles — Error Handling | [`references/principles-error-handling.md`](references/principles-error-handling.md) |

---

---

## Code Analysis & Exploration

For codebase navigation and static analysis, see:

- **[`rules/code-analysis.md`](rules/code-analysis.md)** — contextplus MCP tools, Context7 for library/framework references, and static analysis tools

---

## Working Style

> **Craftsman mindset:** This discipline isn't bureaucracy — it's respect for the process and the team. Each phase exists for a reason. Shortcuts create debt.

Create all tasks with TaskCreate during Phase 2 **before writing any code**. The commit and push
tasks are not optional — do not mark the workflow complete until both are checked off.

**When the user asks to stop early:**
- Still create the commit and push tasks
- Mark them as blocked and note the reason: "User requested to pause"
- Never silently drop them — transparency over assumption

If the user explicitly says "don't push" or "don't commit", respect their decision but document it. A craftsman is honest about the state of things.

## Composing with Other Skills

This skill is the workflow backbone — it sets the process and enforces the rules. Domain skills
do the specialized work within Phase 3. They are not in conflict; they layer naturally.

- If `frontend-design` is active, defer to its patterns when writing UI code in Phase 3
- If a language server skill is active, use its tools (type lookup, symbol navigation, diagnostics)
  to validate types and find references before and after writing code
- If contextplus MCP is active, its tools layer on top of both — use them for codebase mapping
  and blast radius checks; they do not replace language server or domain skill responsibilities.
  See [`rules/code-analysis.md`](rules/code-analysis.md) for details.
- After implementation, you may invoke `simplify` during Phase 5 if the user asks for a
  code quality pass before committing

**Conflict resolution:** If skills conflict (e.g., one says do X, another says do Y), ask the user — don't guess which takes precedence. When in doubt, the domain skill usually wins for its domain, but clarity beats assumption.

The goal of this skill is a clean, tested, well-described commit on the right branch — every time.
