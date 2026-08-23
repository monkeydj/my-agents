# Synthesis: Does agent-memory.dev fit the Claude Code cross-profile messaging gap?

**Status:** COMPLETE
**Last updated:** 2026-08-21

---

## CRITICAL INSTRUCTIONS FOR AGENT

> **YOU WILL BE STOPPED AND RELAUNCHED IF YOU VIOLATE THIS PROTOCOL.**
>
> Read both `profile.md` and `fit-assessment.md` in this same directory before writing anything.
> The ONLY acceptable pattern is: **Read -> Edit -> Read -> Edit.**
> After reading each source file, IMMEDIATELY Edit this file with what you learned.
>
> Produce a single coherent document with:
> - Executive summary (3-5 bullets)
> - Key findings organized by theme (not by source agent)
> - Contradictions or tensions found across the two source files
> - Confidence assessment (what's well-supported vs. needs validation)
> - Recommended next steps
>
> Every claim carried over must keep its inline source URL from the originating file.
>
> When DONE, change "Status: IN PROGRESS" to "Status: COMPLETE" at the top.

---

## Executive Summary

- agent-memory.dev ("agentmemory") is a self-hosted, open-source (Apache-2.0) local memory server for coding agents — one Node process, state on disk as JSON, no external DBs, exposing 54 MCP tools and a 130-endpoint REST twin, with first-party integrations for Claude Code and 19 other agents/IDEs [agent-memory.dev](https://www.agent-memory.dev/), [agent-memory.dev/docs](https://www.agent-memory.dev/docs).
- Its stated purpose is single-agent durable memory/continuity across sessions ("captures what your coding agent does, distills it into durable memory, and recalls it in later sessions") [agent-memory.dev/docs](https://www.agent-memory.dev/docs) — not cross-agent messaging.
- Bottom-line verdict: **partial-yes on technical feasibility, no on recommended adoption for this specific gap.** The tool does carry genuine agent-to-agent coordination primitives (`memory_signal_send`/`read`, `memory_lease`, `memory_action_create`/`frontier`, `memory_mesh_sync`) that could substitute for Claude Code's native cross-session messaging when two sessions run under different `CLAUDE_CONFIG_DIR` profiles and thus can't see each other's `sessions/*.json` registry.
- It does not touch or extend Claude Code's native `ListAgents`/`SendMessage` discovery mechanism at all — it would sit alongside it as a wholly separate, deliberately-wired channel, not a fix to the underlying discovery gap.
- For the narrow ask in isolation, the tool is disproportionate: its coordination tools are poll/pull-based (no push into a running session), and a minimal hand-rolled shared MCP server or SQLite table achieves the same delivery semantics with a small fraction of the moving parts. It only becomes a reasonable choice if a team is already adopting agentmemory for its primary memory/continuity purpose and gets the coordination tools "for free."

## Key Findings

### (a) What the tool actually is

agentmemory is a self-hosted local memory server, not a hosted SaaS: "a single Node process with zero external services. State lives on disk as JSON" [agent-memory.dev](https://www.agent-memory.dev/). It is simultaneously four things per its own homepage framing: a local server (130 REST endpoints under `/agentmemory/*`), an MCP server (54 tools, installable via `npx -y @agentmemory/mcp`), a set of agent plugins/hooks (12 auto-capture hooks for Claude Code, Cursor, Codex CLI, GitHub Copilot CLI, OpenCode, and others), and a bundled real-time web viewer on port 3113 [agent-memory.dev](https://www.agent-memory.dev/).

Internally, one process hosts three parts — a bundled engine (built on a version-pinned dependency, "iii-engine" v0.11.2), a memory worker registering 264 functions total, and the viewer — with both the REST and MCP surfaces dispatching to the same worker functions [agent-memory.dev/docs/how-it-works](https://www.agent-memory.dev/docs/how-it-works), [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory). Under the hood it is, per its own comparison table, "None (SQLite + iii-engine)" for external deps [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory) — i.e., a SQLite-backed store with substantial purpose-built logic (BM25+vector+graph hybrid search, consolidation, decay, provenance tracking, leasing, signaling, a viewer) layered on top.

Maturity signals are mixed but lean toward "early but active": pre-1.0 on npm (`0.9.29`) [registry.npmjs.org](https://registry.npmjs.org/@agentmemory/agentmemory/latest), a ~6-month-old GitHub repo (created 2026-02-25, last pushed 2026-08-17) with 27,240 stars, 2,330 forks, and 488 open issues [api.github.com/repos/rohitg00/agentmemory](https://api.github.com/repos/rohitg00/agentmemory), a CI badge and a claimed "1,674+ tests passing" (not independently verified) [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory), and self-reported (not third-party-verified) benchmark claims of 95.2% on LongMemEval-S [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).

### (b) The specific coordination primitives that make "partial-yes" possible

The full MCP tool reference [agent-memory.dev/docs/mcp-tools](https://www.agent-memory.dev/docs/mcp-tools) documents a "Team and mesh" / "Actions and coordination" category that goes beyond plain memory storage:
- `memory_signal_send` — "Send a message to another agent or broadcast. Supports threading, typed messages, and TTL expiration."
- `memory_signal_read` — "Read messages for an agent. Marks delivered messages as read."
- `memory_lease` — "Acquire, release, or renew an exclusive lease on an action. Prevents multiple agents from working on the same thing."
- `memory_team_share` / `memory_team_feed` — share a memory/observation with team members / retrieve recent shared items from all team members.
- `memory_mesh_sync` — "Sync memories and actions with peer agentmemory instances for multi-agent collaboration" (for cross-machine, not just cross-profile-same-machine, scenarios).
- `memory_claude_bridge_sync` — a Claude-Code-specific bridge that syncs memory state to/from Claude Code's native `MEMORY.md` file.
- `memory_action_create`/`memory_frontier`/`memory_next` — typed work items with dependencies, so one agent's actions can be picked up by another.

The project's own README explicitly claims a "Multi-agent" differentiator: "MCP + REST + leases + signals," contrasted against mem0 ("API, no coordination"), Letta ("within Letta runtime only"), and CLAUDE.md ("per-agent files") [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory). The REST API reference independently confirms an "Actions" endpoint family described as "the coordination layer: work items, dependencies, leases, messaging, gates" with routes `signals/*`, `leases/*`, `checkpoints/*`, `sentinels/*` [agent-memory.dev/docs/rest-api](https://www.agent-memory.dev/docs/rest-api). By default the server is open on loopback with no auth required ("runs keyless by default: no LLM key, no embedding key, no API auth" [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration)), which is what makes wiring two same-machine Claude Code sessions to one shared instance mechanically trivial.

### (c) The integration mechanism required

Getting two independently-configured Claude Code sessions to talk through agentmemory requires three deliberate steps: (1) run the `agentmemory` server process once per machine; (2) register it as an MCP server in each session's config — independently, under each `CLAUDE_CONFIG_DIR`/profile — using the standard entry:
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
[agent-memory.dev](https://www.agent-memory.dev/); and (3) optionally install the dedicated Claude Code plugin ("12 hooks + MCP + skills") for auto-capture [agent-memory.dev](https://www.agent-memory.dev/). MCP server registration is a project/user config concern entirely separate from the `sessions/*.json` registry that Claude Code's native `ListAgents`/`SendMessage` feature uses — so this integration is additive/parallel, not a hook into the native discovery path [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors).

Delivery is push-on-write but pull-on-read: capture hooks POST continuously to `POST /agentmemory/observe`, but recall (`mem::search`/`mem::smart-search`, and by extension `memory_signal_read`) runs only when an MCP tool is explicitly invoked, or once per session start via optional context injection (`AGENTMEMORY_INJECT_CONTEXT=true`) [agent-memory.dev/docs/how-it-works](https://www.agent-memory.dev/docs/how-it-works). There is a live WebSocket stream ("mem-live," port 3112), but the docs describe it as powering the human-facing viewer's live badge, not as a mechanism that pushes new records into a running agent's context [agent-memory.dev/docs/how-it-works](https://www.agent-memory.dev/docs/how-it-works).

### (d) Comparison vs. a hand-rolled shared MCP server / SQLite workaround

For the narrow ask — letting two Claude Code sessions under different `CLAUDE_CONFIG_DIR` values exchange a message — a bare shared SQLite file or a minimal custom MCP server with two tools (`send`/`poll`) would fully solve it with far less surface area: no bundled engine process, no BM25/vector/graph indexing, no consolidation pipeline, no LLM provider wiring, no viewer, none of the 54-tool/130-endpoint surface. The mechanism agentmemory would actually be exercised for here — `memory_signal_send`/`memory_signal_read`, which are poll-based — is something a 20-line SQLite table with a `WHERE read = 0` query accomplishes with identical complexity.

agentmemory becomes meaningfully better than a bespoke workaround only if the team already wants its broader feature set (durable cross-session memory, hybrid retrieval, lessons, knowledge graph, replay/viewer) for its own sake — in that case, signal-passing arrives "for free" on already-running infrastructure. It is not a case where one would install agentmemory *specifically* to solve the cross-profile-messaging gap, since that gap is a tiny fraction of what the tool is built for, and its delivery model does not surpass a hand-rolled shared file for that one job.

## Contradictions / Tensions

- **Stated purpose vs. use under discussion.** agentmemory's own docs describe its purpose as single-agent durable memory and continuity across sessions — "captures what your coding agent does, distills it into durable memory, and recalls it in later sessions" [agent-memory.dev/docs](https://www.agent-memory.dev/docs) — which is a different problem from live cross-agent signaling between two concurrently-running sessions. The coordination tools (`memory_signal_send/read`, `memory_lease`, `memory_action_create/frontier`, `memory_mesh_sync`) exist and are documented, but they sit in a secondary "Team and mesh" / "Actions and coordination" category, not the product's headline pitch (which is memory recall, benchmark scores, and token savings). Using agentmemory for cross-profile Claude Code messaging is therefore a **repurposing** of a secondary feature set, not use of the tool as intended or as primarily marketed.
- **Delivery semantics vs. the native transport being replaced.** The gap being solved is that Claude Code's native `SendMessage` (with `ListAgents`) pushes a message directly into a running session's turn via a socket transport that works fine once sessions can discover each other — the transport itself was never the limiting factor, only cross-profile discovery was. agentmemory's coordination tools, by contrast, are poll/pull-based: `memory_signal_read` must be actively called by the receiving session, or the message waits for the next session-start context injection [agent-memory.dev/docs/how-it-works](https://www.agent-memory.dev/docs/how-it-works). There is no documented push/interrupt mechanism analogous to native `SendMessage` delivering into an active turn in real time. This is a genuine downgrade in delivery timing, not a stylistic difference — a receiving session could go an entire session without noticing a pending signal unless it happens to poll or unless context injection is enabled and timed right.
- **"Shared" as a label vs. as a sync protocol.** The "shared" origin-channel tag and `TEAM_MODE=shared` scoping are data-partitioning/provenance features (who wrote what, which team/user tuple it belongs to), not authorization or live-sync mechanisms — profile.md's auth-model section and fit-assessment.md's Section 3 both independently note this distinction, which is worth flagging so the two source documents' language ("shared") isn't read as implying more real-time synchronization than is documented.

## Confidence Assessment

**Well-sourced (documented, inline-cited in both source files):**
- The existence, names, and one-line descriptions of the coordination MCP tools (`memory_signal_send/read`, `memory_lease`, `memory_team_share/feed`, `memory_mesh_sync`, `memory_claude_bridge_sync`, `memory_action_create/frontier/next`) — from the MCP tools reference page and cross-confirmed by the REST API reference's "Actions" endpoint family [agent-memory.dev/docs/mcp-tools](https://www.agent-memory.dev/docs/mcp-tools), [agent-memory.dev/docs/rest-api](https://www.agent-memory.dev/docs/rest-api).
- The overall architecture (single Node process, SQLite + iii-engine, REST/MCP as two front-ends on one worker, ports 3111/3112/3113) [agent-memory.dev/docs/how-it-works](https://www.agent-memory.dev/docs/how-it-works).
- The default-open, loopback-no-auth posture and the opt-in `AGENTMEMORY_SECRET` bearer-token model [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration).
- The integration mechanism (MCP config entry, optional plugin/hooks, independence from Claude Code's `sessions/*.json` registry) [agent-memory.dev](https://www.agent-memory.dev/), [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors).
- Maturity/popularity numbers pulled directly from the npm registry and GitHub API (version, stars, forks, open issues, push dates) [registry.npmjs.org](https://registry.npmjs.org/@agentmemory/agentmemory/latest), [api.github.com/repos/rohitg00/agentmemory](https://api.github.com/repos/rohitg00/agentmemory) — these are primary-source API responses, not marketing copy.

**Inference / untested (flagged as such in the source files, carried forward here):**
- That the coordination tools would *actually work smoothly* as a live messaging substitute in practice — this is inferred from documented tool descriptions and architecture, not from a hands-on trial. Neither source file reports having actually run two Claude Code sessions wired to a shared agentmemory instance and exercised `memory_signal_send`/`memory_signal_read` end to end.
- Whether a message sent via `memory_signal_send` could go unnoticed indefinitely if the receiving session never polls and context injection is off — fit-assessment.md explicitly flags this as an open question that "does not change the verdict" but remains unverified.
- The self-reported benchmark and token-savings numbers (95.2% LongMemEval-S, ~170K tokens/yr) are from the project's own README/docs and explicitly noted in profile.md as not independently verified [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory). These are not load-bearing for the messaging-gap verdict but are part of the tool's overall credibility picture.
- Exact CI pass/fail history and test coverage — a badge and a "1,674+ tests passing" graphic exist but were not independently fetched/verified [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).

**Missing/limitations noted by the source research:** no independent third-party verification of any benchmark claim; no documented formal governance model or maintainer team size beyond the GitHub username `rohitg00`; no first-party client SDK confirmed (integration is MCP/REST/CLI-driven only); Windows support for automated setup is materially weaker than macOS/Linux [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors), [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory) — not directly relevant to the messaging-gap verdict but relevant to overall adoption risk if the tool were adopted for its primary purpose.

## Recommended Next Steps

- **Do not adopt agent-memory.dev specifically to close the cross-profile messaging gap.** The documented mechanism is real but disproportionate — it requires standing up a full memory server, its engine dependency, and a 54-tool/130-endpoint surface to get poll-based signaling that a ~20-line SQLite table or a two-tool custom MCP server (`send`/`poll`) would replicate with far less to secure and maintain.
- **If curiosity or a live test is wanted anyway**, the cheap experiment is: wire one shared MCP server (agentmemory, or a minimal hand-rolled equivalent) into two Claude Code sessions running under different `CLAUDE_CONFIG_DIR` profiles, and actually call `memory_signal_send` from one and `memory_signal_read` from the other — live — rather than trusting the docs' tool descriptions alone. This would directly answer the one open question (does a pending signal ever go unnoticed, and how promptly does poll-based delivery actually surface a message) that neither source file could resolve from documentation.
- **Revisit the recommendation only if the underlying motivation changes**: if there's independent interest in agentmemory for its primary purpose (durable cross-session memory/context, retrieval, lessons, knowledge graph) across a team's various coding-agent setups, then its coordination tools become a reasonable "bonus" capability worth exercising as part of that broader adoption — at that point the messaging-gap use case is a secondary benefit of infrastructure already justified on other grounds, not a standalone justification for adoption.
- **If a permanent fix to the actual gap is wanted** (not a workaround), the more direct path — outside agent-memory.dev's scope entirely — would be examining whether Claude Code's own `ListAgents`/`SendMessage` discovery could be pointed at a shared registry location across `CLAUDE_CONFIG_DIR` profiles (e.g., a shared `sessions/` directory or an env var to widen discovery scope), since the transport (Unix sockets in `/tmp/cc-socks/*.sock`) already works across profiles per fit-assessment.md's Section 1 — only discovery is scoped per-profile. This was not investigated in either source file and would need separate research into Claude Code's own configuration surface, not agent-memory.dev's.
