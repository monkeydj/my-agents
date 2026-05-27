# Jira — Comment Formatting

## General

The MCP `jira_add_comment` / `jira_edit_comment` tools accept markdown and convert it to Jira's internal format (ADF). The API response body shows flat text extraction — trust the UI, not the response body.

## Known Conversion Pitfalls

| Input | Actual Rendering | Workaround |
|---|---|---|
| `+` signs | Silently stripped | Spell out: "and", "with", "or above" |
| Underscores in identifiers (`get_eligible_orgs`) | Parsed as italic (`get*eligible*orgs`) | Avoid underscored identifiers in bold/italic contexts, or accept minor glitch |
| Markdown tables | Work but finicky | Prefer bold labels with dash-separated lines over pipe tables |
| Backticks inside table cells | Unreliable | Use plain text in table cells |

## Preferred Comment Structure

Use bold step labels as list items instead of tables:

```
## Phase Title

**Step 1.1** Description here — Status

**Step 1.2** Description here — Status
```

This converts cleanly to Jira headings and bold text.

## Status Updates

Keep the ticket description as the stable spec. Use comments for living progress — phase status, step completion, blockers. Each progress update is a new comment or edit of a pinned progress comment.
