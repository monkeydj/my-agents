## Knowledge Graphs

This project has two graph tools. Use graph tools before Grep/Glob/Read when possible — they're faster, cheaper (fewer tokens), and give structural context.

### Routing: Which Graph Tool When

| Question | Use |
|----------|-----|
| Cross-module "how does X relate to Y" | `graphify query`, `graphify path` |
| Architecture overview, community structure | `graphify-out/GRAPH_REPORT.md` or `get_architecture_overview` |
| God nodes, unexpected coupling | `graphify-out/GRAPH_REPORT.md` or `get_hub_nodes` / `get_bridge_nodes` |
| What breaks if I change X (mid-edit) | `get_impact_radius` |
| Code review — risk-scored changes | `detect_changes` + `get_review_context` |
| Find function/class by name or keyword | `semantic_search_nodes` (cosine similarity) |
| Trace callers, callees, imports, tests | `query_graph` with pattern |
| Which execution paths are impacted | `get_affected_flows` |
| Planning renames, finding dead code | `refactor_tool` |

**Core distinction:** graphify = static artifacts, good for exploration + docs. code-review-graph = live MCP tools, updates per file edit, good for blast radius + impact analysis during active coding.

### graphify

Graph at `graphify-out/`. Committed to git.

- Before answering architecture or codebase questions, read `graphify-out/GRAPH_REPORT.md` for god nodes and community structure
- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw files
- For cross-module questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse EXTRACTED + INFERRED edges
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)

### code-review-graph (MCP)

Live MCP server with 28 tools. Auto-updates on file changes via hooks.

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

Workflow:
1. `detect_changes` for code review
2. `get_affected_flows` to understand impact
3. `query_graph` pattern="tests_for" to check coverage
