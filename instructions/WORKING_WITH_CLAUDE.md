# Working With Claude Code

A reference guide for explicitly instructing Claude to use skills, invoke MCP tools, and activate plugins — minimizing token overhead from tool inference.

---

## The Big Idea

By default, Claude infers which tool/skill to use from natural language — spending tokens deliberating. You can skip that entirely by naming the exact tool or skill in your first prompt.

---

## The 3 Things You Can Explicitly Invoke

### 1. Skills → `/skill-name`

Skills are saved playbooks (`.claude/skills/<name>/SKILL.md`). Call them by name directly:

```
/review-pr
/deploy staging
/fix-issue 123
```

From your **first prompt**:
```
/explain-code src/auth/login.ts
```

No inference needed — Claude skips deciding "should I use this skill?" and just runs it.

---

### 2. MCP Tools → name them directly

MCP tools are always loaded but Claude still has to figure out which one to call. Cut that out by naming the tool explicitly:

```
Use mcp__jira__getJiraIssue to fetch issue PROJ-42, then summarize it.
```

```
Use the GitHub MCP tool to list open PRs, not WebSearch.
```

This bypasses Claude's "which tool should I pick?" reasoning entirely.

---

### 3. Plugins → `/plugin-name:skill-name`

Plugins are namespaced, so invoke their skills directly:

```
/serena:find_symbol Foo
/atlassian:searchJiraIssuesUsingJql project = MYPROJ
```

---

## Token-Saving First Prompt Templates

**Pattern A — Pure skill dispatch:**
```
/skill-name <args>
```

**Pattern B — Explicit MCP call:**
```
Call [mcp__server__toolName] with [params]. Do not infer tools.
```

**Pattern C — Multi-step, all explicit:**
```
1. /load-context
2. Use mcp__jira__getJiraIssue for ticket ABC-99
3. /write-summary
Skip tool inference at every step.
```

**Pattern D — Deferred tool (schema not yet loaded):**
```
ToolSearch select:WebFetch, then WebFetch https://... prompt="summarize"
```

---

## Quick Reference

| What you want | Explicit syntax |
|---|---|
| Run a skill | `/skill-name [args]` |
| Run a plugin's skill | `/plugin:skill-name [args]` |
| Call an MCP tool | `Use mcp__server__tool with {param: value}` |
| Load a deferred tool | `ToolSearch select:ToolName, then call it` |
| Prevent auto-inference | Add: `"Do not infer tools, use exactly [X]"` |

---

## Deferred Tools Error

If you see this error:

```
InputValidationError: WebFetch failed — schema was not sent to the API
```

It means the tool's schema wasn't loaded into context. Fix:

```
ToolSearch select:WebFetch   ← loads the schema
then: WebFetch <url> prompt="..."
```

Deferred tools appear in `<available-deferred-tools>` but need to be fetched via `ToolSearch` before their typed parameters (arrays, booleans, numbers) are handled correctly.

---

## Session Management

| Command | What it does |
|---|---|
| `claude --resume` / `claude -r` | Open interactive session picker |
| `claude --continue` / `claude -c` | Continue most recent session |
| `/resume` | Switch sessions from within active session |

In the session picker: `/` to search, `A` to toggle all projects, `R` to rename, `P` to preview.

---

## Sources

- [Slash commands — Claude Code Docs](https://code.claude.com/docs/en/slash-commands)
- [Claude Code Extensions Explained: Skills, MCP, Hooks, Subagents, Agent Teams & Plugins](https://muneebsa.medium.com/claude-code-extensions-explained-skills-mcp-hooks-subagents-agent-teams-plugins-9294907e84ff)
