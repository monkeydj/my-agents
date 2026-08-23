# Practical Integration: Practical Integration Patterns & Operational Limits

**Status:** IN PROGRESS
**Last updated:** 2026-08-23T00:00:00Z

---

## CRITICAL INSTRUCTIONS FOR AGENT

> **YOU WILL BE STOPPED AND RELAUNCHED IF YOU VIOLATE THIS PROTOCOL.**
>
> The ONLY acceptable pattern is: **Search -> Edit -> Search -> Edit -> Search -> Edit.**
> NEVER: Search -> Search. NO EXCEPTIONS. NOT EVEN ONCE.
>
> After EVERY search or fetch, IMMEDIATELY Edit this file with what you learned.
> If you do two searches in a row without an Edit to this file, you are VIOLATING THE PROTOCOL and will be killed.
>
> Work through sections in order. For each section:
> 1. Search/fetch for information
> 2. IMMEDIATELY write findings to this file under that section
> 3. Search/fetch for more information on the same section
> 4. IMMEDIATELY update this file with additional findings
> 5. Move to next section only after writing current section
>
> If a web fetch returns a 403 error, WRITE WHAT YOU HAVE before trying another URL.
>
> Every number needs a source. Every source needs a clickable URL inline.
> Do NOT collect sources at the end -- put them inline with the facts.
>
> When you are DONE with all sections, change "Status: IN PROGRESS" to "Status: COMPLETE" at the top.

---

## 1. Single server vs. multiple servers — one agentmemory on :3111 serving all agents?

**Recommendation: One agentmemory server on port 3111 serving all agents simultaneously.**

