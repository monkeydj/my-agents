# Cross-Agent Plugin Ecosystem & Interoperability Research

**Status:** COMPLETE
**Date:** 2026-08-23
**Research Question:** How do native plugins for different agents (Claude Code, OpenCode, Codex CLI, Hermes) interact with the same agentmemory server? Can memories written by one agent be recalled by another?

---

## 1. Plugin Matrix — Native vs MCP-Only; Hook Counts per Agent

| Agent | Native Plugin Location | Native Hooks | MCP Tools | Integration Type |
|-------|------------------------|--------------|-----------|------------------|
| **Claude Code** | `.claude-plugin/` + `plugin/hooks/hooks.json` | **12 hooks** (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, PreCompact, SubagentStart, SubagentStop, Notification, TaskCompleted, Stop, SessionEnd) | 54 tools via `@agentmemory/mcp` | Native plugin + MCP (auto-wired via `.mcp.json`) |
| **Codex CLI** | `.codex-plugin/` + `plugin/hooks/hooks.codex.json` | **6 hooks** (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PreCompact, Stop) | 54 tools via `@agentmemory/mcp` | Native plugin + MCP (hooks.json + mcpServers in plugin.json) |
| **OpenCode** | `plugin/opencode/` + `plugin/opencode/agentmemory-capture.ts` | **22 hooks** (session lifecycle, messages, tool lifecycle, parts, file enrichment, permissions, tasks, model/config) | 54 tools via MCP config in `opencode.json` | Native plugin (TypeScript) + MCP |
| **Hermes** | `integrations/hermes/` + `plugin.yaml` | **6 hooks** (prefetch, sync_turn, on_session_end, on_pre_compress, on_memory_write, system_prompt_block) | 54 tools via MCP config in `~/.hermes/config.yaml` | Native Python plugin + YAML config + MCP |
| **pi** | `integrations/pi/index.ts` | **4 hooks** (session_start, before_agent_start, tool_result, agent_end, session_shutdown) | 3 tools (memory_health, memory_search, memory_save) via REST | Native TypeScript extension + REST |
| **OpenClaw** | `integrations/openclaw/` + `plugin.yaml` | **4 hooks** (on_session_start, on_pre_llm_call, on_post_tool_use, on_session_end) | 43 tools via MCP config | Native plugin (YAML + JS) + MCP |
| **Cursor** | `plugin/cursor/hooks.json` | **7 hooks** (sessionStart, beforeSubmitPrompt, preToolUse, postToolUse, postToolUseFailure, stop, sessionEnd) | 54 tools via MCP | Native plugin + MCP |
| **Gemini CLI** | None | 0 | 54 tools via MCP | MCP-only |
| **GitHub Copilot CLI** | `plugin/.mcp.copilot.json` + GitHub subdir | Plugin hooks/skills via Copilot plugin system | 54 tools via MCP | MCP + optional full plugin |
| **Warp** | None | 0 | 54 tools via MCP | MCP-only + skills via `.claude/skills/` |
| **Zed** | None | 0 | 54 tools via MCP | MCP-only |
| **Devin** | `plugin/.devin-plugin/` + hooks via connect | 6 hooks via `connect devin --with-hooks` | 54 tools via MCP | MCP + optional hooks |
| **Cline / Roo Code / Kilo Code** | None | 0 | 54 tools via MCP | MCP-only |
| **Aider** | None | 0 | REST API only | REST-only |
| **Goose** | None | 0 | 54 tools via MCP | MCP-only |

