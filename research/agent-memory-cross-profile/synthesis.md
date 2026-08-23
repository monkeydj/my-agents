# Cross-Profile AgentMemory Synthesis

**Status: COMPLETE**

## 1. Executive Summary

- agentmemory achieves cross-profile isolation primarily through `AGENT_ID` + `AGENTMEMORY_AGENT_SCOPE=isolated` environment variables, NOT through `CLAUDE_CONFIG_DIR` directly (cross-profile-architecture.md:13-28)
- Each profile must run with a distinct `AGENT_ID` (e.g., `work`, `personal`, `client-x`) and isolated scope to prevent memory leakage; without explicit `AGENT_ID`, all profiles share the same memory bucket in legacy "shared" mode (cross-profile-architecture.md:28)
- Project attribution is based on session working directory (cwd), not config directory — both OpenCode plugin (per-session map) and Claude Code hooks (stateless per-event) resolve project identically via 3-tier: env override → git toplevel → cwd basename (cross-profile-architecture.md:67-91)
- JSONL transcript import derives project from each transcript's recorded `cwd` field, enabling multi-profile imports from custom `CLAUDE_CONFIG_DIR` paths, but imported sessions lack `agentId` and are filtered out in `isolated` mode unless wildcard `agentId: "*"` is used (cross-profile-architecture.md:102-125)
- Running multiple profiles requires multiple agentmemory server instances (`--instance N` or separate `--port` + `--data-dir`) for true isolation; single server shares memory across all profiles (cross-profile-architecture.md:134, 141-151)
- **All four target agents (Claude Code, Codex CLI, OpenCode, Hermes) have native plugins with lifecycle hooks** — not just MCP. Hook counts: OpenCode (22) > Claude Code (12) > Hermes (6) = Codex CLI (6). All share the same 54 MCP tools via `@agentmemory/mcp` (cross-agent-plugins.md:9-40)
- **Cross-agent recall works by default** — all agents use identical project resolution logic (env override → git toplevel → cwd basename) and write to the same REST endpoints with identical schema. No `agentId` filter exists in core recall; memories are pooled by project, not agent (cross-agent-plugins.md:102-128)
- **Native plugins provide auto-capture** (hooks for tool use, session lifecycle, pre-LLM injection, file enrichment, compaction handling); **MCP-only agents (Warp, Zed, Gemini CLI, etc.) get tool access but zero auto-capture** — they can read/write but don't contribute automatic observations (cross-agent-plugins.md:241-274)

## 2. Key Findings by Theme

### Profile Isolation Mechanism
- **AgentId + isolated scope** is the primary isolation mechanism, not CLAUDE_CONFIG_DIR (cross-profile-architecture.md:13-28)
- **Fail-closed behavior**: isolated mode without resolved agentId throws error rather than leaking data (cross-profile-architecture.md:17)
- **Multiple server instances required** for true multi-profile isolation (--instance N or separate ports/data dirs) (cross-profile-architecture.md:134, 141-151)
- **Provenance channels** tag every record (user/agent/tool/import/shared) enabling filtered views (cross-profile-architecture.md:34-61)

### Project Attribution & Session Mapping
- **Identical 3-tier project resolution** across all agents: AGENTMEMORY_PROJECT_NAME env → git toplevel basename → cwd basename (cross-profile-architecture.md:20-23, 82-91; cross-agent-plugins.md:105-110)
- **OpenCode**: per-session project map keyed by sessionId, resolved at session.created, pruned on session.deleted (cross-profile-architecture.md:67-80)
- **Claude Code**: stateless per-hook resolution from payload cwd/workspace_roots (cross-profile-architecture.md:82-86)
- **Hermes**: resolves via Python plugin reading AGENTMEMORY_URL/SECRET from ~/.agentmemory/.env (cross-agent-plugins.md:163-167)

### Session Import/Replay (JSONL)
- **import-jsonl** discovers JSONL under ~/.claude/projects (or custom path), derives project from transcript's cwd field (cross-profile-architecture.md:97-108)
- **Deduplication**: content-addressed IDs for crystals/lessons — re-import upserts (cross-profile-architecture.md:113)
- **Imported sessions lack agentId** — invisible in isolated mode unless agentId: "*" wildcard used (cross-profile-architecture.md:124)
- **Claude Code cleanupPeriodDays (default 30)** auto-deletes source JSONL — historical import limited to last 30 days (cross-profile-architecture.md:122-123)

