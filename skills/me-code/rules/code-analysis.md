# Code Analysis & Exploration

This document defines how to explore and analyze the codebase during development.

---

## Codebase Navigation

### contextplus MCP (for local codebase)

contextplus (https://github.com/ForLoopCodes/contextplus) is an optional MCP server that adds
semantic intelligence to the workflow. When it is configured, it replaces manual file traversal
and grep-based searches with AST-aware, embedding-backed tools.

**Check availability:** if `get_context_tree` is in the tool list, contextplus is active.

> **Craftsman mindset:** These tools give you superhuman codebase navigation — use them to understand faster, not to skip understanding. The goal is comprehension, not speed.

#### Tool reference

| Tool | Purpose | When to use |
|---|---|---|
| `get_context_tree` | Project-wide symbol map with token-aware pruning | Phase 1 — first step before any file reads |
| `get_file_skeleton` | Function signatures and types without the full body | Phase 3 — before every full file read |
| `semantic_code_search` | Find files by meaning via Ollama embeddings | Phase 1 — locate relevant files from ticket language |
| `semantic_identifier_search` | Find functions/classes and all call sites | Phase 3 — locate symbol usages before refactoring |
| `semantic_navigate` | Group files into semantic clusters | Phase 1 — discover related code not obvious from names |
| `get_blast_radius` | Every file and line that imports/uses a symbol | Phase 3 — **mandatory** before any deletion or rename |
| `run_static_analysis` | Native linter (tsc / pyright / cargo / go vet) | Phase 5 — before running tests |
| `upsert_memory_node` | Store a concept, file, or symbol in the knowledge graph | After Phase 3 — persist non-obvious codebase facts |
| `create_relation` | Link two memory nodes with a typed edge | After `upsert_memory_node` — record dependencies/ownership |
| `search_memory_graph` | Semantic search + graph traversal over stored nodes | Phase 1 — recall prior knowledge about the repo |
| `undo_change` | Revert a file to its shadow restore point | Any phase — non-destructive rollback without touching git |

#### What contextplus does NOT replace

- **TaskCreate / TaskUpdate** — still used for plan tracking
- **GitLab MCP tools** — still used for MR creation (Phase 7)
- **Standard Read / Edit / Write tools** — still used for files; `get_file_skeleton` informs
  when a full read is necessary, but does not replace the Read tool itself
- **propose_commit** — contextplus's own commit tool enforces strict 2-line header formatting
  that conflicts with the "match existing code style" rule. Do **not** use `propose_commit`
  unless the user explicitly opts in. Use standard git commit (Phase 6) instead.

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

When working with libraries or frameworks in the codebase, use **Context7** for up-to-date documentation.

### Context7 CLI (preferred)

If Context7 skill is installed, it will trigger automatically for library-related questions. You can also use the CLI directly:

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
| Working with a library/framework in the codebase and need to understand its API | Use Context7 (CLI or skill) |
| Need code examples for a specific library method | Use Context7 |
| Setting up or configuring a library | Use Context7 |
| Uncertain which library to use for a task | Use Context7 to compare options |

### When to use WebSearch

Use **websearch** only when:
- Context7 doesn't have the specific library
- You need community discussions or troubleshooting (Stack Overflow, GitHub issues)
- The library is niche or recently released and not yet in Context7

> **Default to Context7 first.** Only escalate to websearch if Context7 doesn't yield useful results.

---

## Static Analysis

Run native linters before committing to catch errors early:

| Language | Tool |
|---|---|
| TypeScript/JavaScript | `tsc`, `eslint` |
| Python | `pyright`, `ruff` |
| Go | `go vet`, `golangci-lint` |
| Rust | `cargo check`, `clippy` |
| Ruby | `rubocop` |
| PHP | `phpcs`, `phpstan` |

Run via contextplus if available: `run_static_analysis`, or run directly via the appropriate CLI tool.
