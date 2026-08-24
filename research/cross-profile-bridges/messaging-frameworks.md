# Agent 1: Alternative Cross-Session Messaging Frameworks

**Status:** COMPLETE
**Last updated:** 2026-08-24

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

## Context: The Problem You're Solving

Cross-profile Claude Code messaging gap: Two Claude Code sessions running under different `CLAUDE_CONFIG_DIR` profiles cannot discover each other via native `ListAgents`/`SendMessage` because session registry files are scoped per-profile. Prior research (research/agent-memory-dev/) evaluated agent-memory.dev as a potential bridge but found it disproportionate for this narrow use case.

Your job: Find alternative tools/frameworks that solve the same problem (cross-profile messaging, or broader cross-agent coordination) with lower complexity or different trade-offs than agent-memory.dev.

---

## 1. Native Claude Code Registry Widening

### Session Registry Scope

Claude Code's session registry is isolated per `CLAUDE_CONFIG_DIR` profile. Each profile maintains its own `~/.claude/sessions/` directory ([Claude Code Docs](https://code.claude.com/docs/en/claude-directory)), containing one file per active session used for concurrent-session detection and crash recovery.

### Configuration Extensibility

**Current limitations:**
- `CLAUDE_CONFIG_DIR` controls the base directory for all `.claude` resources (settings, credentials, MCP configs, session registry)
- No native configuration exists to widen the discovery scope beyond a single profile
- Sessions registry queries are profile-local; `ListAgents` and `SendMessage` primitives do not support cross-profile discovery
- Each profile is intentionally isolated: separate credentials, MCP server configs, and histories

### Configuration Options Checked

- `CLAUDE_DISCOVERY_RESULTS_FILE` exists for caching MCP server discovery results, reducing latency with many servers — but this is MCP server discovery, not agent/session discovery
- No registry-path aliasing or symlink-aware configuration found that would allow sharing `sessions/` across profiles

### Conclusion

Native Claude Code registry widening is not supported. The isolation is architectural: each profile gets its own complete `.claude` directory tree for security and independence. Workarounds must bridge the gap externally (see Section 3).

## 2. Other Persistent-Memory Tools (mem0, Letta, LiteLLM)

### Mem0

**Model:** Framework-agnostic memory layer. Sits alongside your agent code.

