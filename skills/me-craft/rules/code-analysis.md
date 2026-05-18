# Code Analysis & Exploration — Implementation Phase

This document defines how to navigate and analyze the codebase during **Phase 1 (Implement)**,
**Phase 3 (Run Tests & Fix Failures)**, and **Phase 4 (Commit)**. The goal is safe, precise
code changes — read before writing, check blast radius before deleting, analyze before committing.

---

## Codebase Navigation

### contextplus MCP (for local codebase)

contextplus is an optional MCP server that adds semantic intelligence to implementation-time
navigation. When it is configured, it gives you blast radius analysis, file skeletons, and
static analysis — the core safety tools for writing code.

**Check availability:** if `get_file_skeleton` is in the tool list, contextplus is active.

> **Craftsman mindset:** These tools prevent you from breaking call sites you didn't know existed. Use them before every structural change — not as a formality, but as a professional habit.

#### Tool reference

| Tool | Purpose | When to use |
|---|---|---|
| `get_file_skeleton` | Function signatures and types without the full body | Phase 1 — before every full file read; orient before diving in |
| `semantic_identifier_search` | Find functions/classes and all call sites | Phase 1 — locate all usages before modifying a symbol |
| `get_blast_radius` | Every file and line that imports/uses a symbol | Phase 1 — **mandatory** before any deletion or rename |
| `run_static_analysis` | Native linter (tsc / pyright / cargo / go vet) | Phase 3 — before running tests; fix all issues first |
| `undo_change` | Revert a file to its shadow restore point | Any phase — non-destructive rollback without touching git |
| `search_memory_graph` | Semantic search + graph traversal over stored nodes | Phase 1 — recall me-draft's findings before writing code |
| `upsert_memory_node` | Store a concept, file, or symbol in the knowledge graph | After Phase 1 — persist non-obvious implementation discoveries |
| `create_relation` | Link two memory nodes with a typed edge | After `upsert_memory_node` — record ownership or dependency |

#### Hard gates

- **`get_blast_radius` before every deletion or rename** — if you skip it and orphan a call site,
  the tests will catch it, but the error will be harder to trace. No exceptions.
- **`run_static_analysis` before marking any task complete** — clean code before moving on.

#### What contextplus does NOT replace

- **TaskCreate / TaskUpdate** — still used for plan tracking
- **GitLab MCP tools** — still used for MR creation (Phase 4)
- **Standard Read / Edit / Write tools** — still used for files; `get_file_skeleton` informs
  when a full read is necessary, but does not replace the Read tool itself
- **propose_commit** — contextplus's own commit tool enforces strict 2-line header formatting
  that conflicts with the "match existing code style" rule. Do **not** use `propose_commit`
  unless the user explicitly opts in. Use standard git commit (Phase 4) instead.

#### Memory graph — when to persist

After completing a task, persist knowledge that would save the next person an hour of investigation:

```
Persist when: you discover a non-obvious dependency, an undocumented invariant,
              ownership information that isn't in code comments or git history,
              or any finding that would take meaningful effort to re-derive.
Skip when:    the information is obvious from the code or covered by a docstring.
```

Create a node with `upsert_memory_node`, then link it to related nodes with `create_relation`
using typed edges (`depends_on`, `implements`, `uses`, `owns`).

---

## Library & Framework References

When implementing against a library or framework, use **Context7** for up-to-date docs and
code examples. Training data may not reflect recent API changes.

### Context7 CLI (preferred)

```bash
# Step 1: Find the library ID
npx ctx7@latest library "<library name>" "<what you want to do>"

# Step 2: Get documentation
npx ctx7@latest docs <libraryId> "<your question>"
```

**Example:**
```bash
npx ctx7@latest library "nextjs" "middleware authentication"
# Returns: /vercel/next.js

npx ctx7@latest docs /vercel/next.js "middleware authentication"
# Returns: Current docs with code examples
```

### When to use Context7

| Scenario | Action |
|---|---|
| Implementing against a library method you're unsure of | Use Context7 |
| Need code examples for a specific API | Use Context7 |
| Configuring a library | Use Context7 |

> **Default to Context7 first.** Only escalate to websearch if Context7 doesn't yield useful results
> or the library is too niche/new to be indexed.

---

## Static Analysis

Run native linters before committing to catch type errors and dead code early:

| Language | Tool |
|---|---|
| TypeScript/JavaScript | `tsc`, `eslint` |
| Python | `pyright`, `ruff` |
| Go | `go vet`, `golangci-lint` |
| Rust | `cargo check`, `clippy` |
| Ruby | `rubocop` |
| PHP | `phpcs`, `phpstan` |

Run via contextplus if available: `run_static_analysis`, or run the native CLI tool directly.
Always fix all issues before moving to Phase 3 (Run Tests).
