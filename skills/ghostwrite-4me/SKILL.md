---
description: Draft Slack messages, team updates, Confluence announcements, Jira comments, and MR descriptions in the user's natural voice. Trigger on "draft a message", "write a Slack message", "announce this", "craft a message for", or any request to write comms on the user's behalf.
---

# ghostwrite-4me

Draft messages that sound like the user wrote them — not like an AI polished them.

## Voice Profile

**Identity:** Vietnamese high-intermediate English. Casual phrasing is intentional, not errors. Natural > grammatically correct.

**Greeting:** `Hi team` (group) or `Hi [name]` (DM). No "Hey everyone!", no "Dear team,".

**Ownership:** `I` when user owns the action. `we` only for genuinely collective work. Never use `we` to soften `I`.

**Structure:** context → what I'm doing / what changed → what I need from you. No preamble.

**Closings:** `if you got thoughts or concerns` / `let me know` / `heads up` / `lmk`. Never: `please share your thoughts`, `looking forward to your feedback`, `don't hesitate to reach out`.

**Length:**
- Status update: 3-6 sentences
- Ask/request: max 2 short paragraphs
- Heads-up/FYI: 1-3 sentences
- Announcement: context paragraph + bullet list of what changed

**Vocabulary:**
- Precise technical nouns (`enablement`, `migration`, `rollback`) over vague verbs (`move forward`, `address`, `leverage`)
- Domain shorthand assumed shared — don't expand acronyms the team already knows
- Name the thing directly, don't dance around it

## Confluence Guard

**Create and publish directly.** After drafting, go ahead and create or update the Confluence page — the user will review the content in Confluence.

**Page creation requires explicit approval.** Before calling `confluence_create_page`, present:
1. Proposed page title
2. Parent page (title + link)
3. Content outline (key sections, not full body)

Wait for user confirmation before creating. Never create Confluence pages in the same turn as the outline.

## Anti-Patterns (never do these)

| Pattern | Why it fails |
|---|---|
| Over-polishing grammar | Removes authenticity. One pass max. |
| Meta-openers: "fundamentally", "essentially", "at its core" | Corporate filler the user never uses |
| Hedging: "it depends", "both approaches have merit" | User states positions as facts |
| AI flattery: "great question!", "absolutely!" | Dead giveaway |
| Soft gestures: "worth exploring", "something to consider" | User says "it should go through X", not "maybe we could think about X" |
| Formal sign-offs: "Best regards", "Thanks in advance" | User closes casual |
| Multiple polish passes | Stop before it sounds like PR copy |

## Message Types

### Slack — Team Update

```
Hi team

[1-2 sentences: what changed or what I did]
[1 sentence: why / context if non-obvious]
[1 sentence: what's next or what I need]

[casual closing if needed]
```

### Slack — Technical Ask

```
Hi [name/team]

[1 sentence: what I'm working on — context]
[1-2 sentences: the specific question or blocker]
[optional: what I already tried or ruled out]

lmk / if you got thoughts on this
```

### Slack — Heads-Up / FYI

```
Hi team

heads up — [thing that happened or will happen]. [impact or what to expect]. [action needed, if any].
```

### Slack — Raising Concerns / Blockers

```
Hi team

[context: what we're building / what plan this relates to]

few things not settled yet:
1. [blocker/question] — [why it matters in 1 clause]
2. [blocker/question] — [why it matters]
3. [blocker/question]

[what I think we should do / who should decide]
```

### Confluence — Announcement or Doc Update

Normal prose, slightly more structured than Slack. Still casual. Use headers and bullets. No corporate boilerplate intro paragraphs.

### Confluence — Formatting Rules

**Header reference table (mandatory).** Every Confluence page starts with a 2-row × 4-column metadata table before any content or TOC:

| Ticket | `BP-XXXX` | Status | `STATUS LOZENGE` |
| Last Updated | `YYYY-MM-DD` | Owner | `Name` |

Use `ac:structured-macro ac:name="status"` for the status cell. Colour mapping: Green = DONE/UNCHANGED, Yellow = IN PROGRESS, Blue = NEW, Red = BLOCKED.

**Images always centered.** Wrap every image in `<p style="text-align: center;">`. No exceptions — inline images, diagrams, screenshots all get centered alignment.

**Tables full-width with proportional columns.** Use `data-layout="full-width"` on all `<table>` elements. Set explicit `style="width:XX%;"` on each `<th>`/`<td>` in the header row, proportional to expected content length — narrow for short fields (codes, dates), wide for descriptions or names. Never leave column widths at Confluence defaults.

### Jira Comments — Formatting Rules

The MCP `jira_add_comment` / `jira_edit_comment` tools accept markdown and convert it to Jira's internal format (ADF). The API response body shows flat text extraction — **not** the actual rendered format. Trust the UI, not the response body.

**Known conversion pitfalls:**

| Pitfall | Workaround |
|---|---|
| `+` signs silently stripped | Spell out: "and", "with", "or above" |
| Underscores in identifiers parsed as italic (`get_eligible_orgs` → `get*eligible*orgs`) | No reliable escape — avoid underscored identifiers in bold/italic contexts, or accept minor rendering glitch |
| Markdown tables in comments | Work but can be finicky — prefer **bold labels** with dash-separated lines for step trackers over pipe tables |
| Backticks inside table cells | Unreliable — use plain text in table cells |

**Preferred comment structure for progress trackers:**

Use bold step labels as list items instead of tables:

```
## Phase Title

**Step 1.1** Description here — Status

**Step 1.2** Description here — Status
```

This converts cleanly to Jira headings and bold text. Avoid embedding code-style identifiers in structural formatting.

**Status updates as comments, not description.** Keep the ticket description as the stable spec. Use comments for living progress — phase status, step completion, blockers. Each progress update is a new comment or edit of a pinned progress comment.

### MR Description

For MR descriptions, use conventional format. For MR comment replies, defer to `cipher-talks` skill instead — different register.

## Workflow

1. **Read the request** — understand audience, channel, purpose
2. **Draft once** — write in voice profile, one pass
3. **Self-check** — read it aloud mentally. Does it sound like the user or like a press release? If press release, strip.
4. **Present** — show draft. Ask: "tone right? anything to add/cut?"
5. **Iterate** — change only what feedback targets. Don't re-polish the whole thing.

## Calibration Example

**User asks:** "draft a Slack message to the team about dashboard sharing needing notimanager instead of custom email service"

**Draft:**
```
Hi team

heads up on dashboard sharing emails — we should route through notimanager instead of building a custom email service in analytic3. analytic3 already has notimanager_email_service.py with send_email_to_org_user(), so the integration path exists.

need to check: does notimanager support a "dashboard sharing invitation" event type, or do we need to register a new one? also need to confirm the email template system on notimanager side.

if you got context on this lmk
```

**Why this works:**
- `Hi team` greeting
- `heads up` — natural opener
- `we should` for team decision, `I` would be for personal action
- Technical nouns: `notimanager_email_service.py`, `send_email_to_org_user()`
- Casual closing: `if you got context on this lmk`
- No corporate filler, no preamble, no sign-off
