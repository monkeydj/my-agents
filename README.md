# my-agents

Personal Claude Code skills, agents, and operational rules for streamlined AI-assisted development.

## Overview

This repository contains:
- **Skills** — Interactive workflows invoked in Claude Code (CLI or web)
- **Agents** — Self-contained subagents for programmatic orchestration
- **Rules** — Operational principles and voice guidelines
- **Research** — Design docs and fit assessments for Claude features
- **Plugins** — Marketplace distribution bundle

No build system, no dependencies. Skills and agents are pure markdown + instructions; ready to run immediately in Claude Code.

---

## Quick Navigation

### 🎯 Skills (Interactive Workflows)

Located in `skills/`. Invoked with `/skillname` in Claude Code.

| Skill | Purpose |
|-------|---------|
| **me-draft** | Planning & design exploration before implementation |
| **me-craft** | Craftsman-driven code → test → commit cycles |
| **ghostwrite** | Draft Slack, Confluence, Jira, MR comms in your voice |
| **research** | Multi-agent research orchestration (parallel finders + synthesis) |
| **defuddle** | Extract clean markdown from web pages (via npx) |
| **diagen** | Render PlantUML, Mermaid, Graphviz diagrams with traceability |
| **pickup** | Resume an interrupted implementation with context recovery |

Each skill is self-contained: `skills/<name>/SKILL.md` with trigger phrases, workflow phases, and examples.

### 🤖 Agents (Programmatic Subagents)

Located in `agents/`. Invoked via `Agent({ subagent_type: "ghostwriter" })` or similar.

| Agent | Purpose | Use When |
|-------|---------|----------|
| **ghostwriter** | Draft comms (Slack/Confluence/Jira/MR) in voice, from structured context | Another agent or skill needs to generate comms programmatically |

Agents are single-file definitions (`.md` only); can be copied to `~/.claude/agents/` for global availability.

### 📏 Rules (Operational Principles)

Located in `rules/`. Shape how agents behave in decision-making and voice.

| Rule | Summary |
|------|---------|
| **prima-flint.md** | Voice (caveman clarity) + action posture (act when intent clear, no permission-seeking) |
| **crafting.md** | Code pride, debt awareness, learning, structural judgment, sustainable pace + visible checkpoints |
| **dissensus.md** | Pushback & negotiation: steelman before counter, 3-step handshake, dissent requires participation |
| **endophosia.md** | Internal monologue framework for reasoning / exploration (agent-facing only) |

### 📚 Research

Located in `research/`. Design docs and fit assessments.

- `agent-memory-dev/` — Evaluation of Claude agent persistent memory for cross-session context
- `agent-memory-cross-profile/` — Architecture for cross-profile agent memory sharing

### 🔌 Plugins

Located in `plugins/anima/`. Marketplace distribution bundle with symlinked `skills/` and `agents/`.

Manifest: `.claude-plugin/marketplace.json` (owner: `duy.ton`, plugin: `anima`)

### 🛠 Scripts

Located in `scripts/`.

- **statusline.sh** — Claude Code session monitor with Pac-Man context-window visualization. Requires `jq` and `bc`.

### 📖 Prompts

Located in `prompts/`. Custom prompts for various purposes — a sample/draft
of master rules, standalone skill/pattern prompts, and reference guides.
None of these are authoritative or enforced anywhere; the actual rules
live in `rules/`.

| File | Purpose |
|------|---------|
| **GLOBAL_CLAUDE.md** | Sample/draft of master rules — not synced or enforced anywhere; kept for reference |
| **hq_instructions.md** | Standalone prompt: document-compression skill (summarize/extract before reasoning over large fetched content) |
| **hq_instructions_2.md** | Earlier draft of global CLAUDE.md rules — precursor to `rules/prima-flint.md`'s Clarify vs Act section, kept for reference |
| **Haiku Compression Guide.md** | Architecture pattern: Haiku-based compression layer for large Confluence/GitLab responses |
| **KNOWLEDGE_GRAPH_ROUTING.md** | Knowledge graph navigation patterns |
| **SKILL_TEMPLATE.md** | Template for creating new skills |
| **WORKING_WITH_CLAUDE.md** | Reference: explicitly invoking skills/MCP tools/plugins to skip inference overhead |

---

## Repository Structure

```
my-agents/
├── README.md                          # This file
├── CLAUDE.md                          # Project-level Claude Code config (references this README)
├── AGENTS.md                          # Deprecated (see README)
├── LICENSE                            # Apache 2.0
│
├── skills/                            # Interactive workflows
│   ├── me-draft/SKILL.md
│   ├── me-craft/SKILL.md
│   ├── ghostwrite/SKILL.md
│   ├── research/SKILL.md
│   ├── defuddle/SKILL.md
│   ├── diagen/SKILL.md
│   └── pickup/SKILL.md
│
├── agents/                            # Programmatic subagents
│   └── ghostwriter.md
│
├── rules/                             # Operational principles
│   ├── prima-flint.md                 # Voice + action posture
│   ├── crafting.md                    # Code craft principles + checkpoints
│   ├── dissensus.md                   # Pushback & negotiation
│   └── endophosia.md                  # Internal reasoning framework
│
├── research/                          # Design docs & assessments
│   ├── agent-memory-dev/
│   │   ├── profile.md
│   │   ├── fit-assessment.md
│   │   └── synthesis.md
│   └── agent-memory-cross-profile/
│       ├── cross-agent-plugins.md
│       └── cross-profile-architecture.md
│
├── plugins/                           # Marketplace distribution
│   └── anima/
│       ├── skills/ → (symlink to ../skills)
│       ├── agents/ → (symlink to ../agents)
│       └── .claude-plugin/plugin.json
│
├── prompts/                           # Custom prompts (master rules, drafts, patterns)
│   ├── GLOBAL_CLAUDE.md               # sample/draft, not enforced
│   ├── SKILL_TEMPLATE.md
│   ├── KNOWLEDGE_GRAPH_ROUTING.md
│   ├── WORKING_WITH_CLAUDE.md
│   ├── hq_instructions.md
│   ├── hq_instructions_2.md           # draft precursor to rules/prima-flint.md
│   └── Haiku Compression Guide.md
│
├── scripts/                           # Utility scripts
│   └── statusline.sh
│
└── .claude/
    └── settings.local.json            # Local Claude Code config
```

---

## Creating New Skills

1. Create `skills/<name>/SKILL.md`
2. Include frontmatter: `name`, `description`, `origin` (optional)
3. Define trigger phrases, phases, and examples
4. Reference `prompts/SKILL_TEMPLATE.md` for format

No build system required. Skills load directly in Claude Code.

---

## Creating New Agents

1. Create `agents/<name>.md` (single file only)
2. Include frontmatter: `name`, `description`, `tools`, `model`
3. Define input/output contracts
4. Inline all behavior rules (no sibling file references)

Unlike skills, agents must be portable; they're copied to `~/.claude/agents/` for global use.

---

## Conventions

- **Commits**: Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`)
- **Branching**: Feature branches from `main` (never commit directly to `main`)
- **Rules**: live in `rules/`; `prompts/GLOBAL_CLAUDE.md` is a sample/draft only — not synced or enforced anywhere

---

## Getting Started

1. **Browse skills**: `ls skills/` and pick one to explore
2. **Read a rule**: Start with `rules/prima-flint.md` (voice + posture)
3. **Understand agents**: See `agents/ghostwriter.md` for a complete example
4. **Check research**: Dig into `research/` for deep dives on Claude features

---

## License

Apache 2.0 (see LICENSE file)