Agentmemory is designed as a single shared memory server that multiple agents connect to via MCP/REST. The README explicitly states: *"All agents share the same memory server"* and *"Works with any agent that speaks MCP or HTTP. One server, memories shared across all of them."* [Source](https://github.com/rohitg00/agentmemory/blob/main/README.md)

**Architecture:**
- Single agentmemory process runs on `http://localhost:3111` (REST API)
- Real-time viewer on `http://localhost:3113`
- Streams on port 3112, iii-engine WebSocket on 49134
- All agents (ccli lifanuke, default claude, OpenCode, Codex CLI, Hermes) connect to the same endpoint via `AGENTMEMORY_URL=http://localhost:3111`

**Multi-agent isolation via `AGENT_ID` and `AGENTMEMORY_AGENT_SCOPE`:**
- Set `AGENT_ID` per agent (e.g., `AGENT_ID=lifanuke`, `AGENT_ID=default-claude`, `AGENT_ID=opencode`, `AGENT_ID=codex`, `AGENT_ID=hermes`)
- Enable `AGENTMEMORY_AGENT_SCOPE=isolated` (default is `shared`) to filter recall by agentId
- Each agent's writes are tagged with its `agentId`; isolated mode filters reads to only that agent's memories
- Per-request override via `?agentId=<role>` or `agentId: "*"` to bypass scope [Source](https://github.com/rohitg00/agentmemory/blob/main/README.md) (lines 2585-2624 in CHANGELOG)

**Project attribution:**
- Project is derived from working directory (cwd) at session start
- Each agent session carries `project` field; memories are queryable by project
- OpenCode plugin notes: *"Project attribution is per-session, so one OpenCode process spanning several repositories files each session under its own project"* [Source](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md)

**Running multiple instances (if needed):**
- Use `--instance N` flag (e.g., `--instance 1` → ports 3211/3212/3213/49234)
- Or `--port N` which derives streams=REST+1, engine=REST+46023
- Env overrides: `III_STREAM_PORT`, `III_ENGINE_PORT`, `III_ENGINE_URL` [Source](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md) (PR #651, PR #815)

**Bottom line:** Single server on :3111 is the intended and tested pattern. Use `AGENT_ID` + `AGENTMEMORY_AGENT_SCOPE=isolated` for agent-level memory isolation while sharing infrastructure.

## 2. MCP config — universal JSON with AGENTMEMORY_URL; per-agent agentId env

**Universal MCP server block (same for all agents):**

```json
{
  "mcpServers": {
    "agentmemory": {
      "command": "npx",
      "args": ["-y", "@agentmemory/mcp"],
      "env": {
        "AGENTMEMORY_URL": "http://localhost:3111",
        "AGENTMEMORY_SECRET": "${AGENTMEMORY_SECRET}"
      }
    }
  }
}
```

This block works across Claude Code, Cursor, Codex CLI, Gemini CLI, OpenClaw, Cline, Roo Code, Claude Desktop, and any MCP-compatible host [Source](https://github.com/rohitg00/agentmemory/blob/main/README.md) (Standard MCP block section).

**Per-agent config locations and agentId injection:**

| Agent | Config File | agentId Injection Method |
|-------|-------------|--------------------------|
| **ccli (lifanuke profile)** | `~/.another-claudes/lifanuke/settings.json` (via `CLAUDE_CONFIG_DIR`) | Set `AGENT_ID=lifanuke` in shell env or `~/.agentmemory/.env`; plugin reads from process env |
| **default claude** | `~/.claude/settings.json` | Set `AGENT_ID=default-claude` in shell env |
| **OpenCode** | `~/.config/opencode/opencode.json` | OpenCode plugin reads `AGENT_ID` from process env at hook runtime [Source](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md) |
| **Codex CLI** | `~/.codex/config.toml` or plugin hooks | Codex plugin registers 6 lifecycle hooks; `AGENT_ID` via shell env |
| **Hermes** | `~/.hermes/config.yaml` | Hermes plugin reads `AGENTMEMORY_URL`, `AGENTMEMORY_SECRET` from `~/.agentmemory/.env` at import time [Source](https://github.com/rohitg00/agentmemory/blob/main/integrations/hermes/README.md) |

**Agent-specific MCP config shapes:**

- **OpenCode** (different shape — top-level `mcp` key, command as array):
  ```json
  {
    "mcp": {
      "agentmemory": {
        "type": "local",
        "command": ["npx", "-y", "@agentmemory/mcp"],
        "enabled": true
      }
    }
  }
  ```
  [Source](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md)

- **Codex CLI** (TOML):
  ```toml
  [mcp_servers.agentmemory]
  command = "npx"
  args = ["-y", "@agentmemory/mcp"]
  env = { AGENTMEMORY_URL = "http://localhost:3111" }
  ```

- **Hermes** (YAML):
  ```yaml
  mcp_servers:
    agentmemory:
      command: npx
      args: ["-y", "@agentmemory/mcp"]
  memory:
    provider: agentmemory
  ```

**Environment variable strategy:**
- Put shared config in `~/.agentmemory/.env` (no `export` prefix):
  ```
  AGENTMEMORY_URL=http://localhost:3111
  AGENTMEMORY_SECRET=your-secret-if-needed
  AGENTMEMORY_AGENT_SCOPE=isolated
  ```
- Per-agent `AGENT_ID` set in each agent's launch environment:
  - ccli lifanuke: `AGENT_ID=lifanuke ccli ...`
  - default claude: `AGENT_ID=default-claude claude ...`
  - OpenCode: `AGENT_ID=opencode opencode ...`
  - Codex: `AGENT_ID=codex codex ...`
  - Hermes: `AGENT_ID=hermes hermes ...`

**MCP tool surface:**
- Full 54 tools available **only when MCP shim reaches a running agentmemory server** via `AGENTMEMORY_URL`
- Without server: falls back to 7 local tools (`memory_save`, `memory_recall`, `memory_smart_search`, `memory_sessions`, `memory_export`, `memory_audit`, `memory_governance_delete`) [Source](https://github.com/rohitg00/agentmemory/blob/main/README.md) (MCP shim vs full server section)
- Use `AGENTMEMORY_TOOLS=core` for lean 8-tool set on hosts with tight tool limits

## 3. Memory lifecycle — auto-capture hooks, consolidation on stop, graph extraction

### Auto-capture hooks (per agent)

**Claude Code (12 hooks via plugin):**
- SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PreCompact, Stop, SessionEnd, Notification, SubagentStop, TaskCompleted, PostToolUseFailure, SubagentStart
- Auto-wired via `/plugin install agentmemory` which registers hooks + skills + MCP via `.mcp.json` [Source](https://github.com/rohitg00/agentmemory/blob/main/README.md) (Claude Code section)

**Codex CLI (6 hooks via plugin):**
- SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PreCompact, Stop
- Codex Desktop: plugin hooks currently silent (issue [openai/codex#16430](https://github.com/openai/codex/issues/16430)); workaround: `agentmemory connect codex --with-hooks` mirrors hooks to `~/.codex/hooks.json` [Source](https://github.com/rohitg00/agentmemory/blob/main/README.md) (Codex CLI section)

**OpenCode (22 hooks via plugin):**
- Covers session lifecycle, messages, tools, errors, file enrichment, permissions, tasks, model config
- Two-layer injection pipeline: memory context (once/session via `/context`) + file enrichment (per file batch via `/enrich`) [Source](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md)

**Hermes (6 lifecycle hooks via memory provider plugin):**
- `prefetch()` — injects relevant memories before each LLM call
- `sync_turn()` — captures every conversation turn in background
- `on_session_end()` — marks sessions complete for summarization
- `on_pre_compress()` — re-injects context before compaction
- `on_memory_write()` — mirrors MEMORY.md writes to agentmemory
- `system_prompt_block()` — injects project profile at session start [Source](https://github.com/rohitg00/agentmemory/blob/main/integrations/hermes/README.md)

### Consolidation pipeline

**4-tier consolidation (runs automatically when LLM provider configured):**
1. **Raw observations** → compressed observations (LLM summarization)
2. **Compressed observations** → session crystals (key facts, decisions, patterns)
3. **Crystals** → lessons (generalizable insights, cross-session)
4. **Lessons** → knowledge graph entities/relations (graph extraction) [Source](https://github.com/rohitg00/agentmemory/blob/main/README.md) (4-tier memory consolidation section)

**Trigger points:**
- **On session end** (`session.deleted` / `session.compacted`): consolidation runs automatically [Source](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md) (Consolidation pipeline now called on session.deleted)
- **Scheduled cron**: nightly consolidation, decay sweeps, snapshot rotation via `iii-cron` worker [Source](https://github.com/rohitg00/agentmemory/blob/main/iii-config.yaml)
- **Manual**: `POST /agentmemory/graph/build` backfills graph from existing observations [Source](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md) (PR #698)

**Consolidation config (in `~/.agentmemory/.env`):**
```
# On by default when LLM provider configured; opt out:
CONSOLIDATION_ENABLED=false

# Graph extraction separate flag (enabled by default with LLM):
GRAPH_EXTRACTION_ENABLED=false

# Token budget for compression (default 2000 tokens):
AGENTMEMORY_COMPRESSION_TOKEN_BUDGET=2000
```

**Keyless mode (no LLM key):**
- Synthetic BM25 compression + recall still work
- No LLM-backed summarization, crystals, lessons, or graph extraction
- Set `CONSOLIDATION_ENABLED=false` explicitly to suppress warnings [Source](https://github.com/rohitg00/agentmemory/blob/main/README.md) (LLM Providers section)

### Graph extraction

- **Keyless graph population**: Since v0.9.26, knowledge graph populates without LLM key using heuristic extraction [Source](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md) (Release wave notes)
- **Graphify integration**: Import Graphify's structural graph via `POST /agentmemory/graph/import-graphify` with `GRAPH_EXTRACTION_ENABLED=true` [Source](https://github.com/rohitg00/agentmemory/blob/main/docs/recipes/pairings.md)
- **Viewer**: "Build Graph" button triggers `/agentmemory/graph/build` endpoint

### Index persistence & flush on stop

- **Sharded BM25/vector index** with manifest commit/rollback (since v0.9.25) — large snapshots write as bounded shards, manifest published only after all shards commit [Source](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md) (PR #764)
- **Stop order fixed** (v0.9.26): worker stops first (5s SIGTERM grace for index flush), then engine — prevents "all data lost on stop+restart" bug [Source](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md) (Issue #843 fix)
- **Deleted memories** cleared from BM25 + vector indices synchronously via `SearchIndex.remove()` so SIGKILL between mutation + debounce can't resurrect entries [Source](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md) (PR #636)
- **Docker-mode stop**: CLI reaps native worker before Docker teardown; refuses to signal Docker/VM port holders unless `--force` [Source](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md) (Issue #1151 fix)

## 4. Token costs — consolidation needs LLM key; capture/recall work without

[To be filled by research agent]

## 5. Operational gotchas — viewer port conflicts, index flush on stop, Docker vs. bare

[To be filled by research agent]