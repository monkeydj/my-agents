---
name: me-craft
description: >
  Craftsman-driven implementation workflow: self-iterating code → test → commit → push cycles
  that follow coding best practices by domain. Expects a confirmed development plan (from me-draft
  or equivalent). TRIGGER when the user has a plan and wants to start implementing — even if they
  don't say "me-craft" explicitly. Activate for phrases like: "let's implement the plan",
  "start coding", "build it", "code this up", "implement the steps", "execute the plan",
  "write the code", "follow the plan and implement", "let's go", "run the implementation".
  Also trigger when the user has already reviewed requirements and wants to move to execution.
  This skill enforces TDD discipline, domain-specific best practices, clean commits with
  conventional messages, and a push + Draft MR on every completion. Quality over speed — refactor before committing.
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, TaskUpdate, get_file_skeleton, semantic_identifier_search, get_blast_radius, run_static_analysis, undo_change, search_memory_graph, upsert_memory_node, create_relation, mcp__gitlab__create_merge_request
---

# me-craft: Craftsman Implementation Workflow

This skill executes a confirmed development plan through to a clean, tested commit on the right branch.
It composes with domain references and language server skills. It does not re-plan — it delivers.

Work through the phases in order. Mark each task complete with TaskUpdate as you go.

---

## Phase 0: Branch Safety (Always First)

Run `git branch --show-current` before touching any code.

| Current branch     | What to do                                                                                        |
|--------------------|---------------------------------------------------------------------------------------------------|
| `main` or `master` | Stop. Ask the user for a branch name. Suggest a prefix based on intent: `feat/`, `fix/`, `chore/`, or `migration/`. Create and switch once confirmed. |
| `release-*`        | Switch to `main`/`master` first, then apply the same rule above.                                |
| Anything else      | Continue to Phase 1.                                                                             |

**Hard constraint:** Never push to `main`, `master`, or any `release-*` branch at any point.

---

## Phase 1: Implement Changes

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

**Domain references** — detect which apply and load them before writing any code.
See the [Technical Domain References](#technical-domain-references) section below.

> **Self-review before next task:** Before marking a task complete, run `run_static_analysis`
and fix any issues. Then ask: "Would I be proud to show this to a peer?" If not, refactor first.

Mark each task as completed with TaskUpdate as you finish it.

---

## Phase 2: Add Tests

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

## Phase 3: Run Tests & Fix Failures

> **Craftsman mindset:** A failing test is a conversation. Read it carefully — it tells you something about the system. Don't guess. Trace, understand, then fix.

For Python projects, ensure the virtual environment is active before running any command
(see the environment detection table in Phase 1).

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

## Phase 4: Commit, Push & MR

See [`workflow/commit-n-push.md`](workflow/commit-n-push.md).

---

## Phase 5: Post-Commit Code Review (Optional)

See [`workflow/review-code-changes.md`](workflow/review-code-changes.md).

---

The workflow is complete. A craftsman delivers quality work and welcomes review.

---

## Technical Domain References

> **Craftsman mindset:** These references are guardrails, not blueprints. Apply judgment. If a reference conflicts with existing code, existing code wins — consistency within a codebase matters more than following an external pattern.

During **Phase 1**, detect which references apply to the current repo and read them before writing
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

## Code Analysis & Exploration

For codebase navigation and static analysis, see:

- **[`rules/code-analysis.md`](rules/code-analysis.md)** — contextplus MCP tools, Context7 for library/framework references, and static analysis tools

---

## Composing with Other Skills

This skill is the execution layer — domain skills and LSP tools layer within Phase 1.

- If `frontend-design` is active, defer to its patterns when writing UI code in Phase 1
- If a language server skill is active, use its tools (type lookup, symbol navigation, diagnostics)
  to validate types and find references before and after writing code
- If contextplus MCP is active, its tools layer on top of both — use them for codebase mapping
  and blast radius checks; they do not replace language server or domain skill responsibilities.
  See [`rules/code-analysis.md`](rules/code-analysis.md) for details.
- After implementation, you may invoke `simplify` during Phase 3 if the user asks for a
  code quality pass before committing

**Conflict resolution:** If skills conflict, ask the user — don't guess. Domain skill usually wins for its domain.

The goal of this skill is a clean, tested, well-described commit on the right branch — every time.
