---
description: Draft Slack messages, team updates, Confluence announcements, Jira comments, and MR descriptions in the user's natural voice. Trigger on "draft a message", "write a Slack message", "announce this", "craft a message for", or any request to write comms on the user's behalf.
---

# ghostwrite

Interactive front end for the `ghostwriter` agent. This skill owns the
human-in-the-loop parts (tone-check, iteration, publish confirmation); all
actual drafting — voice profile, anti-patterns, per-medium formatting rules
— lives in `agents/ghostwriter.md`, the single source of truth. Don't
re-implement drafting logic here.

## Workflow

1. **Read the request** — determine `medium` (slack / confluence / jira /
   mr), `audience`, `purpose`, and `key_facts` from the conversation.

2. **Delegate drafting** — invoke the Agent tool with
   `subagent_type: "ghostwriter"`, passing `medium`, `purpose`, `audience`,
   `key_facts`. For Confluence, do not set `publish: true` yet — draft first.

3. **Handle open questions** — if the returned JSON has non-empty
   `open_questions`, ask the user (you have one; the agent doesn't). Fold
   the answers into `key_facts` and re-invoke.

4. **Present** — show the returned `draft` verbatim. Ask: "tone right?
   anything to add/cut?" Surface any `assumptions`/`limitations` the agent
   noted, briefly.

5. **Iterate** — on feedback, re-invoke `ghostwriter` with `prior_draft` set
   to the last draft and `feedback` set to what the user said. Change only
   what the feedback targets — don't ask the agent to re-polish the whole
   thing.

6. **Publish (Confluence/Jira only)** — if the user explicitly confirms they
   want it published:
   - Confluence: confirm proposed title, parent page (title + link), and
     content outline first (per the agent's publish contract, page
     creation is a visible, hard-to-reverse action — this confirmation is
     this skill's job, not the agent's).
   - Then re-invoke `ghostwriter` with `publish: true` and the target.
   - Report `publish_location` back to the user.

## Calibration Example

**User asks:** "draft a Slack message to the team about dashboard sharing
needing notimanager instead of custom email service"

**Skill gathers:** medium=slack, purpose=heads-up, audience=team,
key_facts="dashboard sharing emails should route through notimanager
instead of a custom email service; analytic3 already has
notimanager_email_service.py with send_email_to_org_user() so the
integration path exists; open question whether notimanager supports a
'dashboard sharing invitation' event type or needs a new one registered."

**Delegates to `ghostwriter`**, which returns a draft with no open
questions (see `agents/ghostwriter.md` for the full example). This skill
then presents that draft as-is and asks "tone right?" — it does not modify
the wording itself.
