---
name: save-plan
description: Save the current plan to Obsidian vault with date, title, and tags
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
argument-hint: [tags...]
---

Save the current plan to `~/Documents/Claude_Plans` at:
`~/Documents/Claude_Plans`

## Instructions

1. Read the active plan from `~/.claude/plans/` and generate a filename: `YYYY-MM-DD-<kebab-case-title>.md` derived from the plan's heading
2. Add Obsidian-compatible YAML frontmatter:
   - `date`: today's date (YYYY-MM-DD)
   - `tags`: include `cc-plan` plus any from `$ARGUMENTS`
   - `project`: basename of current working directory
   - `status`: `planned`
3. Generate a `## TODO` section from the plan's implementation steps:
   - Convert each step into a `- [ ]` checkbox item
   - Add items for prerequisite setup and a final verification item
   - Place before `## Critical Files` or at the end
4. Detect related plans in Claude_Plans dir (same `project` or similar ticket/feature prefix). If found, add `## Related Plans` with wiki-links (e.g. `- [[2026-03-16-risk-indicator-crud]]`)
5. Write the file and report the saved path

## Rules
- Don't include speculative or unverified information
- Don't include secrets, tokens, passwords, or .env values

## Example output

```markdown
---
date: 2026-03-15
tags:
  - cc-plan
  - esignature
  - pdf
  - preview
project: rs-frontend
status: planned
---

# Plan: Some Plan Title

## Context
...

## Implementation Steps

### 1. Do thing A
...

### 2. Do thing B
...

## TODO
- [ ] Prerequisites / infra setup if any
- [ ] Do thing A
- [ ] Do thing B
- [ ] Test end-to-end

## Related Plans
- [[2026-03-18-rise-14068-esig-report-followup-export]]
- [[2026-03-17-fix-esignature-subsection-report-ui]]
- [[2026-03-17-esignature-lineclamp-view-ux]]
- [[2026-03-10-esignature-draw-implementation]]

## Critical Files
...
```
