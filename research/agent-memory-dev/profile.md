# Agent 1: Product & Technical Profile of agent-memory.dev

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

## 1. What agent-memory.dev is

"agentmemory" (marketing site: agent-memory.dev) is a **self-hosted local memory server for coding agents**, not a hosted SaaS. Per the homepage: it runs as "a single Node process with zero external services. State lives on disk as JSON." [agent-memory.dev](https://www.agent-memory.dev/). It positions itself against Mem0, Letta, and Zep/Graphiti in a homepage comparison table [agent-memory.dev](https://www.agent-memory.dev/).

It is simultaneously several project types, per the homepage's own framing:
- **A local server** exposing 130 REST endpoints under `/agentmemory/*` [agent-memory.dev](https://www.agent-memory.dev/)
- **An MCP server** exposing 54 MCP tools (`memory_save`, `memory_recall`, `memory_smart_search`, `memory_sessions`, governance, audit, export, etc.), installable via `npx -y @agentmemory/mcp` [agent-memory.dev](https://www.agent-memory.dev/)
- **A set of agent plugins/hooks** (12 auto-capture hooks) integrating with coding agents/IDEs: Claude Code, Cursor, Codex CLI, GitHub Copilot CLI, OpenCode, "pi", Hermes (Nous Research), and a gateway plugin for "OpenClaw" [agent-memory.dev](https://www.agent-memory.dev/)
- **A bundled real-time web viewer** auto-started on port 3113 [agent-memory.dev](https://www.agent-memory.dev/)

Marketed benchmark claim: 95.2% on "LongMemEval-S," compared on the same homepage table to Mem0 (68.5% on LoCoMo), Letta (83.2% on LoCoMo), and Zep/Graphiti (63.8% on LongMemEval) — note these are stated as different benchmark datasets per competitor, so the table's side-by-side framing is not a like-for-like comparison as presented [agent-memory.dev](https://www.agent-memory.dev/).

Not documented on the fetched homepage: a single explicit mission/tagline sentence defining the product category — the categorization above is inferred from the feature grid and comparison table rather than a stated definition.

## 2. Architecture — where state lives, what talks to what

**Deployment model: self-hosted only** — no hosted/cloud offering is mentioned anywhere on the site. The docs landing page states: "Everything runs on your machine." [agent-memory.dev/docs](https://www.agent-memory.dev/docs)

**State storage**: State lives on disk as JSON, on the same machine running the server — "0 EXTERNAL DBs... Runs as a single Node process with zero external services. State lives on disk as JSON. agentmemory stop flushes indexes before exit, in Docker mode too." [agent-memory.dev](https://www.agent-memory.dev/) This is presented as a differentiator vs. Mem0 (needs Qdrant/pgvector), Letta (Postgres + vector), and Zep/Graphiti (Neo4j) [agent-memory.dev](https://www.agent-memory.dev/).

**Data model** (from the docs landing page) — five record types [agent-memory.dev/docs](https://www.agent-memory.dev/docs):
- **Observations**: raw session events from hooks (prompts, tool calls, results)
- **Memories**: durable typed facts (pattern, preference, architecture, bug, workflow, fact) with version chains — a near-duplicate save supersedes the prior version rather than duplicating it, and recall returns only current versions while history stays queryable
- **Lessons**: short imperative rules with a confidence score that grows on reinforcement and decays when unused
- **Crystals**: frozen one-session summaries retained after raw observations are pruned
- **Graph**: entities/relations extracted from observations

**What talks to what** (component flow, per homepage + docs):
- Coding-agent hooks (12 auto-capture hooks) fire on session start/prompt/tool-call/stop and push observations into the memory pipeline [agent-memory.dev](https://www.agent-memory.dev/)
- The core server exposes both an MCP interface (54 tools) and a REST interface (130 endpoints, "Every MCP tool has a REST twin under /agentmemory/*") — these are two surfaces onto the same backend, not separate systems [agent-memory.dev](https://www.agent-memory.dev/)
- A bundled real-time viewer (web UI, port 3113) reads from the same server for live observation streaming, session replay, memory browsing, and graph visualization [agent-memory.dev](https://www.agent-memory.dev/)
- Optional: an LLM provider key activates consolidation (raw→semantic compression, dedup, decay) and knowledge-graph extraction — capture/recall work without any LLM key, so those are additive, keyless-by-default features [agent-memory.dev/docs](https://www.agent-memory.dev/docs)
- Optional peer-to-peer sync ("mesh federation"): another agentmemory node can be registered to push/pull memories over authenticated HTTPS with a required bearer token [agent-memory.dev](https://www.agent-memory.dev/)

**Self-hosted vs. hosted**: exclusively self-hosted based on all fetched pages so far — no mention of a managed/cloud tier. Will flag explicitly if later pages contradict this.

**Detailed internal architecture** (from the "How it works" doc page) [agent-memory.dev/docs/how-it-works](https://www.agent-memory.dev/docs/how-it-works):
- "One process hosts three parts: a bundled engine (state store, streams, HTTP triggers), a memory worker that registers every `mem::*` function against it, and the viewer. Agent integrations talk to the REST surface or the MCP server; both dispatch to the same worker functions." — confirming REST and MCP are two front-ends onto one internal worker, all inside one OS process.
- **Capture path**: integrations POST to `POST /agentmemory/observe` → `mem::observe` stamps session/project/agent id + origin channel (user, agent, tool, import, shared) → hands off to `mem::compress` (heuristic/synthetic compression with no LLM key; richer LLM-written facts/concepts with a key) → compressed observations enter the BM25 index immediately, the vector index when embeddings are available, and stream live to the viewer over a channel called `mem-live`.
- **Recall path**: `mem::search` / `mem::smart-search` fuse three streams per query — BM25 keyword, vector similarity, graph adjacency — with per-item weight normalization, a cross-stream-agreement bonus, deterministic tie-breaking, and session-diversity caps so one session can't dominate a results page. Superseded memory versions never surface (version chain stays in the store).
- **Context injection** (opt-in via `AGENTMEMORY_INJECT_CONTEXT=true`): `mem::context` assembles a session-start block in fixed order — pinned memory slots, then project profile (top concepts/key files/conventions/common errors), then up to 10 confidence-ranked lessons (project-scoped boosted over global), then recent-session summaries — packed against a token budget (`TOKEN_BUDGET`, default 2000), dropping whole blocks rather than truncating mid-block.
- **Distillation (session-end / slow path)**: consolidation requires both its feature flag and an LLM provider key. Graph extraction runs unconditionally at session end via a deterministic structural pass (files/concepts → nodes, co-occurrence → `related_to` edges) with zero LLM keys required; setting `GRAPH_EXTRACTION_ENABLED=true` plus a provider key adds an LLM pass for typed relations. Crystals outlive pruned raw observations.
- **Runtime ports/surfaces**: 3111 = REST API (`api::*` triggers); 3112 = streams WebSocket (powers the viewer's live badge); 3113 = Viewer (proxies REST, serves dashboard); 49134 = internal engine WebSocket the worker registers against.
- The worker registers **264 functions in total** (superset of the 130 REST endpoints + 54 MCP tools + internal functions), per the same doc page.

## 3. Integration surface — SDKs, APIs, MCP compatibility

**Core distribution**: no traditional client-side SDK for embedding into your own app code is advertised on the homepage; the integration model is CLI-driven and agent-plugin/hooks-driven. The MCP server package is `@agentmemory/mcp`, run via `npx -y @agentmemory/mcp`, and points at a running local server via the `AGENTMEMORY_URL` env var (default e.g. `http://localhost:3111`) [agent-memory.dev](https://www.agent-memory.dev/).

**REST API**: 130 endpoints under `/agentmemory/*`, served on port 3111 (`api::*` triggers), explicitly billed as "every MCP tool has a REST twin" — curlable, browser-fetchable, or proxyable [agent-memory.dev](https://www.agent-memory.dev/), [agent-memory.dev/docs/how-it-works](https://www.agent-memory.dev/docs/how-it-works).

**MCP surface**: 54 MCP tools grouped by area (memory_save, memory_recall, memory_smart_search, memory_sessions, governance, audit, export, lesson save/recall/delete, graph query, etc.) [agent-memory.dev](https://www.agent-memory.dev/). A dedicated MCP tool reference page exists at `/docs/mcp-tools` (not yet fetched in full).

**CLI / connector tooling**: `npx @agentmemory/agentmemory connect` is the setup CLI. Run with no argument it opens an interactive picker over detected agents; `connect <agent>` wires a specific one. Flags: `--all` (wire every detected agent), `--dry-run`, `--force` (reinstall over existing entry), `--with-hooks` (install native auto-capture hooks where supported), `--no-guidelines` (skip writing the memory-usage guideline into the agent's rules file) [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors). Every automated adapter backs up the target config file to `~/.agentmemory/backups/` before writing, and re-reads it afterward to verify.

**Platform note**: on Windows, automated `connect` supports only `copilot-cli`; every other agent needs manual setup there. macOS and Linux support all adapters [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors).

**Breadth of integration — 20 documented adapters** (per the docs "connectors" page), spanning MCP-only, MCP+hooks, and native-plugin styles [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors):
- **Native plugin (hooks + skills + MCP)**: Claude Code (MCP + hooks via `~/.claude/settings.json`), Cursor (7 hooks + 17 skills + MCP, or MCP-only), Devin (MCP + 6 hooks, or plugin with 17 skills)
- **MCP + hooks**: Codex CLI (`~/.codex/config.toml`), Antigravity CLI/agy (`~/.gemini/config/mcp_config.json`), Droid/Factory.ai (`~/.factory/mcp.json`), DeepSeek Harness
- **MCP only**: GitHub Copilot CLI, Gemini CLI, Qwen Code, Antigravity, Kiro, Warp, Cline, Continue, Zed
- **MCP + plugin**: OpenCode (top-level `mcp` key + bundled capture plugin)
- **Manual/native, no MCP required**: pi (TypeScript extension talking directly to REST on port 3111), OpenHuman (REST proxy at 3111, "automation pending"), Hermes Agent (Python plugin + YAML config, manual MCP block)
- The homepage additionally names an "OpenClaw" gateway plugin (onSessionStart/onPreLlmCall/onPostToolUse/onSessionEnd hooks) [agent-memory.dev](https://www.agent-memory.dev/), consistent with the docs page's OpenClaw MCP entry.

**Language/runtime support**: the server, MCP package, and CLI are distributed as Node.js/npm packages (`npx`-run), implying a Node.js runtime requirement for the server itself. Client-side, integration is agent-config-based (JSON/TOML/YAML files) rather than requiring a specific host-app programming language — any MCP-speaking client or anything that can issue HTTP requests to the REST API can integrate, per "the standalone stdio server works with anything that speaks MCP" [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors).

**Skills**: a separate optional layer of "17 skills" installable via `npx skills add rohitg00/agentmemory -y`, described as complementary to `connect` — connect exposes the tools, skills teach the agent when to call them [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors). Note: the referenced GitHub org/user is `rohitg00/agentmemory`, suggesting the underlying open-source repo is at `github.com/rohitg00/agentmemory` (per homepage links to `github.com/rohitg00/agentmemory/tree/main/...` for several plugin integrations) [agent-memory.dev](https://www.agent-memory.dev/).

**Universal MCP JSON config** (from homepage), works across Claude Desktop, Cursor, Cline, Roo, Windsurf, Gemini, Warp, Droid, Kiro, Antigravity, Qwen [agent-memory.dev](https://www.agent-memory.dev/):
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

**Replay/import feature**: can ingest a Claude Code JSONL session transcript directly — "Point agentmemory at a Claude Code JSONL transcript and it rehydrates the session, indexes it for search, and derives crystals and lessons from what it finds." [agent-memory.dev](https://www.agent-memory.dev/)

Not yet confirmed from fetched pages: whether there is a first-party Python/JS client SDK (as opposed to the MCP/REST protocol surfaces) for programmatic use outside of agent-plugin contexts — not documented on the pages fetched so far.

## 4. Auth/access model

**Default posture: no auth.** Per the configuration doc: "agentmemory runs keyless by default: no LLM key, no embedding key, no API auth." [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration)

**Auth mechanism when enabled**: a single shared-secret bearer token via the `AGENTMEMORY_SECRET` env var — "Bearer token required on the REST API, viewer, and all integration plugins. Without it, endpoints are open on loopback." The docs explicitly instruct: "Set `AGENTMEMORY_SECRET` before exposing the daemon beyond loopback." The mesh-sync (peer federation) feature refuses to run without this secret set, and wired MCP client configs pass the secret through automatically via `${AGENTMEMORY_SECRET:-}` so a single export covers every connected client [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration).

This is a **single shared-secret model, not per-user/per-role access control**: one bearer token gates all REST access, the viewer, and integration plugins — there is no documented concept of distinct read vs. write permissions, API keys per client, or granular ACLs on the pages fetched so far.

**Multi-tenant / multi-agent scoping**: the product supports scoping memories by agent and by team, but these are data-partitioning/provenance features, not authorization/access-control features:
- `agentId` can be passed through save and recall calls to scope memory per agent (per homepage: "Pass agentId through save and recall to scope memory per agent") [agent-memory.dev](https://www.agent-memory.dev/)
- Every record carries write-time provenance — an "origin channel" tag of user, agent, tool, import, or shared [agent-memory.dev](https://www.agent-memory.dev/), [agent-memory.dev/docs](https://www.agent-memory.dev/docs)
- `TEAM_MODE=shared` plus `TEAM_ID` and `USER_ID` env vars scope memories to a (team, user) tuple [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration) — but this appears to be a data-scoping/tagging mechanism, not an enforced access-control boundary (nothing on the fetched pages states that a given TEAM_ID/USER_ID is cryptographically verified or prevents cross-team reads at the API layer)

**Federation/mesh auth**: "Peer-to-peer sync. Register another agentmemory node and push or pull memories over authenticated HTTPS. A bearer token is required; no silent syncs." [agent-memory.dev](https://www.agent-memory.dev/) — this reuses the same `AGENTMEMORY_SECRET` bearer-token mechanism per the configuration page, and is refused entirely if no secret is configured.

**Conclusion on the auth model**: single-agent/single-tenant-oriented by default (loopback-only, no auth), with an opt-in shared-secret bearer token as the sole gate for exposing the server beyond localhost or to peer nodes. There is no documented per-tenant or per-role authorization system — "who can read/write a given memory store" is effectively "anyone holding the one configured `AGENTMEMORY_SECRET` value" once auth is turned on, or "anyone who can reach the loopback port" when it is not. Not documented: any mention of OAuth, per-user API keys, or RBAC.

## 5. Maturity signals

**License**: Apache-2.0, per both the homepage comparison table ("OPEN SOURCE: Yes (Apache-2.0)") [agent-memory.dev](https://www.agent-memory.dev/) and the GitHub repo's license badge [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).

**Source location**: `github.com/rohitg00/agentmemory` [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory). Built on top of a separate engine dependency called "iii engine" (`github.com/iii-hq/iii`), version-pinned at 0.11.2 — "agentmemory pins iii-engine v0.11.2 and won't attach to a different version (the worker can't speak another engine's protocol)" [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory), [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration).

**Distribution/versioning**: published to npm as `@agentmemory/agentmemory` (CLI) and `@agentmemory/mcp` (MCP server). Queried directly against the npm registry API, the current published `latest` version of `@agentmemory/agentmemory` is **0.9.29**, license `Apache-2.0`, repository `github.com/rohitg00/agentmemory` [registry.npmjs.org](https://registry.npmjs.org/@agentmemory/agentmemory/latest) — i.e., the package is still pre-1.0 by semver, consistent with an early-stage/actively-iterating project. A `CHANGELOG.md` exists in-repo, referenced as "Latest release notes" [github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md](https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md) — not fetched in detail beyond confirming its existence.

**CI/testing signals**: README displays a "CI" GitHub Actions badge and a stat badge claiming "1,674+ tests passing" [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory). Exact CI pass/fail status and workflow details were not independently fetched (badge only, rendered as an image, not verified beyond its presence).

**Popularity/community signals**: queried directly against the GitHub API, `rohitg00/agentmemory` has **27,240 stars**, **2,330 forks**, and **488 open issues** as of this research [api.github.com/repos/rohitg00/agentmemory](https://api.github.com/repos/rohitg00/agentmemory). The repo was created **2026-02-25** and last pushed to **2026-08-17** — roughly a 6-month-old project with a push within the last week of this research (conducted 2026-08-21), indicating active, ongoing development [api.github.com/repos/rohitg00/agentmemory](https://api.github.com/repos/rohitg00/agentmemory). (Note: a separately-referenced design-doc gist is badged elsewhere on the README as having "1.6k stars / 230 forks" — that figure is for the gist, not the main repo, and is well below the main repo's actual figures above [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).) A "Trendshift" badge is also displayed, indicating the project trended on that GitHub-trends tracking site at some point [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).

**Internationalization**: README is translated into 11 additional languages (Simplified/Traditional Chinese, Japanese, Korean, Spanish, Turkish, Russian, Hindi, Portuguese, French, German), suggesting an actively maintained, community-facing project [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).

**Docs completeness**: the docs site (`agent-memory.dev/docs`) is structured and detailed — dedicated pages exist for Quickstart, Connectors (20 adapters), Integrations (per-agent guides), How it works, Configuration (66 flags, all enumerated with defaults), MCP tools (54-tool reference), REST API reference, and Viewer [agent-memory.dev/docs](https://www.agent-memory.dev/docs), [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors), [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration). Pages carry visible last-modified dates: the docs landing page, connectors page, and configuration page were all "Last modified on August 15, 2026" or "August 16, 2026," indicating recent/active documentation maintenance relative to this research (conducted 2026-08-21) [agent-memory.dev/docs](https://www.agent-memory.dev/docs), [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors), [agent-memory.dev/docs/configuration](https://www.agent-memory.dev/docs/configuration).

**Benchmark claims (self-reported, not independently verified)**: README claims 95.2% R@5 on "LongMemEval-S" (ICLR 2025, 500-question public benchmark) vs. an internal "BM25-only fallback" at 86.2% R@5, and a small in-house 15-session corpus ("coding-agent-life-v1") where its hybrid retrieval reaches "100% top-5 hit rate at the P@5 math ceiling," explicitly caveated in the README itself as "small and gold-sparse" [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory). Token-savings claims (~170K tokens/yr vs. ~19.5M+ for "paste full context") are also self-reported and not independently verified [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory). A comparison table lists numerous competitors by GitHub star count (mem0 63K★, Letta/MemGPT 24K★, Khoj 36K★, supermemory 29K★, MemPalace 54K★, etc.) — these star counts are as displayed in the agentmemory README, not independently verified against each competitor's live repo [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).

**Platform support caveat affecting maturity**: Windows support is explicitly weaker — "The fast path is WSL2. Native Windows engine setup is manual (about 10 to 20 minutes) and `agentmemory connect` is currently unsupported there." [github.com/rohitg00/agentmemory](https://github.com/rohitg00/agentmemory), consistent with the docs/connectors page noting only `copilot-cli` auto-connects on native Windows [agent-memory.dev/docs/connectors](https://www.agent-memory.dev/docs/connectors).

**Not documented / not confirmed from available sources**:
- Independent (third-party) verification of the benchmark numbers — all retrieval/token-savings claims originate from the project's own README/benchmark docs, run on the project's own in-house or adapted corpora
- A formal governance model, maintainer team size, or funding/backing entity beyond the GitHub username `rohitg00`
- Exact CI workflow pass/fail history and coverage percentage (a CI badge and a "1,674+ tests passing" stat graphic are shown, but the underlying workflow run details were not independently fetched)
