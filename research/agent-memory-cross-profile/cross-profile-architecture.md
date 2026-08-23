# Cross-Profile Architecture Research: agentmemory

**Status: COMPLETE**

**Research Question:** How does agentmemory handle cross-profile session isolation, project attribution, and memory scoping when multiple Claude Code instances run with different CLAUDE_CONFIG_DIR values?

---

## 1. Profile Isolation Mechanism — How CLAUDE_CONFIG_DIR Maps to agentmemory Projects/Sessions

agentmemory does **not** directly read or depend on `CLAUDE_CONFIG_DIR`. Instead, it isolates profiles through a combination of:

### A. Agent ID Scoping (`AGENT_ID` + `AGENTMEMORY_AGENT_SCOPE=isolated`)
The primary cross-profile isolation mechanism is the `AGENT_ID` environment variable paired with `AGENTMEMORY_AGENT_SCOPE=isolated` [config.ts:357-377](https://github.com/rohitg00/agentmemory/blob/main/src/config.ts#L357-L377). When set:
- Every observation, memory, and session is tagged with `agentId` at capture time [observe.ts:194-199](https://github.com/rohitg00/agentmemory/blob/main/src/functions/observe.ts#L194-L199), [remember.ts:154-160](https://github.com/rohitg00/agentmemory/blob/main/src/functions/remember.ts#L154-L160)
- Recall paths (`mem::search`, `mem::smart-search`, `mem::context`, `/agentmemory/search`, `/agentmemory/smart-search`, `/agentmemory/context`) filter by `agentId` [context.ts:46-62](https://github.com/rohitg00/agentmemory/blob/main/src/functions/context.ts#L46-L62), [search.ts:230-240](https://github.com/rohitg00/agentmemory/blob/main/src/functions/search.ts#L230-L240)
- Fail-closed behavior: if `isolated` mode is enabled but no `agentId` resolves (env unset, no explicit `agentId` in call), the request throws rather than leaking cross-agent data [context.ts:58-62](https://github.com/rohitg00/agentmemory/blob/main/src/functions/context.ts#L58-L62), [CHANGELOG.md:0.9.28](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md#security-1)

### B. Per-Session Project Attribution
Each session is attributed to a project at `session.created` (OpenCode) or `SessionStart` hook (Claude Code). The project name is resolved from:
1. `AGENTMEMORY_PROJECT_NAME` env override
2. Git toplevel basename (repo name)
3. CWD basename (fallback) [session-start.mjs:16-27](https://github.com/rohitg00/agentmemory/blob/main/plugin/scripts/session-start.mjs#L16-L27), [agentmemory-capture.ts:80-105](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/agentmemory-capture.ts#L80-L105)

### C. CLAUDE_CONFIG_DIR Relationship
Claude Code stores JSONL transcripts under `~/.claude/projects/<slug>/` where `<slug>` is derived from the project path. When `CLAUDE_CONFIG_DIR` changes, the transcript location changes, but **agentmemory's project attribution is based on the session's working directory (cwd), not the config dir**. The `import-jsonl` command discovers JSONL files under a given path (default `~/.claude/projects`) and derives project from each file's recorded `cwd` field [replay.ts:204-220](https://github.com/rohitg00/agentmemory/blob/main/src/functions/replay.ts#L204-L220), [jsonl-parser.ts:43-70](https://github.com/rohitg00/agentmemory/blob/main/src/replay/jsonl-parser.ts#L43-L70).

**Key insight**: Multiple Claude Code profiles with different `CLAUDE_CONFIG_DIR` values will naturally isolate in agentmemory **if** each profile runs with a distinct `AGENT_ID` and `AGENTMEMORY_AGENT_SCOPE=isolated`. Without explicit `AGENT_ID`, all profiles share the same memory bucket (legacy "shared" mode).

---

## 2. agentId Provenance Channel — Scoping Memories Per Agent/Profile

agentmemory implements a **write-time provenance block** on every record (observation, memory, lesson, crystal) introduced in v0.9.29 [CHANGELOG.md:0.9.29](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md#added-2). The provenance structure:

```typescript
origin: {
  channel: "user" | "agent" | "tool" | "import" | "shared",
  detail?: string,           // e.g., tool name for tool-channel observations
  capturedAt: string         // ISO timestamp
}
```

### AgentId Threading Through All Save Paths
Fixed in v0.9.29 [CHANGELOG.md:0.9.29](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md#fixed-3):
- **REST `/agentmemory/remember`**: forwards `agentId` instead of dropping it
- **`memoryToObservation()`**: carries the memory's `agentId` into the search-index shape so saved memories are visible to agent-scoped search
- **MCP `memory_save`**: schema exposes `agentId`; stdio package forwards both `agentId` and `project`
- **Observations**: inherit `agentId` from the session record at first observation [observe.ts:194-199](https://github.com/rohitg00/agentmemory/blob/main/src/functions/observe.ts#L194-L199)
- **Memories**: request body `agentId` wins; falls back to env `AGENT_ID`; none → unscoped (legacy) [remember.ts:154-160](https://github.com/rohitg00/agentmemory/blob/main/src/functions/remember.ts#L154-L160)

### Provenance Channels
| Channel | Source | Typical Use |
|---------|--------|-------------|
| `user` | `prompt_submit` hook | User prompts |
| `agent` | `memory_save` / `remember` skill | Explicit agent memories |
| `tool` | `pre_tool_use`, `post_tool_use`, `post_tool_failure` | Tool executions |
| `import` | `import-jsonl` / JSONL replay | Historical transcript ingestion |
| `shared` | Cross-agent consolidation | Team-shared lessons |

The `detail` field captures the tool name for tool-channel observations, enabling filtering like "show me all `Edit` tool observations from agent X" [observe.ts:65-75](https://github.com/rohitg00/agentmemory/blob/main/src/functions/observe.ts#L65-L75).

---

## 3. Project Attribution — OpenCode Plugin's Per-Session Project Mapping; Does Claude Code Plugin Do Similar?

### OpenCode Plugin: Per-Session Project Attribution (v0.9.29+)
**Yes, fully implemented.** The OpenCode plugin maintains a `sessionProjects` map keyed by `sessionId`, resolved at `session.created` from each session's own directory [agentmemory-capture.ts:49-55](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/agentmemory-capture.ts#L49-L55), [CHANGELOG.md:0.9.29](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md#fixed-2):
```typescript
const sessionProjects = new Map<string, { name: string; cwd: string }>();

function projectFor(sessionId: string): { name: string | null; cwd: string | null } {
  const p = sessionProjects.get(sessionId);
  return p ?? { name: defaultProjectName, cwd: defaultProjectCwd };
}
```
- Module-level `defaultProjectName`/`defaultProjectCwd` are only fallbacks for events before any session is created
- `sessionProjects` entries are pruned on `session.deleted` [agentmemory-capture.ts:78-81](https://github.com/rohitg00/agentmemory/blob/main/plugin/opencode/agentmemory-capture.ts#L78-L81)
- Fixes the prior bug where a long-lived OpenCode process serving multiple directories filed every session under whichever repo loaded the plugin first [CHANGELOG.md:0.9.29](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md#fixed-2)

### Claude Code Plugin: Per-Session Project Attribution
**Yes, via hooks.** Each hook script (`session-start.mjs`, `session-end.mjs`, etc.) independently resolves project from the hook payload's `cwd` or `workspace_roots` [session-start.mjs:16-27](https://github.com/rohitg00/agentmemory/blob/main/plugin/scripts/session-start.mjs#L16-L27), [session-end.mjs:16-27](https://github.com/rohitg00/agentmemory/blob/main/plugin/scripts/session-end.mjs#L16-L27):
- `hookCwd(data)` extracts cwd from payload → `workspace_roots` → `CLAUDE_PROJECT_DIR` env
- `resolveProject(cwd)` applies the same 3-tier resolution (env override → git toplevel → cwd basename)
- No module-level state; each hook invocation is stateless and resolves project from the current event's context

### Project-Scope Parity (v0.9.29)
All capture surfaces now resolve `project` identically [CHANGELOG.md:0.9.29](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md#fixed-2):
- OpenCode plugin, Hermes plugin, Pi extension, JSONL replay → same resolution order
- `AGENTMEMORY_PROJECT_NAME` env override respected everywhere (with deprecated `AGENTMEMORY_PROJECT` alias)
- Windows-recorded paths handled in replay [jsonl-parser.ts:65-70](https://github.com/rohitg00/agentmemory/blob/main/src/replay/jsonl-parser.ts#L65-L70)

---

## 4. Session Import/Replay — JSONL Transcript Ingestion Across Profiles

### `import-jsonl` Command (CLI)
- Entry point: `npx @agentmemory/agentmemory import-jsonl [path]` [README.md](https://github.com/rohitg00/agentmemory/blob/main/README.md#session-replay)
- Default path: `~/.claude/projects` (Claude Code's default transcript directory)
- Accepts a single `.jsonl` file or directory (recursively walks, capped at 200 files default, 1000 max) [replay.ts:170-210](https://github.com/rohitg00/agentmemory/blob/main/src/functions/replay.ts#L170-L210)

### JSONL Parsing & Project Derivation
Each `.jsonl` file is parsed by `parseJsonlText()` [jsonl-parser.ts:110-212](https://github.com/rohitg00/agentmemory/blob/main/src/replay/jsonl-parser.ts#L110-L212):
- Extracts `sessionId`, `cwd`, timestamps from transcript entries
- Derives project from the transcript's recorded `cwd` using `deriveProject(cwd)`:
  - If `cwd` exists on disk: `git rev-parse --show-toplevel` → basename
  - Fallback: basename of `cwd` (handles Windows-recorded paths with both `/` and `\` separators) [jsonl-parser.ts:43-70](https://github.com/rohitg00/agentmemory/blob/main/src/replay/jsonl-parser.ts#L43-L70)
- **No `AGENTMEMORY_PROJECT_NAME` override during bulk import** — a global name would mislabel multi-project imports [jsonl-parser.ts:50-52](https://github.com/rohitg00/agentmemory/blob/main/src/replay/jsonl-parser.ts#L50-L52)

### Import Behavior
- Creates/updates `Session` records with `tags: ["jsonl-import"]` [replay.ts:300-320](https://github.com/rohitg00/agentmemory/blob/main/src/functions/replay.ts#L300-L320)
- Observations stamped with `origin: { channel: "import", capturedAt: ... }` [replay.ts:325](https://github.com/rohitg00/agentmemory/blob/main/src/functions/replay.ts#L325)
- **Deduplication**: Content-addressed IDs for crystals (`fingerprintId("crystal", sessionId)`) and lessons (`fingerprintId("lesson", content)`) — re-importing the same JSONL upserts instead of duplicating [replay.ts:110-145](https://github.com/rohitg00/agentmemory/blob/main/src/functions/replay.ts#L110-L145)
- **Indexing**: Imported observations are indexed into BM25 and vector index (fixed in v0.9.29) so imports are searchable [CHANGELOG.md:0.9.29](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md#fixed-3)

### Replay/Viewer Integration
- `mem::replay::load` — loads timeline for a session ID
- `mem::replay::sessions` — lists all sessions (imported + native) sorted by `startedAt` desc
- Imported sessions appear in the Viewer's **Replay** tab alongside native sessions [README.md](https://github.com/rohitg00/agentmemory/blob/main/README.md#session-replay)

### Cross-Profile Import Caveats
1. **Claude Code's `cleanupPeriodDays`** (default 30) auto-deletes JSONL transcripts older than 30 days from `~/.claude/projects/` [README.md](https://github.com/rohitg00/agentmemory/blob/main/README.md#session-replay). Fresh agentmemory install on months-old history loses data beyond the window.
2. **Profile-specific config dirs**: If using `CLAUDE_CONFIG_DIR=/custom/path`, transcripts live at `/custom/path/projects/`. Must pass explicit path to `import-jsonl`.
3. **AgentId on import**: Imported sessions **do not** receive an `agentId` unless the import caller explicitly provides one. They remain unscoped (legacy) and visible to all agents in `shared` mode, but **filtered out in `isolated` mode** unless `agentId: "*"` wildcard is used.

---

## 5. Limitations/Gaps for Cross-Profile Use Cases

| Gap | Impact | Workaround / Status |
|-----|--------|---------------------|
| **No automatic `AGENT_ID` derivation from `CLAUDE_CONFIG_DIR`** | User must manually set `AGENT_ID=profile-name` per profile | Documented pattern: `AGENT_ID=work AGENTMEMORY_AGENT_SCOPE=isolated npx @agentmemory/agentmemory` per profile |
| **Imported JSONL sessions lack `agentId`** | In `isolated` mode, imported sessions are invisible to all agents (fail-closed) | Re-import with explicit `agentId` via REST API; or use `agentId: "*"` wildcard for reads |
| **Single server, multiple profiles** | All profiles share one agentmemory server instance (port 3111) | Run multiple agentmemory instances with `--instance N` (v0.9.27+) or `--port` + `--data-dir` for full isolation [CHANGELOG.md:0.9.27](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md#fixed-3) |
| **No per-profile viewer separation** | Viewer at `:3113` shows all agents' memories mixed (filtered only by `agentId` in API calls) | Use `agentId` filter in viewer UI; or run separate viewer per instance |
| **Claude Code hook scripts embed versioned paths** | `agentmemory connect claude-code --with-hooks` writes absolute paths like `~/.codex/plugins/cache/agentmemory/.../0.9.22/scripts/...` — upgrade breaks hooks until re-run | Re-run `agentmemory connect claude-code --with-hooks` after upgrade [README.md](https://github.com/rohitg00/agentmemory/blob/main/README.md#claude-code-without-the-plugin-install-mcp-standalone-path) |
| **`cleanupPeriodDays` deletes source JSONL** | Historical import limited to last 30 days by default | Raise `cleanupPeriodDays` in `~/.claude/settings.json`; cron `import-jsonl`; or use hook-based capture (live) |
| **No built-in profile switcher** | No CLI command to list/switch `AGENT_ID` profiles | Manual env management; could script `agentmemory profile <name>` wrapper |
| **Cross-agent memory sharing opt-in only** | `AGENTMEMORY_AGENT_SCOPE=shared` (default) merges all agents; `isolated` requires explicit `AGENT_ID` | Team workflows must coordinate `AGENT_ID` values; no discovery mechanism |

### Recommended Cross-Profile Setup
```bash
# Profile 1: Work projects
AGENT_ID=work AGENTMEMORY_AGENT_SCOPE=isolated AGENTMEMORY_DATA_DIR=~/.agentmemory-work npx @agentmemory/agentmemory --instance 1

# Profile 2: Personal projects  
AGENT_ID=personal AGENTMEMORY_AGENT_SCOPE=isolated AGENTMEMORY_DATA_DIR=~/.agentmemory-personal npx @agentmemory/agentmemory --instance 2

# Profile 3: Client X
AGENT_ID=client-x AGENTMEMORY_AGENT_SCOPE=isolated AGENTMEMORY_DATA_DIR=~/.agentmemory-client-x npx @agentmemory/agentmemory --instance 3
```
Each gets isolated memory, separate data dirs, separate ports (3111/3211/3311...), and can import their own `CLAUDE_CONFIG_DIR` transcripts via `import-jsonl /path/to/claude/projects`.