### Limitations & Gaps
- **No automatic AGENT_ID derivation from CLAUDE_CONFIG_DIR** — manual env management required (cross-profile-architecture.md:132)
- **No per-profile viewer separation** — single viewer shows all agents' memories mixed (cross-profile-architecture.md:135)
- **Hook scripts embed versioned paths** — upgrade breaks hooks until re-run (cross-profile-architecture.md:136)
- **No built-in profile switcher** — could script wrapper (cross-profile-architecture.md:138)
- **MCP-only agents lose auto-capture, session tracking, pre-LLM injection, file enrichment, compaction handling** (cross-agent-plugins.md:241-253)

## 3. Cross-Profile Verdict: Does agentmemory solve the CLAUDE_CONFIG_DIR isolation?

**Partial Yes — but requires explicit opt-in and multi-instance deployment.**

- **agentmemory does NOT automatically derive isolation from CLAUDE_CONFIG_DIR** (cross-profile-architecture.md:132). The config dir only affects where Claude Code writes JSONL transcripts; agentmemory's project attribution uses the session's cwd, not the config dir (cross-profile-architecture.md:26).
- **True isolation requires**: distinct `AGENT_ID` per profile + `AGENTMEMORY_AGENT_SCOPE=isolated` + separate agentmemory server instances (separate `--data-dir` and `--port`/`--instance N`) (cross-profile-architecture.md:141-151).
- **Without explicit AGENT_ID**: all profiles share the same memory bucket (legacy "shared" mode) (cross-profile-architecture.md:28).
- **Imported JSONL sessions lack agentId** — they become invisible in `isolated` mode unless `agentId: "*"` wildcard is used (cross-profile-architecture.md:124).
- **Viewer shows all profiles mixed** — no per-profile viewer separation (cross-profile-architecture.md:135).

**Verdict**: agentmemory *can* solve CLAUDE_CONFIG_DIR isolation, but it's not automatic. You must manually orchestrate: separate AGENT_ID env vars, isolated scope, multiple server instances with separate data dirs, and explicit import paths per profile.

## 4. Cross-Agent Verdict: Can Claude Code, OpenCode, Codex CLI, Hermes share memory?

**Yes — by design, they share memory at the project level.**

- **All four have native plugins** with lifecycle hooks: OpenCode (22), Claude Code (12), Hermes (6), Codex CLI (6) (cross-agent-plugins.md:9-40).
- **All write to the same REST endpoints** (`/observe`, `/remember`, `/smart-search`, `/context`, `/enrich`, `/session/start`, `/session/end`, `/summarize`) with identical schema (sessionId, project, cwd, hookType, data, timestamp) (cross-agent-plugins.md:76-93).
- **Project resolution is identical across agents**: AGENTMEMORY_PROJECT_NAME env → git toplevel basename → cwd basename (cross-agent-plugins.md:105-110).
- **No agentId filter in core recall** — memories are pooled by project, not by agent. A memory saved by Claude's PostToolUse hook is indistinguishable from one saved by Codex's PostToolUse hook (cross-agent-plugins.md:112-119).
- **README explicitly confirms**: "Cross-agent: memories from Claude Code, Cursor, Gemini CLI all accessible" and "One local agentmemory server can be shared across pi, pi2, Hermes, OpenClaw, Claude Code, Codex CLI, and Gemini CLI" (cross-agent-plugins.md:121).
- **Consolidation merges cross-agent sessions** into project-level crystals server-side on session/end (cross-agent-plugins.md:126).

**Verdict**: Full cross-agent memory sharing works out of the box. The system is designed for **shared team memory**, not agent-isolated memory. All agents in the same git repo write to the same project bucket and can recall each other's memories.

## 5. Mesh Federation Verdict: Can it bridge profiles/machines?

**Yes — mesh federation can bridge separate agentmemory instances across machines, with caveats.**

