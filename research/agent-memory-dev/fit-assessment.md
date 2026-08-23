# Agent 2: Fit Assessment — agent-memory.dev vs. Claude Code cross-profile messaging gap

**Status:** COMPLETE
**Last updated:** 2026-08-21

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

## 1. The gap, restated

Claude Code (Anthropic's CLI) has a built-in "cross-session messaging" feature: one running `claude` process can discover and message another running `claude` process on the same machine, via the `ListAgents` / `SendMessage` tools and the `/list-agents` command. This discovery works by each session reading a local registry of JSON files under `<CLAUDE_CONFIG_DIR>/sessions/*.json` (e.g. `~/.claude/sessions/*.json`). The actual message-passing itself happens over shared, profile-agnostic Unix socket files in `/tmp/cc-socks/*.sock` — so the transport is not the limiting factor. The limitation is discovery: a session only reads the `sessions/` directory under its *own* `CLAUDE_CONFIG_DIR`. If you run Claude Code with two different config directories (e.g. default `~/.claude` vs. a custom profile like `~/.another-claudes/lifanuke`), each session's registry is a separate, isolated directory, and neither session ever looks in the other's registry. The result: two Claude Code sessions started under different `CLAUDE_CONFIG_DIR` values cannot discover or message each other, even though they are on the same machine and could technically reach each other's sockets. Cross-session messaging works *within* one profile, not *across* profiles. This was confirmed by direct inspection of the registry files on disk in a prior investigation, not inferred from documentation.

## 2. Could agent-memory.dev bridge two independent Claude Code sessions?

**Preliminary finding from homepage content** [agent-memory.dev](https://www.agent-memory.dev/): agentmemory is a memory/context-persistence tool for coding agents, not a messaging tool. It runs as a single local Node process ("0 EXTERNAL DBs... Runs as a single Node process with zero external services. State lives on disk as JSON") exposing a memory server on `localhost:3111` (MCP/REST) and a live viewer on `localhost:3113`. It offers an MCP surface (`memory_save`, `memory_recall`, `memory_smart_search`, `memory_sessions`, `governance`, `audit`, `export`) and "every MCP tool has a REST twin under /agentmemory/*". It has a first-class Claude Code plugin ("12 hooks + MCP + skills") that auto-captures session events (prompt, tool call, stop) into the memory pipeline. It supports write-time provenance tagging: "Every record carries write-time provenance: user, agent, tool, import, or shared. Pass agentId through save and recall to scope memory per agent" — this is notable because it means multiple distinct agent identities can write into and be distinguished within the same memory store.

This establishes the store is reachable over a normal local HTTP/MCP endpoint, so in principle two Claude Code sessions could both be configured to point at the same running agentmemory server (same `AGENTMEMORY_URL`) and both save/recall records, using the `agentId` field to tag/filter who wrote what — i.e., a shared read/write point does appear technically plausible.

**Update after reading the full MCP tool reference** [agent-memory.dev/docs/mcp-tools](https://www.agent-memory.dev/docs/mcp-tools) (54 tools, `src/mcp/tools-registry.ts`): this materially strengthens the "yes" case beyond plain shared storage. Under a "Team and mesh" and "Actions and coordination" category, the tool registry documents actual agent-to-agent primitives, not just a memory store:
- `memory_signal_send` — "Send a message to another agent or broadcast. Supports threading, typed messages, and TTL expiration."
- `memory_signal_read` — "Read messages for an agent. Marks delivered messages as read."
- `memory_lease` — "Acquire, release, or renew an exclusive lease on an action. Prevents multiple agents from working on the same thing."
- `memory_team_share` / `memory_team_feed` — share a memory/observation with team members / get recent shared items from all team members.
- `memory_mesh_sync` — "Sync memories and actions with peer agentmemory instances for multi-agent collaboration."
- `memory_claude_bridge_sync` — "Sync memory state to/from Claude Code's native MEMORY.md file" (a Claude-Code-specific bridge tool).
- `memory_action_create`/`memory_frontier`/`memory_next` — typed work items with dependencies, so one agent's actions can be picked up by another.

**Answer: Partial-yes.** agent-memory.dev is not built as "cross-session messaging for Claude Code" and does not touch Claude Code's native `sessions/*.json` discovery registry at all — so it cannot make the native `ListAgents`/`SendMessage` tools work across `CLAUDE_CONFIG_DIR` profiles. But as an independent, out-of-band channel, it plausibly *could* substitute for that native feature for the specific cross-profile-messaging use case: two Claude Code sessions (regardless of `CLAUDE_CONFIG_DIR`) that are both wired to the same running `agentmemory` server via MCP could use `memory_signal_send`/`memory_signal_read` to pass messages to each other by agent id, and `memory_lease`/`memory_action_create`/`memory_frontier` to hand off work items — which is a superset of what plain SendMessage does (it adds TTL, threading, typed messages, and dependency-aware task handoff). This is grounded in the documented tool registry, not speculation about unstated capabilities. What remains unverified from the docs alone: delivery semantics (is `memory_signal_read` pull/poll-only, i.e., the receiving session must proactively call it, or is there any hook-driven push?), and whether the auto-capture hooks would surface an inbound signal to the agent without an explicit recall call.

## 3. What integration would actually require

**Findings from docs overview** [agent-memory.dev/docs](https://www.agent-memory.dev/docs): The tool's own framing confirms its purpose is single-agent continuity, not cross-agent handoff: "agentmemory captures what your coding agent does, distills it into durable memory, and recalls it in later sessions. Everything runs on your machine." It stores five record types (Observations, Memories, Lessons, Crystals, Graph). Relevant to provenance/multi-writer use: "Every record carries write-time provenance: the channel it arrived through (user, agent, tool, import, shared)" — note "shared" is listed as one of five *origin channel* tags, not a synchronization protocol; it appears to just be a label on how a record entered the store, not a live cross-agent sync mechanism.

Mechanically, integration into Claude Code would require (per the homepage's connector wiring section) adding an MCP server entry to Claude Code's config, e.g.:
```json
{
  "mcpServers": {
    "agentmemory": {
      "command": "npx",
      "args": ["-y", "@agentmemory/mcp"],
      "env": { "AGENTMEMORY_URL": "http://localhost:3111" }
    }
  }
}
```
plus, optionally, installing the dedicated Claude Code plugin providing "12 hooks + MCP + skills" for auto-capture (per the homepage's plugin comparison table). So the integration mechanism is: (1) run the `agentmemory` server process once per machine, (2) register it as an MCP server in each Claude Code session's config (this can be done independently under each `CLAUDE_CONFIG_DIR`/profile — MCP server registration is a project/user config concern, separate from the `sessions/*.json` registry the native cross-session-messaging feature uses), and (3) optionally install the Claude Code auto-capture plugin/hooks. This is a bolt-on MCP tool, not a hook into Claude Code's native session-discovery registry — it would not make `ListAgents`/`SendMessage` work across profiles; it would only give both sessions a common place to read/write data if each is separately configured to point at the same `AGENTMEMORY_URL`.

**Delivery/timing mechanics, from the architecture page** [agent-memory.dev/docs/how-it-works](https://www.agent-memory.dev/docs/how-it-works): the system is one Node process exposing REST (port 3111), a streams WebSocket (port 3112, "powers the viewer live badge"), and the viewer (port 3113). Capture is push-on-event: "Integrations post every prompt and tool call to `POST /agentmemory/observe`" — this is how the auto-capture hooks write data continuously during a session. Recall, however, is explicit-pull: `mem::search`/`mem::smart-search` run per query (i.e., when an MCP tool is actually invoked), and automatic "context injection" (`AGENTMEMORY_INJECT_CONTEXT=true`) only assembles a context block once, at session start (pinned slots, project profile, top lessons, recent session summaries) — it is not a continuous mid-session feed. There is a live WebSocket stream ("mem-live", port 3112), but the docs describe it as powering the human-facing viewer's live badge, not as a mechanism that pushes new records into a running agent's context or interrupts it.

**Implication for integration work:** to use agentmemory as a handoff channel between two Claude Code sessions, each session needs (1) the MCP server entry pointed at a shared `AGENTMEMORY_URL`, and (2) the receiving session's agent would need to *actively call* `memory_signal_read` (or rely on the once-per-session-start context injection) to notice a message — there is no documented push/interrupt mechanism analogous to how the native `SendMessage`/socket transport delivers a message into a running session in real time. So the two sessions can rendezvous through agentmemory, but only if the receiving side polls or checks at defined points (e.g., session start, or if a hook/skill is written to poll `memory_signal_read` periodically) — this is a real mechanical difference from the native feature, not just a styling detail.

**Configuration details relevant to a multi-session setup** [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration): agentmemory "runs keyless by default: no LLM key, no embedding key, no API auth" and "endpoints are open on loopback" unless `AGENTMEMORY_SECRET` (a bearer token) is set — meaning by default any process on the same machine (both Claude Code sessions, regardless of profile) can already reach the shared server with zero auth setup, which is what makes the cross-profile handoff mechanically trivial to set up. There is an explicit `TEAM_MODE=shared` flag with `TEAM_ID`/`USER_ID` that "scopes memories to (TEAM_ID, USER_ID) tuples" — a built-in multi-writer scoping primitive that goes beyond the `agentId` provenance tag. There is also a dedicated, named Claude Code bridge: `CLAUDE_MEMORY_BRIDGE=true` plus `CLAUDE_PROJECT_PATH` and `CLAUDE_MEMORY_LINE_BUDGET`, which "mirrors compressed memories into Claude Code's memory file" — i.e., a documented, first-party sync path between agentmemory and Claude Code's own memory file, distinct from the generic MCP wiring. None of this configuration surface touches or extends Claude Code's `sessions/*.json` discovery registry or `CLAUDE_CONFIG_DIR` scoping — it is a fully separate, parallel channel that both sessions must be deliberately pointed at.

## 4. Comparison vs. shared MCP server / shared file / shared DB workaround

**From the GitHub repo README** [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory): the project's own comparison table explicitly lists a "Multi-agent" capability row: "MCP + REST + leases + signals," contrasted against competitors like mem0 ("API (no coordination)"), Letta ("Within Letta runtime only"), and CLAUDE.md ("Per-agent files"). This is agentmemory's own claimed differentiator, not third-party confirmation, but it is consistent with the `memory_signal_send`/`memory_lease` tools found in the MCP reference (Section 3). The README also states plainly: "Works with any agent that speaks MCP or HTTP. One server, memories shared across all of them" — confirming by design intent (not just incidental capability) that one running instance is meant to be shared by multiple, independently-configured agent clients.

Architecturally, under "External deps" the comparison table lists agentmemory itself as "None (SQLite + iii-engine)" — i.e., agentmemory *is*, under the hood, a wrapper around SQLite plus a bundled workflow/stream engine ("iii-engine", pinned version, run as a companion process) exposed over REST/MCP/WebSocket, with a large amount of purpose-built application logic on top (BM25+vector+graph hybrid search, consolidation, decay, provenance, leasing, signals, a real-time viewer on port 3113).

**Assessment of "meaningfully better vs. just a shared file/SQLite DB/plain MCP server":**
- For the *narrow* ask in this gap — "let two Claude Code sessions started under different `CLAUDE_CONFIG_DIR` values discover each other and exchange a message" — a bare shared SQLite file or a minimal custom MCP server with two tools (`send`/`poll`) would fully solve it with far less moving surface: no bundled engine process, no BM25/vector/graph indexing, no consolidation pipeline, no LLM provider wiring, no viewer, none of the 54-tool surface area. The core mechanism agentmemory would actually be exercised for here — `memory_signal_send`/`memory_signal_read`, which are poll-based, not push — is something a 20-line SQLite table with a `WHERE read = 0` query accomplishes identically in complexity terms.
- Where agentmemory would be *meaningfully* better than a bespoke shared DB is if the team already wants the rest of its feature set (durable cross-session memory, retrieval, lessons, knowledge graph, replay/viewer) for its own sake — in that case, adding signal-passing "for free" via already-installed infrastructure the team is already running is a reasonable secondary use of a tool acquired primarily for something else. It is not a case where you would install agentmemory *specifically to solve* the cross-profile-messaging gap, because that gap is a tiny fraction of what the tool is built for, and its delivery model (poll on demand / session-start context injection) does not surpass a hand-rolled shared file for that one job.
- Net: for this specific use case in isolation, agentmemory is added complexity for the same outcome. It only stops being "added complexity" if the adopting team's actual motivation is agent memory/continuity broadly, with cross-session signaling as an incidental bonus.

**Additional confirmation from the REST API reference** [agent-memory.dev/docs/rest-api](https://www.agent-memory.dev/docs/rest-api): the "Actions" endpoint family is explicitly documented as "the coordination layer: work items, dependencies, leases, messaging, gates" (routes include `signals/*`, `leases/*`, `checkpoints/*`, `sentinels/*`), and REST auth is uniform — "When `AGENTMEMORY_SECRET` is set every call requires `Authorization: Bearer <secret>`" — same on-by-default-open-on-loopback / opt-in-token model as the MCP surface. The "Team and mesh" family additionally exposes `mesh/peers`, `mesh/sync`, `mesh/receive`, `mesh/export` — for the case where the two Claude Code sessions are on *different* machines (not just different `CLAUDE_CONFIG_DIR` on one machine), each machine would run its own agentmemory instance and use mesh peer sync (bearer-token-gated, per the Configuration page) rather than pointing at one shared server. For the specific gap as described (same machine, different config profiles), no mesh sync is needed — one shared local instance suffices.

## 5. Verdict

**Recommend: No — do not adopt agent-memory.dev specifically to bridge the cross-profile session-discovery gap. Insufficient justification for the added surface area, given the gap can be closed with a much smaller mechanism.**

Reasoning, stated plainly:
- **Technical feasibility is real, not speculative.** The documented MCP/REST tool registry includes genuine agent-to-agent coordination primitives — `memory_signal_send`/`memory_signal_read` (messaging with threading/TTL), `memory_lease` (mutual exclusion), `memory_action_create`/`memory_frontier`/`memory_next` (task handoff with dependencies) — and the project's own README claims "Multi-agent: MCP + REST + leases + signals" as a differentiator. Two Claude Code sessions under different `CLAUDE_CONFIG_DIR` values could both be wired via MCP to one shared agentmemory server (which is open on loopback by default, so no auth setup is even required for same-machine use) and use these tools to exchange messages and hand off work. This is answer "partial-yes" for Section 2, grounded in the docs, not invented.
- **But it does not touch the actual mechanism that's broken.** The gap is specifically that Claude Code's native `ListAgents`/`SendMessage` feature can't discover sessions across `CLAUDE_CONFIG_DIR` values because discovery is scoped to each profile's own `sessions/*.json` registry. agentmemory does not read, write, or extend that registry, and nothing in its docs claims it does. It would sit entirely alongside the native feature as an unrelated, separately-wired channel — not a fix to `ListAgents`/`SendMessage`, but a workaround that replaces the need for them for this one purpose.
- **The mechanism agentmemory offers for this purpose (poll-based signal read, or once-per-session-start context injection) is not better than a minimal hand-rolled alternative.** It requires no push/interrupt delivery into a running session (Section 3), so the receiving Claude Code session must actively call an MCP tool or wait for its next session start — a shared SQLite table or a two-tool custom MCP server accomplishes the identical poll semantics with a small fraction of the moving parts (no bundled engine process, no hybrid search/consolidation/graph pipeline, no viewer, no 54/130-tool surface to secure and maintain).
- **What would flip this to "recommend":** if the team is *already* adopting agent-memory.dev for its primary purpose — durable cross-session memory/context for coding agents — then using its `memory_signal_send`/`memory_lease` tools as a secondary, already-available channel for cross-profile handoff is a reasonable, low-incremental-cost choice. In that scenario the recommendation would flip to "recommend as a bonus use of already-adopted infrastructure," not "adopt this specifically for the gap."
- **No missing/unverifiable information blocking this verdict.** The docs pages fetched (homepage, docs overview, MCP tools reference, how-it-works, configuration, REST API reference, GitHub README) collectively describe the tool's architecture, delivery semantics, and multi-agent claims in enough concrete detail to answer Sections 2-4 without guessing. The one open question — how exactly `memory_signal_read` behaves if never explicitly polled and context-injection is off (i.e., could a message go unnoticed indefinitely) — does not change the verdict, since even in the best case (immediate, reliable poll-delivery) the tool remains disproportionate to the narrow gap.
