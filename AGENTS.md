# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal Claude Code skills and configuration repository. It contains reusable skills (prompt workflows), a statusline utility script, and a plugin marketplace manifest — no build system or dependencies.

## Repository Structure

- `skills/` — Claude Code skills, each in their own directory with a `SKILL.md`
  - `me-code/` — Full dev cycle orchestrator (branch → implement → test → commit → push)
  - `cipher-talks/` — MR/PR reply crafter with a senior-engineer voice
  - `me-code-workspace/` — Benchmarking iterations for `me-code`
- `plugins/anima/` — Plugin bundle that symlinks `skills/` for marketplace distribution
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

## Plugin Manifest

`plugins/anima/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must stay in sync when adding or renaming skills. The `skills` directory inside `anima` is a symlink — do not break it.

## statusline.sh

The script reads Claude Code session state and renders a two-line status bar. It depends on `jq` and `bc`. When modifying, test rendering at various terminal widths. Progress/debug output goes to stderr; the rendered lines go to stdout.

## Conventions

- Conventional commits strictly enforced — see `instructions/GLOBAL_CLAUDE.md` §4
- Never commit directly to `main`; branch with `feat/`, `fix/`, or `chore/` prefix
- The `instructions/GLOBAL_CLAUDE.md` file is the source of truth for all agent behavior rules; edits there propagate to global `~/.claude/CLAUDE.md` manually
