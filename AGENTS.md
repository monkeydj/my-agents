# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal Claude Code skills and configuration repository. It contains reusable skills (prompt workflows), a statusline utility script, and a plugin marketplace manifest — no build system or dependencies.

## Repository Structure

- `skills/` — Claude Code skills, each in their own directory with a `SKILL.md`
  - `me-code/` — Full dev cycle orchestrator (branch → implement → test → commit → push)
  - `cipher-talks/` — MR/PR reply crafter with a senior-engineer voice
  - `me-code-workspace/` — Benchmarking iterations for `me-code`
  - `ghostwrite/` — Interactive front end for drafting comms; delegates the
    actual drafting to the `ghostwriter` agent and owns only the human
    tone-check/iterate/publish-confirmation loop
- `agents/` — Self-contained subagent definitions (one `.md` file per
  agent), invoked via the Agent tool's `subagent_type`, callable by other
  agents/orchestrators rather than a live human
  - `ghostwriter.md` — Drafts (and publishes, when told to) Slack/Confluence/Jira/MR
    comms in the user's voice, from context handed to it programmatically
- `plugins/anima/` — Plugin bundle that symlinks `skills/` and `agents/` for
  marketplace distribution
- `.claude-plugin/marketplace.json` — Marketplace manifest (owner: `duy.ton`, plugin: `anima`)
- `scripts/statusline.sh` — Claude Code session monitor with Pac-Man context-window visualization
- `instructions/GLOBAL_CLAUDE.md` — Master rules (duplicated into `~/.claude/CLAUDE.md` for global use)

## Skill File Format

Each skill lives in `skills/<name>/SKILL.md`. The file must include:
- **Description** — one-line summary for `description:` in `plugin.json`
- **Trigger** — exact phrases or input patterns that should invoke the skill
- **Workflow** — numbered phases; each phase has a clear name and action list
- **Voice/Style** (if applicable) — explicit do/don't examples

When editing a skill, keep trigger phrases tight and unambiguous. Phases should be ordered so earlier phases gate later ones (e.g., branch safety always runs first in `me-code`).

## Agent File Format

Each agent lives in a single file: `agents/<name>.md`. No supporting
directory — unlike skills, an agent may not read sibling files at runtime,
because its definition must travel as one file when installed elsewhere
(e.g. copied into `~/.claude/agents/`). The file must include:

- **Frontmatter** — `name`, `description` (what it does + when a caller
  should reach for it vs. alternatives), `tools` (explicit grant, narrowest
  that works), `model`
- **Input contract** — the fields a caller must/may supply
- **Output contract** — the exact shape returned (plain text is fine for
  simple agents; use structured JSON when a caller needs to branch on the
  result)
- Everything else the agent needs to do its job, inlined — voice/style
  rules, domain rules, examples

**Skill vs. agent split:** interactive, human-facing behavior (tone-check
loops, "does this look right?", publish confirmations) lives in `skills/`.
Callable, programmatic behavior invoked by other agents or orchestrators
lives in `agents/`. When both exist for the same job (e.g. `ghostwrite`
skill + `ghostwriter` agent), the skill should be a thin wrapper that
delegates the actual work to the agent and owns only the human loop — the
agent is the single source of truth for how the work gets done.

## Plugin Manifest

`plugins/anima/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must stay in sync when adding or renaming skills or agents. The `skills` and `agents` directories inside `anima` are symlinks — do not break them.

## statusline.sh

The script reads Claude Code session state and renders a two-line status bar. It depends on `jq` and `bc`. When modifying, test rendering at various terminal widths. Progress/debug output goes to stderr; the rendered lines go to stdout.

## Conventions

- Conventional commits strictly enforced — see `instructions/GLOBAL_CLAUDE.md` §4
- Never commit directly to `main`; branch with `feat/`, `fix/`, or `chore/` prefix
- The `instructions/GLOBAL_CLAUDE.md` file is the source of truth for all agent behavior rules; edits there propagate to global `~/.claude/CLAUDE.md` manually
