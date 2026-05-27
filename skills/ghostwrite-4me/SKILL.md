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

## Per-Medium Rules

- **rules/slack.md** — team update, technical ask, heads-up/FYI, blockers templates
- **rules/confluence.md** — formatting rules (header table, images, tables) and announcement style
- **rules/jira.md** — comment formatting, conversion pitfalls, progress tracker structure
- **rules/mr.md** — conventional commit MR description format

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

## Workflow

1. **Read the request** — understand audience, channel, purpose
2. **Load medium rules** — read the relevant file from `rules/`
3. **Draft once** — write in voice profile, one pass
4. **Self-check** — read it aloud mentally. Does it sound like the user or like a press release? If press release, strip.
5. **Present** — show draft. Ask: "tone right? anything to add/cut?"
6. **Iterate** — change only what feedback targets. Don't re-polish the whole thing.

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
