# Code Analysis & Exploration — Analysis Phase

This document defines how to explore and analyze the codebase during **Phase 1 (Review & Analyze)**
and **Phase 2 (Craft Plan)**. The goal is comprehension and mapping — no code is written here.

---

## Codebase Navigation

### contextplus MCP (for local codebase)

contextplus is an optional MCP server that adds semantic intelligence to codebase exploration.
When it is configured, it replaces manual file traversal and grep-based searches with
AST-aware, embedding-backed tools.

**Check availability:** if `get_context_tree` is in the tool list, contextplus is active.

> **Craftsman mindset:** These tools give you superhuman codebase navigation — use them to understand faster, not to skip understanding. The goal is comprehension, not speed.

#### Tool reference

| Tool | Purpose | When to use |
|---|---|---|
| `get_context_tree` | Project-wide symbol map with token-aware pruning | Phase 1 — first step, before any file reads |
| `semantic_code_search` | Find files by meaning via embeddings | Phase 1 — locate relevant files from ticket language |
| `semantic_identifier_search` | Find functions/classes and all call sites | Phase 1 — map usages when assessing scope of a change |
| `semantic_navigate` | Group files into semantic clusters | Phase 1 — discover related code not obvious from names |
| `get_file_skeleton` | Function signatures and types without the full body | Phase 1 — understand a file's shape before reading it in full |
| `search_memory_graph` | Semantic search + graph traversal over stored nodes | Phase 1 — recall prior knowledge about the repo before re-exploring |
| `upsert_memory_node` | Store a concept, file, or symbol in the knowledge graph | After Phase 2 — persist non-obvious findings for future sessions |
| `create_relation` | Link two memory nodes with a typed edge | After `upsert_memory_node` — record dependencies discovered during analysis |
| `undo_change` | Revert a file to its shadow restore point | If exploration causes any unintended file changes |

#### What contextplus does NOT replace

- **TaskCreate / TaskUpdate** — still used for plan tracking in Phase 2
- **Standard Read / Glob / Grep tools** — still used for files; `get_file_skeleton` informs
  when a full read is necessary, but does not replace the Read tool itself

#### Memory graph — when to persist

After completing Phase 2, persist knowledge that would save the next person an hour of investigation:

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

When the plan involves libraries or frameworks, use **Context7** to understand current APIs
before committing to an approach — training data may be stale.

### Context7 CLI

```bash
# Step 1: Find the library ID
npx ctx7@latest library "<library name>" "<what you want to understand>"

# Step 2: Get documentation
npx ctx7@latest docs <libraryId> "<your question>"
```

### When to use Context7 during analysis

| Scenario | Action |
|---|---|
| Assessing feasibility of an approach using a library | Use Context7 to check if the API supports it |
| Identifying constraints from a framework before planning | Use Context7 |
| Uncertain which library capability fits the requirement | Use Context7 to compare options |

> **Default to Context7 first.** Only escalate to websearch if Context7 doesn't yield useful results.