- **Peer-to-peer sync over authenticated HTTPS** with Bearer token auth (AGENTMEMORY_SECRET required on both peers) (mesh-federation.md:12-20, 75-76).
- **Explicit peer registration** via `POST /agentmemory/mesh/peers` — no silent/automatic syncs (mesh-federation.md:72-73).
- **Three sync modes**: push, pull, both (bidirectional) via `mem::mesh-sync` (mesh-federation.md:22-27).
- **Syncs full memory graph**: memories, actions, semantic, procedural, relations, graphNodes, graphEdges (mesh-federation.md:36-43).
- **Delta sync** using `lastSyncAt` timestamp — only fetches changes since last successful sync (mesh-federation.md:46).
- **Conflict resolution**: Last-Write-Wins (LWW) based on updatedAt/createdAt timestamps (mesh-federation.md:52-53).
- **Provenance tracking**: each record carries Origin block (channel: user/agent/tool/import/shared) for data lineage (mesh-federation.md:55-56).
- **Security**: SSRF protection (no embedded creds, URL validation), private IP blocking (blocks loopback, 10.x, 192.168.x, 172.16.x ranges) (mesh-federation.md:15-19, 78-81).
- **Single-process architecture**: state on disk as JSON, Docker-supported (mesh-federation.md:62-67).

**Caveats for cross-profile/machine bridging**:
- **Private IP blocking means peers must be publicly reachable or on allowed networks** — cannot sync directly between localhost instances on different machines without tunneling/VPN (mesh-federation.md:18).
- **LWW conflict resolution** may lose data if simultaneous edits occur on different peers (mesh-federation.md:53).
- **No project/agentId filtering on sync** — appears to sync entire memory graph (mesh-federation.md:36-43).
- **No automatic conflict merge** for structured data (crystals, lessons) — purely timestamp-based.

**Verdict**: Mesh federation works for bridging profiles/machines but requires: public HTTPS endpoints (or VPN/tunnel), explicit peer config, shared secret, and acceptance of LWW conflicts. It syncs the full memory graph without project-level filtering.

## 6. Practical Setup for Your Stack (ccli lifanuke + default claude + opencode + codex + hermes)

### Single Shared Server (Recommended)

Run one agentmemory server on port 3111 serving all agents simultaneously (practical-integration.md:36-62):
```bash
# Start single server
npx @agentmemory/agentmemory
# REST: http://localhost:3111, Viewer: http://localhost:3113
```

### Universal MCP Config (same for all agents)

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
(practical-integration.md:66-83)

### Per-Agent Config & AGENT_ID Injection

| Agent | Config File | AGENT_ID Setup |
|-------|-------------|----------------|
| **ccli (lifanuke)** | `~/.another-claudes/lifanuke/settings.json` (via `CLAUDE_CONFIG_DIR`) | `AGENT_ID=lifanuke` in shell env or `~/.agentmemory/.env` |
| **default claude** | `~/.claude/settings.json` | `AGENT_ID=default-claude` in shell env |
| **OpenCode** | `~/.config/opencode/opencode.json` | `AGENT_ID=opencode` in shell env (plugin reads process env) |
| **Codex CLI** | `~/.codex/config.toml` | `AGENT_ID=codex` in shell env (6 hooks via plugin) |
| **Hermes** | `~/.hermes/config.yaml` | `AGENT_ID=hermes` in shell env; reads `AGENTMEMORY_URL/SECRET` from `~/.agentmemory/.env` at import time |

(practical-integration.md:85-94)

### Agent-Specific MCP Config Shapes

**OpenCode** (`~/.config/opencode/opencode.json`):
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
(practical-integration.md:97-109)

**Codex CLI** (`~/.codex/config.toml`):
```toml
[mcp_servers.agentmemory]
command = "npx"
args = ["-y", "@agentmemory/mcp"]
env = { AGENTMEMORY_URL = "http://localhost:3111" }
```
(practical-integration.md:111-117)

**Hermes** (`~/.hermes/config.yaml`):
```yaml
mcp_servers:
  agentmemory:
    command: npx
    args: ["-y", "@agentmemory/mcp"]
memory:
  provider: agentmemory
```
(practical-integration.md:119-127)

### Environment Variable Strategy

