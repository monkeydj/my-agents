# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Quick Overview

**See [@README.md](README.md) for full structure, quick navigation, and getting started.**

This is a personal Claude Code skills, agents, and operational rules repository. Contains no build system or dependencies — skills and agents are pure markdown, ready to run immediately.

## Key Points for Claude Code

- **Skills** live in `skills/<name>/SKILL.md` — invoked with `/skillname`
- **Agents** live in `agents/<name>.md` (single file, portable) — invoked programmatically
- **Rules** live in `rules/` — shape decision-making and voice (prima-flint, crafting, dissensus, endophosia)
- **Conventions**: Conventional commits, branch from `main`; rules live in `rules/` — `prompts/GLOBAL_CLAUDE.md` is a sample/draft only, not enforced

## Skill Format

Each skill includes: frontmatter (name, description), trigger phrases, workflow phases, examples.

## Agent Format

Each agent includes: frontmatter (name, description, tools, model), input/output contracts, all behavior rules inlined (must be portable).

## Skill vs. Agent Split

- **Skills**: Interactive, human-facing (tone-check loops, publish confirmations) → `skills/`
- **Agents**: Programmatic, callable by other agents → `agents/`

When both exist for the same job, skill delegates to agent, owns only the human loop.

## Plugin Manifest

`plugins/anima/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must stay in sync. Symlinks inside `anima/` — do not break.

---

**For detailed structure, skill list, agent list, and research topics, see [README.md](README.md).**