**Cross-session capability:** [Mem0 vs Letta comparison](https://vectorize.io/articles/mem0-vs-letta) — Mem0 exposes APIs for writing and retrieving memories, with user-scoped persistent stores. Each agent references the same memory backend, enabling cross-session recall.

**Coordination primitive:** Simple read/write APIs. No built-in multi-agent orchestration — external code must coordinate which agents read/write what memories.

**Complexity for Claude Code:** Requires external backend (cloud API or self-hosted). Not a standalone local tool.

### Letta (formerly MemGPT)

**Model:** Full agent runtime with OS-inspired tiered memory (core memory always in context, recall memory retrievable from history, archival memory indexed externally). [Mem0 vs Letta](https://aicoolies.com/comparisons/mem0-vs-letta) — Letta manages memory as part of its operating system-style platform.

**Cross-session capability:** Yes, via Letta's persistent storage backend. Agents retrieve memories across sessions through its archival memory subsystem.

**Coordination primitive:** Agents run within Letta runtime. Cross-agent coordination happens within that runtime's state management.

**Complexity for Claude Code:** Heavy dependency. Requires running Letta as a service, agent wrapping, and protocol adaptation.

### LiteLLM

**Model:** LLM provider abstraction layer (routing calls across OpenAI, Claude, Gemini, etc.). Not a memory system per se.

**Cross-session capability:** No native cross-session memory. [LangGraph vs Mem0 vs Letta](https://www.bestaiweb.ai/langgraph-mem0-and-letta-how-the-agent-state-management-stack-took-shape-in-2026/) — LiteLLM integrates with Redis (which both Mem0 and Letta can use as a backend), but LiteLLM itself is provider-neutral, not a coordination layer.

**Coordination primitive:** Not applicable. LiteLLM is a routing layer, not a messaging or state system.

### Redis as Shared Backend

All three can integrate with Redis for persistence: [Best AI Agent Memory Frameworks 2026](https://atlan.com/know/best-ai-agent-memory-frameworks-2026/) — working memory (in-memory, sub-millisecond retrieval) + long-term memory (vector search). This enables cross-session coordination if both agents point to the same Redis instance.

**For Claude Code:** Redis is viable but requires external service dependency (not a built-in alternative).

## 3. Lightweight Shared-State Patterns (SQLite, Redis, File-Based)

### SQLite-Based Message Queues

**Pattern:** Use a shared SQLite database file as a durable message queue. [Building a Durable Message Queue on SQLite](https://dev.to/minnzen/building-a-durable-message-queue-on-sqlite-for-ai-agent-orchestration-335m) — SQLite with `journal_mode=WAL` provides zero-external-service coordination with single-file storage.

**Advantages:**
- No process dependency (unlike Redis)
- Atomic writes via SQLite transactions
- Local to filesystem, easily shared across profiles via path

**Limitations:**
- Concurrency contention under high-frequency read/write
- `journal_mode=WAL` mitigates locking but doesn't eliminate it
- Typical read latency 2–10ms per [Redis Session Stores article](https://zylos.ai/research/2026-03-04-redis-session-stores-distributed-ai-agents/) (slower than Redis sub-millisecond)

**Fit for Claude Code:** Good candidate. Agents can reference a shared SQLite file path outside any `CLAUDE_CONFIG_DIR` and use simple SQL to read/write agent presence and message queues.

### Redis

**Pattern:** In-memory store with optional persistence. [Multi-agent systems: Coordinated AI](https://redis.io/blog/multi-agent-systems-coordinated-ai/) — Redis enables sub-millisecond read latency for working memory (current session events) and long-term memory (vector search for semantic recall).

**Advantages:**
- Sub-millisecond retrieval (production-grade performance)
- Native pub/sub for real-time message passing
- Composable with Mem0, Letta, LangGraph, LiteLLM

**Limitations:**
- Requires external Redis service (not local-only)
- Additional operational complexity for local development

**Fit for Claude Code:** Viable for production multi-profile setups but adds infrastructure. Development workflows may prefer SQLite.

### File-Based / Shared Filesystem Coordination

**Pattern:** Agents coordinate via a shared directory containing JSON/YAML files representing agent state, messages, or checksums. [Designing Multi-Agent Development Environments](https://alexlavaee.me/blog/parallel-agent-sessions-infrastructure-gap/) — shared file system protocol enables asynchronous coordination (blackboard architecture).

**Advantages:**
- Zero external dependencies
- Filesystem atomic guarantees for simple operations
- Debuggable (files are human-readable)

**Limitations:**
- No atomicity across multiple file operations (race conditions)
- No locking mechanism (requires application-level coordination)
- Polling-based (not real-time event notification)

**Fit for Claude Code:** Lowest barrier to entry for cross-profile messaging but most fragile under concurrent writes.

## 4. Comparison: Complexity vs. Benefit

### Performance Trade-offs

| Approach | Read Latency | Write Atomicity | Setup Complexity | External Deps |
|----------|------|-----------------|------------------|---------------|
| **File-based** | Polling (~100ms+) | None (races) | Very Low | None |
| **SQLite** | 2–10ms (per [Redis Session Stores](https://zylos.ai/research/2026-03-04-redis-session-stores-distributed-ai-agents/)) | Strong (WAL-enabled) | Low | None |
| **Redis** | <1ms ([Best databases for AI agent memory](https://redis.io/blog/best-databases-for-agent-memory/)) | Strong | Medium | Redis service |
| **Mem0** | Variable (API-dependent) | Framework-specific | Medium | Cloud/self-hosted |
| **Letta** | Variable | Letta runtime | High | Letta runtime service |

### Complexity Analysis

**Hand-rolled SQLite:** [Persistent Memory comparison](https://sparkco.ai/blog/persistent-memory-for-ai-agents-comparing-pag-memorymd-and-sqlite-approaches) notes SQLite provides low memory overhead (39MB for 0.5GB datasets) with durability. Implementation is lightweight: basic SQL schema for agents table (id, profile, last_seen, message_queue_json), polling loop for message delivery.

**Mem0:** Moderate complexity. Requires SDK integration and external backend. Broader than cross-profile messaging alone — adds semantic memory, user scopes, forget operations. Overkill for pure inter-profile IPC.

**Letta:** High complexity. Full runtime dependency. Agents must be rewritten to Letta protocol. Significant operational overhead. Best suited for teams running dedicated Letta clusters, not local development.

**Redis:** Medium complexity. No SDK rewrite needed; agents use Redis client libraries directly. Production-grade for coordinated multi-profile or multi-machine setups, but unnecessary for local-only use cases.

### Fit for Claude Code Cross-Profile Messaging

**Recommendation Order by Use Case:**

1. **Local development only, simplicity priority:** SQLite with WAL (2–10ms latency, zero external deps, straightforward SQL schema)
2. **Production multi-profile with performance priority:** Redis (sub-millisecond latency, pub/sub support, proven patterns)
3. **Broader agent ecosystem integration:** Mem0 (if semantic memory and user scopes add value beyond messaging)
4. **Full agent platform:** Letta (only if existing Letta deployment or org commitment to full runtime)

### Relative to Hand-Rolled Solutions

[AI Agent Memory Systems Compared](https://openclaw-ai.net/en/blog/ai-agent-memory-systems-2026/) — bespoke SQLite solutions balance simplicity and functionality. For cross-profile messaging, hand-rolled SQLite with basic table schema is simpler than adopting external frameworks but requires managing race conditions and coordination logic in application code.

**Cost of not using external tools:** Agents must implement their own discovery, heartbeat, and message delivery. Estimated implementation: <200 LOC Python if using standard sqlite3 module.