**Sources:**
- [Claude Code hooks.json](https://github.com/rohitg00/agentmemory/blob/main/plugin/hooks/hooks.json)
- [Codex CLI hooks.codex.json](https://github.com/rohitg00/agentmemory/blob/main/plugin/hooks/hooks.codex.json)
- [OpenCode plugin README](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md)
- [Hermes plugin.yaml](https://github.com/rohitg00/agentmemory/blob/main/integrations/hermes/plugin.yaml)
- [pi index.ts](https://github.com/rohitg00/agentmemory/blob/main/integrations/pi/index.ts)
- [OpenClaw plugin.yaml](https://github.com/rohitg00/agentmemory/blob/main/integrations/openclaw/plugin.yaml)
- [Cursor hooks.json](https://github.com/rohitg00/agentmemory/blob/main/plugin/cursor/hooks.json)
- [Main README agent matrix](https://github.com/rohitg00/agentmemory/blob/main/README.md)

**Key Finding:** All four target agents (Claude Code, Codex CLI, OpenCode, Hermes) have **native plugins** with lifecycle hooks, not just MCP. The hook counts differ significantly: OpenCode (22) > Claude Code (12) > Hermes (6) = Codex CLI (6). All share the same 54 MCP tools via the universal `@agentmemory/mcp` server.

---

## 2. Memory Write Paths — memory_save via MCP vs Native Hooks; Schema Consistency

### Universal MCP Server Configuration
All agents use the **same MCP server block** (from `plugin/.mcp.json`):
```json
{
  "mcpServers": {
    "agentmemory": {
      "command": "npx",
      "args": ["-y", "@agentmemory/mcp"],
      "env": {
        "AGENTMEMORY_URL": "${AGENTMEMORY_URL:-http://localhost:3111}",
        "AGENTMEMORY_SECRET": "${AGENTMEMORY_SECRET:-}",
        "AGENTMEMORY_TOOLS": "${AGENTMEMORY_TOOLS:-all}"
      }
    }
  }
}
```
[Source: plugin/.mcp.json](https://github.com/rohitg00/agentmemory/blob/main/plugin/.mcp.json)

### Write Paths by Agent

| Agent | Primary Write Path | Hook-Driven Auto-Capture | Manual `memory_save` via MCP |
|-------|-------------------|-------------------------|------------------------------|
| **Claude Code** | 12 hooks → `POST /observe`, `POST /session/start`, `POST /summarize`, `POST /session/end` | Yes (all 12 hooks) | Available via 54 MCP tools |
| **Codex CLI** | 6 hooks → same REST endpoints | Yes (6 hooks) | Available via 54 MCP tools |
| **OpenCode** | 22 hooks → `POST /observe`, `/enrich`, `/context`, `/summarize`, `/session/start`, `/session/end` | Yes (22 hooks + two-layer pipeline) | Available via MCP tools |
| **Hermes** | 6 hooks → `prefetch()` calls `/context`, `sync_turn()` calls `/observe`, `on_memory_write()` mirrors MEMORY.md | Yes (6 hooks via memory provider) | Available via 54 MCP tools |
| **pi** | `before_agent_start` → `smart-search`; `agent_end` → `observe`; `memory_save` tool → `remember` | Yes (session_start, before_agent_start, tool_result, agent_end) | Via `memory_save` tool (REST) |
| **OpenClaw** | Hooks → `observe`; memory slot `promptBuilder` for recall | Yes (4 hooks) | Via 43 MCP tools |

### Schema Consistency
All native hooks and MCP tools converge on the **same REST API endpoints** on the agentmemory server:
- `POST /agentmemory/observe` — captures observations (hookType, sessionId, project, cwd, timestamp, data)
- `POST /agentmemory/remember` — explicit memory_save (content, type, project)
- `POST /agentmemory/smart-search` — recall (query, limit, project)
- `POST /agentmemory/context` — session context injection (project, sessionId)
- `POST /agentmemory/enrich` — file-specific enrichment (files[], project)
- `POST /agentmemory/session/start` — session metadata
- `POST /agentmemory/session/end` — session completion + consolidation trigger
- `POST /agentmemory/summarize` — session summarization

**Schema fields are consistent across agents:**
- `sessionId` (string) — unique per session
- `project` (string) — resolved via git toplevel basename or `AGENTMEMORY_PROJECT_NAME` env
- `cwd` (string) — working directory
- `hookType` (string) — event type (prompt_submit, pre_tool_use, post_tool_use, etc.)
- `data` (object) — agent-specific payload
- `timestamp` (ISO8601)

**Source:** [pi index.ts - callAgentMemory](https://github.com/rohitg00/agentmemory/blob/main/integrations/pi/index.ts#L130-L170), [OpenCode README hook table](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md), [Hermes README](https://github.com/rohitg00/agentmemory/blob/main/integrations/hermes/README.md)

**Key Finding:** All agents write to the **same REST endpoints** with **identical schema**. Native hooks auto-capture richer context (tool names, file paths, error states) while MCP `memory_save` provides manual write capability. The server normalizes all inputs into the same SQLite + vector + knowledge graph storage.

---

## 3. Cross-Agent Recall — Can Codex Recall What Claude Saved? Role of agentId Filter

### Project-Scoped Memory Sharing
**Yes, Codex can recall what Claude saved** — and vice versa — because **all agents share the same `project` scope** by default.

The project name is resolved identically across all agents:
1. `AGENTMEMORY_PROJECT_NAME` env var (explicit override)
2. Git repository toplevel basename (`git rev-parse --show-toplevel`)
3. Current working directory basename (fallback)

[Source: pi index.ts resolveProjectName](https://github.com/rohitg00/agentmemory/blob/main/integrations/pi/index.ts#L85-L105), [OpenCode README](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md)

### No agentId Filter in Core Recall
**There is no `agentId` filter** in the `smart-search` or `context` endpoints. Memories are **not tagged by originating agent** in the core schema. The `hookType` field indicates the event type (e.g., `prompt_submit`, `post_tool_use`) but not which agent generated it.

This means:
- A memory saved by Claude Code's `PostToolUse` hook appears identical to one saved by Codex CLI's `PostToolUse` hook
- `smart-search` returns all matching observations regardless of origin
- `context` endpoint injects project-scoped memories without agent attribution

### Cross-Agent Recall Verification
The README explicitly states: *"Cross-agent: memories from Claude Code, Cursor, Gemini CLI all accessible"* [Hermes README](https://github.com/rohitg00/agentmemory/blob/main/integrations/hermes/README.md) and *"One local agentmemory server can be shared across pi, pi2, Hermes, OpenClaw, Claude Code, Codex CLI, and Gemini CLI"* [pi README](https://github.com/rohitg00/agentmemory/blob/main/integrations/pi/README.md).

### Session Isolation vs Project Sharing
- **Sessions** are isolated per agent run (`sessionId` = unique per session)
- **Projects** are shared — all agents in the same git repo write to the same project bucket
- **Consolidation** runs server-side on `session/end` and merges cross-agent sessions into project-level crystals

**Key Finding:** Cross-agent recall works **by default** because all agents use the same project resolution logic. No `agentId` filter exists — memories are pooled by project, not by agent. This is a feature, not a bug: the system is designed for **shared team memory**, not agent-isolated memory.

---

## 4. Hermes & OpenCode Integration Details — Python Plugin + YAML vs Capture Plugin

### Hermes: Python Memory Provider Plugin + YAML Config

**Architecture:** Hermes has a built-in memory provider interface. agentmemory implements a **6-hook memory provider** as a Python plugin.

**Configuration (`~/.hermes/config.yaml`):**
```yaml
mcp_servers:
  agentmemory:
    command: npx
    args: ["-y", "@agentmemory/mcp"]

memory:
  provider: agentmemory
```

**Deeper Integration (copy plugin folder):**
```bash
cp -r integrations/hermes ~/.hermes/plugins/agentmemory
```
This enables the 6-hook provider that hooks directly into Hermes' agent loop:
- `prefetch()` → calls `/context` before each LLM call, injects relevant memories
- `sync_turn()` → calls `/observe` to capture every conversation turn in background
- `on_session_end()` → marks sessions complete for summarization
- `on_pre_compress()` → re-injects context before compaction
- `on_memory_write()` → mirrors MEMORY.md writes to agentmemory
- `system_prompt_block()` → injects project profile at session start

[Source: Hermes README](https://github.com/rohitg00/agentmemory/blob/main/integrations/hermes/README.md), [plugin.yaml](https://github.com/rohitg00/agentmemory/blob/main/integrations/hermes/plugin.yaml)

**Environment Variables** (read from `~/.agentmemory/.env` at import time):
- `AGENTMEMORY_URL` (default: `http://localhost:3111`)
- `AGENTMEMORY_SECRET` (bearer token)
- `AGENTMEMORY_REQUIRE_HTTPS` (enforce HTTPS for non-loopback)

### OpenCode: TypeScript Capture Plugin + Direct System Prompt Injection

**Architecture:** OpenCode plugin is a **TypeScript file** (`agentmemory-capture.ts`) that registers **22 hooks** via OpenCode's plugin SDK.

**Configuration (`~/.config/opencode/opencode.json`):**
```json
{
  "mcp": {
    "agentmemory": {
      "type": "local",
      "command": ["npx", "-y", "@agentmemory/mcp"],
      "enabled": true
    }
  },
  "plugin": ["./plugins/agentmemory-capture.ts"]
}
```

**Two-Layer Context Injection Pipeline** (via `experimental.chat.system.transform`):
1. **Memory Context** (once per session): calls `/agentmemory/context` → injects project profile, recent session summaries, important observations into `output.system[]`
2. **File Enrichment** (every file-touching turn): calls `/agentmemory/enrich` with stashed files → injects file-specific context (past observations, related bugs, semantic search)

```typescript
// System prompt composition:
System prompt = [OpenCode instructions] + [memory context] + [file enrichment] + [user message]
                                        ^                 ^
                               first turn only         every file-touching turn
```

**Hook Coverage (22 hooks):**
- Session lifecycle: `session.created`, `session.idle`, `session.status`, `session.compacted`, `session.updated`, `session.diff`, `session.deleted`, `session.error`
- Messages: `chat.message`, `message.updated` (user/assistant), `message.removed`
- Parts/Tools: `message.part.updated` (subtask, tool completed/error, step-finish, reasoning, patch, compaction, agent, retry)
- File enrichment: `tool.execute.before`, `file.edited`, `message.part.updated` (file) → stash paths → enrichment inject
- Permissions: `permission.updated`, `permission.replied`
- Tasks: `todo.updated` (with priority)
- Commands: `command.executed`
- Model/Config: `chat.params`, `config`, `experimental.session.compacting`

**Slash Commands:** `/recall <query>`, `/remember <text>`

[Source: OpenCode plugin.json](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/plugin.json), [OpenCode README](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/README.md)

### Comparison: Hermes vs OpenCode

| Dimension | Hermes | OpenCode |
|-----------|--------|----------|
| **Plugin Language** | Python | TypeScript |
| **Config Format** | YAML (`plugin.yaml` + `config.yaml`) | JSON (`opencode.json`) |
| **Hook Count** | 6 | 22 |
| **Context Injection** | Via Hermes memory provider API (`prefetch`, `system_prompt_block`) | Direct `output.system[]` via `experimental.chat.system.transform` |
| **File Enrichment** | Not specified | Two-layer pipeline (memory context + file enrichment) |
| **MEMORY.md Mirroring** | Yes (`on_memory_write`) | No (OpenCode uses AGENTS.md, not MEMORY.md) |
| **MCP Server** | Auto-wired via config.yaml | Manual MCP config in opencode.json |
| **Session Consolidation** | `on_session_end` + `on_pre_compress` | `session.deleted` + `experimental.session.compacting` |

**Key Finding:** Hermes uses a **memory provider interface** (6 hooks) that integrates with Hermes' internal memory system, while OpenCode uses a **capture plugin** (22 hooks) that directly injects into the system prompt via OpenCode's experimental transform hook. Both achieve the same goal — cross-session memory — but via different agent-specific extension points.

---

## 5. Gaps: Agents Without Native Plugins (Warp, Zed, etc.) — MCP-Only Behavior

### MCP-Only Agents
| Agent | Config Method | Capabilities | Limitations |
|-------|---------------|--------------|-------------|
| **Warp** | `agentmemory connect warp` → `~/.warp/.mcp.json` | 54 MCP tools, skills via `.claude/skills/` auto-discovery | No auto-capture hooks; no session lifecycle tracking; relies on manual `memory_save`/`memory_recall` |
| **Zed** | Manual MCP config (Zed v1.3.x and below) | 54 MCP tools | No native hooks; no skills auto-install (skills CLI doesn't cover Zed yet); no session capture |
| **Gemini CLI** | `gemini mcp add agentmemory npx -y @agentmemory/mcp --scope user` | 54 MCP tools | No native hooks; no auto-capture |
| **Claude Desktop** | Manual `claude_desktop_config.json` | 54 MCP tools | No hooks (Desktop doesn't support hooks); no skills |
| **Cline / Roo Code / Kilo Code** | Cline MCP settings UI | 54 MCP tools | No hooks; no skills |
| **Goose** | MCP config | 54 MCP tools | No hooks; no skills |
| **Aider** | REST API only (no MCP) | Direct REST calls | No MCP tools; no hooks; different auth model |

### What MCP-Only Loses vs Native Plugin

| Capability | Native Plugin (Claude/Codex/OpenCode/Hermes/pi/OpenClaw) | MCP-Only (Warp/Zed/Gemini/Claude Desktop/etc.) |
|------------|----------------------------------------------------------|------------------------------------------------|
| **Auto-capture on tool use** | Yes (PreToolUse/PostToolUse hooks) | No — manual `memory_save` only |
| **Session lifecycle tracking** | Yes (SessionStart, SessionEnd, Stop, PreCompact) | No — server sees no session boundaries |
| **Pre-LLM context injection** | Yes (prompt recall via hooks or provider) | No — must manually call `memory_recall` |
| **File enrichment** | Yes (OpenCode pipeline, Claude bridge) | No |
| **Compaction/pre-compress handling** | Yes (PreCompact/Stop hooks trigger summarization) | No — context lost on compaction |
| **Subagent/task tracking** | Yes (SubagentStart/Stop, TaskCompleted, todo.updated) | No |
| **Permission/approval capture** | Yes (permission.updated, Notification hooks) | No |
| **Real-time viewer sync** | Automatic (every hook posts to `/observe`) | Only manual saves appear |
| **Skills/Slash commands** | 17 skills + agent-specific slash commands | Skills only via `npx skills add` (if agent supports skills) |

### Warp Specifics
Warp gets **partial native integration** via skills:
- `agentmemory connect warp` writes MCP config
- Warp auto-discovers skills from `.claude/skills/` — so once Claude Code plugin is installed, the 8 agentmemory action skills (`remember`, `recall`, `recap`, `handoff`, `forget`, `commit-context`, `commit-history`, `session-history`) appear in Warp's slash palette
- But **no hooks** — Warp doesn't expose a hook system for plugins

[Source: Main README Warp section](https://github.com/rohitg00/agentmemory/blob/main/README.md)

### Zed Specifics
- Zed v1.3.x and below: **no native plugin support** — MCP-only
- Skills CLI doesn't cover Zed yet — manual skill file drop required
- No hook system exposed for extensions

### Mitigation for MCP-Only Agents
1. **Run `agentmemory connect <agent> --with-hooks`** where supported (Codex Desktop, Devin) — writes global hooks config
2. **Use `npx skills add rohitg00/agentmemory -y`** to install 17 skills so the agent knows when to call memory tools
3. **Manual workflow**: User must explicitly `/recall` at session start and `/remember` key facts
4. **Import transcripts**: `agentmemory import-jsonl` for agents that log JSONL (Claude Code)

**Key Finding:** MCP-only agents get **tool access (54 tools)** but **zero auto-capture**. They participate in cross-agent recall (can read memories written by native-plugin agents) but don't contribute automatic observations. The memory asymmetry means native-plugin agents build richer project memory over time.

---

## Summary: Cross-Agent Interoperability Verdict

| Question | Answer |
|----------|--------|
| **Do all 4 target agents have native plugins?** | Yes — Claude Code (12 hooks), Codex CLI (6 hooks), OpenCode (22 hooks), Hermes (6 hooks) |
| **Do they share the same memory server?** | Yes — all connect to `http://localhost:3111` via same MCP/REST endpoints |
| **Can Codex recall what Claude saved?** | Yes — project-scoped, no agentId filter, identical schema |
| **Is schema consistent?** | Yes — all hooks & MCP tools normalize to same REST API (`/observe`, `/remember`, `/smart-search`, `/context`, `/enrich`) |
| **What do MCP-only agents lose?** | Auto-capture, session tracking, pre-LLM injection, file enrichment, compaction handling — but retain full read/write via MCP tools |

**Architecture Principle:** agentmemory uses a **single shared server** with **project-scoped storage**. Native plugins provide **agent-specific capture fidelity**; MCP provides **universal tool access**. Cross-agent recall works by design — memories are not agent-isolated.