**Shared config** (`~/.agentmemory/.env`):
```bash
AGENTMEMORY_URL=http://localhost:3111
AGENTMEMORY_SECRET=your-secret-if-needed
AGENTMEMORY_AGENT_SCOPE=isolated
```
(practical-integration.md:130-135)

**Per-agent launch**:
```bash
# ccli lifanuke
AGENT_ID=lifanuke ccli ...

# default claude
AGENT_ID=default-claude claude ...

# OpenCode
AGENT_ID=opencode opencode ...

# Codex CLI
AGENT_ID=codex codex ...

# Hermes
AGENT_ID=hermes hermes ...
```
(practical-integration.md:136-141)

### Cross-Profile Isolation (if needed)

If you need separate memory buckets per profile (e.g., work vs personal), run multiple instances:
```bash
# Instance 1: Work profile
AGENT_ID=work AGENTMEMORY_AGENT_SCOPE=isolated AGENTMEMORY_DATA_DIR=~/.agentmemory-work npx @agentmemory/agentmemory --instance 1

# Instance 2: Personal profile  
AGENT_ID=personal AGENTMEMORY_AGENT_SCOPE=isolated AGENTMEMORY_DATA_DIR=~/.agentmemory-personal npx @agentmemory/agentmemory --instance 2
```
Each gets isolated memory, separate data dirs, separate ports (3111/3211/3311...) (cross-profile-architecture.md:141-151).

### Memory Lifecycle & Consolidation

**Auto-capture hooks**: All four agents have native plugins with hooks (practical-integration.md:150-171):
- Claude Code: 12 hooks (SessionStart, UserPromptSubmit, Pre/PostToolUse, PreCompact, Stop, SessionEnd, Notification, SubagentStop, TaskCompleted, PostToolUseFailure, SubagentStart)
- Codex CLI: 6 hooks (SessionStart, UserPromptSubmit, Pre/PostToolUse, PreCompact, Stop)
- OpenCode: 22 hooks (session lifecycle, messages, tools, errors, file enrichment, permissions, tasks, model config) — two-layer injection pipeline
- Hermes: 6 hooks (prefetch, sync_turn, on_session_end, on_pre_compress, on_memory_write, system_prompt_block)

**4-tier consolidation** (runs on session end + nightly cron):
1. Raw observations → compressed observations (LLM summarization)
2. Compressed observations → session crystals (key facts, decisions, patterns)
3. Crystals → lessons (generalizable insights)
4. Lessons → knowledge graph entities/relations (practical-integration.md:174-178)

**LLM key required** for consolidation/crystals/lessons/graph; keyless mode uses synthetic BM25 only (practical-integration.md:197-200).

### Token Costs

- **Capture/recall**: Work without LLM key (BM25 + vector search)
- **Consolidation/crystals/lessons/graph**: Need LLM provider configured (OpenAI, Anthropic, etc.) — token cost depends on session volume and compression budget (default 2000 tokens) (practical-integration.md:185-195)

### Operational Gotchas

- **Viewer port conflicts**: Single viewer at :3113 shows all agents mixed; use `agentId` filter in UI or run separate instances (cross-profile-architecture.md:135)
- **Index flush on stop**: Worker stops first (5s SIGTERM grace for index flush), then engine — prevents data loss (practical-integration.md:210-213)
- **Docker vs bare**: CLI reaps native worker before Docker teardown; use `--force` for Docker/VM port holders (practical-integration.md:213)
- **Hook version paths**: `agentmemory connect <agent> --with-hooks` writes absolute versioned paths — re-run after upgrade (cross-profile-architecture.md:136)
- **Codex Desktop hooks silent**: Issue openai/codex#16430; workaround: `agentmemory connect codex --with-hooks` (practical-integration.md:158)
- **MCP-only agents** (Warp, Zed, Gemini CLI): Get 54 tools but zero auto-capture — manual `/recall` and `/remember` only (cross-agent-plugins.md:241-253)

## 7. Contradictions or Tensions Found Across Agents

### Tension 1: Cross-Profile Isolation vs. Cross-Agent Sharing

**Contradiction**: 
- Cross-profile architecture **requires** `AGENTMEMORY_AGENT_SCOPE=isolated` + distinct `AGENT_ID` per profile to prevent leakage (cross-profile-architecture.md:28, 141-151)
- Cross-agent plugins document that **no `agentId` filter exists in core recall** — memories are pooled by project, not agent, and this is "a feature, not a bug" (cross-agent-plugins.md:112-128)

**Implication**: You cannot simultaneously have:
- Profile isolation (work vs personal memories separate)
- Cross-agent sharing (Claude, OpenCode, Codex, Hermes all seeing same project memories)

Unless you run **separate agentmemory instances per profile** (each with its own port/data dir), with agents connecting to the instance matching their profile. Single shared server forces a choice: isolated agents (no cross-agent sharing) or shared agents (no cross-profile isolation).

### Tension 2: Imported JSONL Sessions vs. Isolated Mode

**Contradiction**:
- Imported JSONL sessions **lack `agentId`** and are "filtered out in `isolated` mode unless `agentId: '*'` wildcard is used" (cross-profile-architecture.md:124)
- But `agentId: "*"` wildcard defeats the purpose of isolated mode (shows all agents' data)

**Implication**: Historical transcript import doesn't work cleanly with profile isolation. Imported sessions become invisible to isolated agents.

### Tension 3: Mesh Federation Sync Scope vs. Profile Isolation

**Tension**:
- Mesh syncs **full memory graph** (memories, actions, semantic, procedural, relations, graphNodes, graphEdges) with **no project/agentId filtering** (mesh-federation.md:36-43)
- If you run separate agentmemory instances per profile for isolation, mesh federation would sync **all profiles' data** between machines, defeating isolation

**Implication**: Mesh federation is designed for team collaboration (syncing full project memory), not for multi-profile personal use where profiles must stay separate.

### Tension 4: Single Server vs. Multiple Profiles

**Tension**:
- Practical integration recommends **single server on :3111** for all agents (practical-integration.md:36-62)
- Cross-profile architecture says **multiple instances required** for true multi-profile isolation (cross-profile-architecture.md:134, 141-151)

**Resolution**: Single server works if you accept shared project memory across agents. Multiple instances needed only if you need hard isolation between profiles (work vs personal).

### Tension 5: Hermes MEMORY.md Mirroring vs. OpenCode AGENTS.md

**Difference**:
- Hermes plugin mirrors `MEMORY.md` writes to agentmemory via `on_memory_write` hook (cross-agent-plugins.md:220)
- OpenCode uses `AGENTS.md` (not MEMORY.md) and has no equivalent mirroring hook (cross-agent-plugins.md:220)

**Implication**: Asymmetric memory persistence — Hermes agents can sync their explicit MEMORY.md notes to agentmemory; OpenCode agents cannot (unless they use `/remember` slash command).

## 8. Confidence Assessment (well-supported vs. needs validation)

### Well-Supported (High Confidence)

| Claim | Source |
|-------|--------|
| agentmemory uses `AGENT_ID` + `AGENTMEMORY_AGENT_SCOPE=isolated` for profile isolation | cross-profile-architecture.md:13-28 |
| Project resolution identical across agents (env → git toplevel → cwd) | cross-profile-architecture.md:20-23, 82-91; cross-agent-plugins.md:105-110 |
| All 4 target agents have native plugins with hooks | cross-agent-plugins.md:9-40 |
| All agents write to same REST endpoints with identical schema | cross-agent-plugins.md:76-93 |
| Cross-agent recall works by default (project-scoped, no agentId filter) | cross-agent-plugins.md:102-128 |
| MCP-only agents get tools but zero auto-capture | cross-agent-plugins.md:241-253 |
| Mesh federation: P2P sync over HTTPS, Bearer auth, explicit peers | mesh-federation.md:12-20, 72-76 |
| Mesh syncs full memory graph, delta sync, LWW conflict resolution | mesh-federation.md:22-56 |
| Single server on :3111 is intended pattern | practical-integration.md:36-62 |
| Per-agent AGENT_ID injection via shell env | practical-integration.md:85-141 |
| 4-tier consolidation pipeline (observations → crystals → lessons → graph) | practical-integration.md:174-178 |
| Index persistence: sharded BM25/vector with manifest commit/rollback | practical-integration.md:210-211 |
| Stop order fixed: worker first (5s grace), then engine | practical-integration.md:211-212 |

### Needs Validation (Medium/Low Confidence)

| Claim | Gap |
|-------|-----|
| **Mesh federation sync scope**: "No project/agentId filtering on sync" — not explicitly confirmed in sources; mesh-federation.md:36-43 lists synced types but doesn't specify filtering | Need to verify if mesh sync can be scoped to project/agentId |
| **LWW conflict resolution behavior** for structured data (crystals, lessons) — purely timestamp-based may lose semantic merges | mesh-federation.md:52-53 only mentions timestamps |
| **Token cost estimates** for consolidation — practical-integration.md:217 notes "To be filled by research agent" | No concrete numbers available |
| **Codex Desktop hooks silent** — issue openai/codex#16430 status unknown | practical-integration.md:158 references open issue |
| **Hermes MEMORY.md mirroring** vs agentmemory — does it create duplicate entries? | cross-agent-plugins.md:220 mentions mirroring but not deduplication |
| **Viewer per-profile separation** — "could script wrapper" but no implementation exists | cross-profile-architecture.md:138 |
| **Automatic AGENT_ID derivation from CLAUDE_CONFIG_DIR** — explicitly noted as gap | cross-profile-architecture.md:132 |

## 9. Recommended Next Steps

### Immediate (Setup)
1. **Start single agentmemory server**: `npx @agentmemory/agentmemory` on port 3111
2. **Create shared `~/.agentmemory/.env`** with `AGENTMEMORY_URL`, `AGENTMEMORY_SECRET`, `AGENTMEMORY_AGENT_SCOPE=isolated`
3. **Configure each agent** with universal MCP block + per-agent `AGENT_ID` in launch env
4. **Install native plugins**:
   - Claude Code: `npx @agentmemory/agentmemory connect claude-code --with-hooks`
   - OpenCode: Add plugin to `~/.config/opencode/opencode.json`
   - Codex CLI: Install plugin + configure `config.toml`
   - Hermes: Copy `integrations/hermes` to `~/.hermes/plugins/agentmemory` + config.yaml

### Validation (Test Cross-Agent Recall)
5. **Verify cross-agent recall**: Have Claude Code save a memory via `/remember`, then query from OpenCode via `/recall` — confirm project-scoped sharing works
6. **Test isolated mode**: Set `AGENTMEMORY_AGENT_SCOPE=isolated`, verify each agent only sees its own `agentId` memories
7. **Test JSONL import**: Run `npx @agentmemory/agentmemory import-jsonl ~/.claude/projects` for each profile's config dir

### Profile Isolation (If Needed)
8. **If work/personal isolation required**: Spin up second instance with `--instance 2`, separate `AGENTMEMORY_DATA_DIR`, connect work-profile agents to instance 1, personal-profile agents to instance 2
9. **Script profile switcher**: Create wrapper `agentmemory-profile <name>` that sets `AGENT_ID`, `AGENTMEMORY_DATA_DIR`, and launches correct instance

### Mesh Federation (If Multi-Machine)
10. **Set up HTTPS endpoints** for each machine (required by mesh — private IPs blocked)
11. **Configure shared `AGENTMEMORY_SECRET`** on all peers
12. **Register peers**: `POST /agentmemory/mesh/peers` with name + URL
13. **Test sync**: Run `mem::mesh-sync` push/pull/both, verify delta sync and LWW behavior

### Operational Hardening
14. **Configure LLM provider** in `~/.agentmemory/.env` for consolidation (OPENAI_API_KEY, ANTHROPIC_API_KEY, etc.)
15. **Set up cron** for nightly consolidation/decay/snapshots (`iii-cron` worker)
16. **Monitor viewer** at :3113 for memory health, use `agentId` filter for per-agent views
17. **Backup strategy**: Sharded index manifest + JSONL export via `/agentmemory/export`

### Advanced
18. **Graphify integration**: Import structural code graph via `POST /agentmemory/graph/import-graphify`
19. **Skills installation**: `npx skills add rohitg00/agentmemory -y` for 17 action skills (remember, recall, recap, handoff, etc.)
20. **Custom consolidation prompts**: Override default prompts via `~/.agentmemory/prompts/` for domain-specific crystal/lesson extraction

---

**Status: COMPLETE**