# Wayfinder + Prototype: mattpocock/skills

**Status:** COMPLETE
**Last updated:** 2026-08-26 19:41:20 +07

---

## CRITICAL INSTRUCTIONS FOR AGENT

> **YOU WILL BE STOPPED AND RELAUNCHED IF YOU VIOLATE THIS PROTOCOL.**
>
> The ONLY acceptable pattern is: **Search -> Edit -> Search -> Edit -> Search -> Edit.**
> NEVER: Search -> Search. NO EXCEPTIONS. NOT EVEN ONCE.
>
> After EVERY search or fetch, IMMEDIATELY Edit this file with what you learned.
> If you do two searches in a row without an Edit to this file, you are VIOLATING THE PROTOCOL and will be killed.
>
> Work through sections in order. For each section:
> 1. Search/fetch for information
> 2. IMMEDIATELY write findings to this file under that section
> 3. Search/fetch for more information on the same section
> 4. IMMEDIATELY update this file with additional findings
> 5. Move to next section only after writing current section
>
> If a web fetch returns a 403 error, WRITE WHAT YOU HAVE before trying another URL.
>
> Every number needs a source. Every source needs a clickable URL inline.
> Do NOT collect sources at the end -- put them inline with the facts.
>
> When you are DONE with all sections, change "Status: IN PROGRESS" to "Status: COMPLETE" at the top.

---

## 1. Repo Overview

The repo `mattpocock/skills` (GitHub: [mattpocock/skills](https://github.com/mattpocock/skills)) is a personal collection of reusable Claude Code (and other AI coding agent) skills authored by Matt Pocock, described in its README as built from "decades of engineering experience" and meant to be composable, adaptable practices for real-world AI-assisted engineering work. [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)

**Stated philosophy** — the README frames the skill set as addressing four recurring problems with AI coding agents: [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)
1. Misalignment between what the user intends and what the agent outputs.
2. Excessive verbosity/output from agents that don't share the project's domain jargon.
3. Broken or non-functional code caused by weak feedback loops (tests/debugging discipline).
4. Architectural degradation — codebases becoming complex and unmaintainable over time without intentional design.

The README's prescribed remedies map directly to these problems: communication alignment before coding starts ("grilling sessions"), building a shared domain language to cut verbosity and improve consistency, tight feedback loops via testing/debugging, and intentional architectural design. [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)

**Skill inventory**, grouped by how they're triggered, per the README: [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)
- *Engineering skills (user-invoked)*: `grill-with-docs`, `to-spec`, `to-tickets`, `implement`, `improve-codebase-architecture`, `triage`, `wayfinder`.
- *Engineering skills (model-invoked, i.e. the agent decides to use them)*: `tdd`, `diagnosing-bugs`, `prototype`, `code-review`, `domain-modeling`, `codebase-design`.
- *Productivity skills*: `grill-me`, `handoff`, `teach`, `wait-what`, `to-questionnaire`.

Note the invocation split: `wayfinder` is explicitly user-invoked (something the engineer chooses to run), while `prototype` is model-invoked (the agent decides to reach for it when circumstances call for a throwaway prototype) — this distinction matters for Section 5's day-to-day usage guidance. [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)

One-line summaries from the README: Wayfinder "plans large-scale work spanning multiple sessions using decision tickets on an issue tracker, resolving them sequentially to clarify the path forward." Prototype "creates throwaway prototypes (single HTML files or toggleable UI variations) to answer design questions quickly without committing to production code." [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)

## 2. Wayfinder Skill

Correct path found: `skills/engineering/wayfinder/SKILL.md` (skills live under `skills/engineering/` and `skills/productivity/`, not directly under `skills/`). [github.com/mattpocock/skills tree](https://github.com/mattpocock/skills)

Full source fetched from raw file: [skills/engineering/wayfinder/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### Frontmatter / metadata
```yaml
name: wayfinder
description: Plan a huge chunk of work (more than one agent session can hold) as a shared map of decision tickets on your issue tracker, and resolve them one at a time until the way to the destination is clear.
disable-model-invocation: true
```
`disable-model-invocation: true` confirms the README's classification of wayfinder as user-invoked only — the agent never reaches for it on its own; a human must explicitly trigger it. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### Purpose / problem it solves
Wayfinder targets work "too big for one agent session" and "wrapped in fog" — i.e., the path from the current idea to the destination isn't visible yet. Its own framing: "Wayfinding is about finding that way, not charging at the destination." It charts a **shared map** (a single tracker issue) whose **decision tickets** (child issues) are questions to resolve — not build tasks to execute — worked one at a time until the route is clear. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

The "destination" (what the map is finding its way to) is named first, since it fixes scope: it could be a spec to hand off, a decision to lock before planning, or an in-place change like a data-structure migration. The map format itself is described as domain-agnostic — usable for engineering, course content, or other efforts. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### Core philosophy: "Plan, don't do"
Wayfinder is planning by default. Each ticket resolves a decision; the map is "done" when nothing is left to decide before someone executes. The skill explicitly calls the urge to just start building "usually the signal you've reached the edge of the map and it's time to hand off." An effort can override this via the map's Notes section to fold execution into the map, but the default output is decisions, not deliverables. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### Artifacts produced
1. **The Map** — a single issue on the repo's issue tracker (Jira/GitHub Issues/local markdown, whichever is configured), labelled `wayfinder:map`. It is an index, not a store: it lists decisions made and links to the tickets holding the detail, never restating them. Body sections: `## Destination`, `## Notes` (domain context, skills to consult, standing preferences), `## Decisions so far` (one line per closed ticket + link), `## Not yet specified` (fog of war), `## Out of scope`. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)
2. **Tickets** — child issues of the map, each sized to fit one 100K-token agent session, body is just `## Question`. Each carries a `wayfinder:<type>` label — one of `research`, `prototype`, `grilling`, `task` (see Ticket Types below). Answers are recorded as resolution comments, not written into the ticket body pre-resolution; any created assets are linked, not pasted in. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)
3. Tracker-native **blocking/dependency edges** between tickets — deliberately using the tracker's own dependency feature (not a markdown convention) so the "frontier" (open, unblocked, unclaimed tickets) is visible directly in the tracker UI. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)
4. For research tickets specifically, findings are captured on a throwaway `research/<name>` git branch, linked from the ticket via a context pointer. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### Ticket types (four)
- **Research** (AFK — agent works alone): reading docs/third-party APIs/local knowledge bases to surface a fact a decision is waiting on; resolved by a subagent calling the Skill tool with "research".
- **Prototype** (HITL — human in the loop): raises the fidelity of a discussion via a cheap, rough, concrete artifact (outline, UI/logic code stub) to react to; resolved by calling the Skill tool with "prototype"; the prototype is linked as an asset. Used when the key open question is "how should it look/behave."
- **Grilling** (HITL, the default case): a conversation; always resolved by calling the Skill tool twice — for "grilling" and "domain-modeling".
- **Task** (HITL or AFK): manual work (e.g., signing up for a service, provisioning access, moving data) that must happen before a decision can even be discussed — nothing to decide/research/prototype, just something blocking the discussion. Resolved when done; the answer records what was done and resulting facts (credentials location, URLs, row counts) that later tickets depend on. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

Every ticket type is explicitly tagged HITL or AFK, and the skill is emphatic that a HITL ticket "only resolves through that live exchange; the agent never stands in for the human's side of it" — calling out as broken any grilling agent that answers its own questions. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### "Fog of war" concept
The map is deliberately incomplete — don't chart what you can't yet see. The dim, not-yet-sharp view of decisions/investigations that are coming but can't be pinned down yet is written into the map's `## Not yet specified` section. The test for whether something is a ticket vs. fog: "whether you can state the question precisely now, not whether you can answer it now." Sharp-but-blocked questions become tickets; vague future areas stay as fog until the frontier reaches them and they "graduate" into fresh tickets. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### "Out of scope" concept
Work beyond the destination is out of scope — distinct from fog (which is in-scope but not yet sharp). Ruling something out of scope is a scoping act: an existing ticket found to sit past the destination gets closed and logged with a one-line gist + reason in the map's `## Out of scope` section, never in Decisions-so-far. Out-of-scope items never graduate back in; they return only via a redrawn destination, treated as a fresh effort. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### Step-by-step workflow — two invocation modes
**Mode 1: "Chart the map"** — user invokes with a loose idea:
1. Name the destination — call Skill tool for "grilling" then "domain-modeling" to pin down the spec/decision/change being sought (settles scope first).
2. Map the frontier — grill again, breadth-first this time, surfacing open decisions and first takeable steps. If no fog surfaces (whole journey fits in one session), stop and ask the user how to proceed instead of creating a map.
3. Create the map issue (`wayfinder:map` label): Destination + Notes filled in, Decisions-so-far empty, fog sketched into Not-yet-specified.
4. Create tickets that can be specified now as child issues, then wire blocking edges in a second pass (since issues need ids to reference each other); anything not yet specifiable stays in the fog.
5. Fire off research subagents in parallel for each new `research` ticket (each calls Skill tool "research"), capturing findings on a `research/<name>` branch.
6. Stop — charting is one session's work; it resolves nothing itself. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

**Mode 2: "Work through the map"** — user invokes with an existing map (URL or number); a specific ticket is optional:
1. Load the map (low-res view only, not every ticket body).
2. Choose the ticket — user-named one, or else the first frontier ticket in order. Claim it by self-assigning before doing any work.
3. Resolve it — zoom into full ticket bodies as needed, call whichever Skill tools the map's Notes name (default: "grilling" + "domain-modeling" if in doubt).
4. Record the resolution as a comment, close the ticket, append a one-line context pointer to Decisions-so-far.
5. Add newly-surfaced tickets (create-then-wire), graduate any now-specifiable fog out of Not-yet-specified, rule out-of-scope items rather than "resolving" them, and update/delete map parts the decision invalidates.

Hard rule across both modes: **never resolve more than one ticket per session**, with the sole exception of research tickets (which can run in parallel via subagents). The skill notes the map is meant to support concurrent sessions running unblocked tickets in parallel — expect concurrent tracker edits. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

### Other mechanics
- **Naming convention**: every map/ticket is referred to by its issue title (name), never a bare id/number/slug — "a wall of `#42, #43, #44` is illegible; names read at a glance." Ids/URLs are embedded inside the name as a link, not spoken alone. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)
- **Tracker dependency**: where map/tickets/blocking/frontier queries live is tracker-specific; if no tracker is configured for the repo, the skill tells the user to run `/setup-matt-pocock-skills`, and defaults to a local-markdown tracker absent any other config. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md)

## 3. Prototype Skill

Full source fetched from raw file: [skills/engineering/prototype/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/SKILL.md)

### Frontmatter / metadata
```yaml
name: prototype
description: Build a throwaway prototype to answer a design question. Use when the user wants to sanity-check whether a state model or logic feels right, or explore what a UI should look like.
```
No `disable-model-invocation` flag is set (unlike wayfinder), consistent with the README's classification of prototype as **model-invoked** — the agent can decide on its own to reach for this skill when the situation calls for it, in addition to being explicitly invoked by a user or by wayfinder's own `prototype` ticket type. [prototype SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/SKILL.md)

### Purpose / problem it solves
Opening line states the core definition: "A prototype is throwaway code that answers a question. The question decides the shape." It exists to let an engineer (or the agent) sanity-check a state model / logic, or explore what a UI should look like, cheaply and quickly, without committing to production code or wasting effort on polish that will be discarded. [prototype SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/SKILL.md)

### Step-by-step workflow
**Step 1 — Pick a branch** (of two question types, using the user's prompt, surrounding code, or asking the user):
- **"Does this logic / state model feel right?"** → delegates to a `LOGIC.md` reference file. Produces a single shareable HTML file with free-play buttons plus tabbed guided walkthroughs that push a state machine through hard-to-reason-about cases, drivable by a non-developer.
- **"What should this look like?"** → delegates to a `UI.md` reference file. Produces several radically different UI variations on a single route, switchable via a URL search param plus a floating bottom bar.

If the question is ambiguous and the user isn't reachable, the skill instructs defaulting to whichever branch matches the surrounding code (backend module → logic; page/component → UI) and explicitly stating that assumption at the top of the generated prototype. [prototype SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/SKILL.md)

**Step 2 — Rules that apply to both branches** (6 explicit rules):
1. Throwaway from day one, and clearly marked as such — located near the real module/page it prototypes (for context) but named so a casual reader immediately sees it's not production; follow the project's existing routing convention rather than inventing new structure.
2. Trivial to run — a UI prototype launches via one task-runner command (`pnpm <name>`, `python <path>`, `bun <path>`, etc.); a logic demo is a single HTML file the user can double-click. No setup thinking required.
3. No persistence by default — state lives in memory, since persistence is what's often being checked, not a dependency of the check itself; if the question explicitly needs a DB, hit a scratch DB or local file clearly named "PROTOTYPE, wipe me."
4. Skip the polish — no tests, no error handling beyond what's needed to keep it runnable, no abstractions; the goal is learning fast.
5. Surface the state — after every action (logic branch) or every variant switch (UI branch), print/render the full relevant state so the user can see what changed.
6. Capture it when done — fold any validated decision into the real code, then commit the prototype itself to a throwaway branch (out of main) as a "primary source," and leave a context pointer to that branch on the relevant implementation issue; capture the verdict/answer in the issue or a commit message. Main branch retains only the validated decision, not the prototype code. [prototype SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/SKILL.md)

### Artifacts produced
- A single shareable **HTML file** for logic/state-model questions (free-play + guided walkthrough tabs).
- Multiple **UI variants on one route**, switchable via URL search param and a floating bottom bar, for "what should this look like" questions.
- A **throwaway git branch** holding the prototype code as a permanent, linkable primary source (never merged to main).
- A **context pointer** (link) from the relevant issue/ticket to that branch, plus a captured verdict in the issue or commit message. [prototype SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/SKILL.md)

### LOGIC.md branch detail
Source: [skills/engineering/prototype/LOGIC.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/LOGIC.md)

Defines the logic-branch output as "a single, self-contained HTML file (a shareable demo) that lets anyone drive a state model by clicking buttons," aimed at cases where stakeholders need to validate a conceptual model interactively rather than through documentation — e.g., edge-case verification or API-shape exploration before real implementation. [LOGIC.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/LOGIC.md)

Five-step process it instructs the agent to follow:
1. **Clarify the question** — write down the specific state-model question being prototyped up front, so the demo actually answers the intended problem.
2. **Isolate the logic** — extract core logic into a pure, portable module (reducer, state machine, or function set) separate from any UI layer.
3. **Build the HTML** — one dependency-free shareable file structured as: title/explanation → current-state display → free-play buttons → guided scenario walkthroughs.
4. **Share and iterate** — distribute the file, collect feedback on unexpected behaviors that expose conceptual flaws.
5. **Capture results** — document findings, then archive the prototype alongside the validated logic for future reference. [LOGIC.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/LOGIC.md)

Explicit constraints: avoid tests, database connections, over-generalization, framework dependencies, and production deployment of the demo shell — the extracted logic module itself must stay pure and liftable (portable into real code later). [LOGIC.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/LOGIC.md)

### UI.md branch detail
Source: [skills/engineering/prototype/UI.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/UI.md)

Core instruction: generate 3–5 radically different UI variations on a single route, switchable via a floating bottom bar plus a `?variant=` URL parameter. [UI.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/UI.md)

Two sub-shapes:
- **Sub-shape A (preferred)** — mount the variants on an existing page, preserving real data/context.
- **Sub-shape B (fallback)** — only create a throwaway prototype route if no existing page fits. [UI.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/UI.md)

Key requirement: variants must be "structurally different: different layout, different information hierarchy, different primary affordance, not just different colours" — explicitly ruling out color-only tweaks as a valid variant set. [UI.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/UI.md)

Switcher UI spec: fixed bottom bar with left/right arrows, a variant label, keyboard navigation (←/→ keys), and production-gating so it only renders when `process.env.NODE_ENV !== 'production'`. [UI.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/UI.md)

Process: state the plan → draft radically different variants → wire up the switcher → test cycling through variants → capture the winning variant → fold the winner into real code and move the prototype code to a throwaway branch (mirrors the general "capture it when done" rule from SKILL.md). [UI.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/UI.md)

Anti-patterns explicitly called out: color-only tweaks between variants, over-sharing code between variants (which would blur the "radically different" requirement), real data mutations during exploration, and directly promoting a prototype variant straight to production without a proper rewrite. The winning variant always gets rewritten cleanly before merging — the prototype itself never ships. [UI.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/prototype/UI.md)

## 4. Other Related Skills Supporting the Same Workflow Shape

Both wayfinder and prototype delegate heavily to other skills via the "call the Skill tool with X" pattern rather than duplicating logic. Mapping these out shows the full workflow shape.

### grill-with-docs
Source: [skills/engineering/grill-with-docs/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/grill-with-docs/SKILL.md)

```yaml
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
```

Its entire body is one line: "Call the Skill tool twice, for 'grilling' and 'domain-modeling'." — it is a thin composition wrapper, user-invoked (`disable-model-invocation: true`), chaining two underlying skills: **grilling** (an intensive interview/questioning process) and **domain-modeling** (which produces Architecture Decision Records and a glossary as a side effect of the conversation). This is the same pair wayfinder itself calls in its "Chart the map" step 1 and its default ticket-resolution fallback — confirming grilling + domain-modeling function as the shared clarification engine underneath both `grill-with-docs` and `wayfinder`. [grill-with-docs SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/grill-with-docs/SKILL.md)

### to-spec
Source: [skills/engineering/to-spec/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-spec/SKILL.md)

```yaml
name: to-spec
description: "Turn the current conversation into a spec and publish it to the project issue tracker: no interview, just synthesis of what you've already discussed."
disable-model-invocation: true
```

User-invoked only. Explicitly does **not** interview the user — it synthesizes a spec purely from what's already been discussed plus codebase exploration. This is the natural next step after a grilling/wayfinder-style conversation has converged: turn talk into a durable artifact. [to-spec SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-spec/SKILL.md)

Three-step process: (1) explore the repo if not already done, using the project's domain-glossary vocabulary and respecting existing ADRs; (2) sketch the "seams" at which the feature will be tested, preferring existing seams and minimizing their count (ideal: one seam), confirming with the user; (3) write the spec from a fixed template and publish it to the issue tracker with a `ready-for-agent` triage label. [to-spec SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-spec/SKILL.md)

The spec template has fixed sections: Problem Statement, Solution, User Stories (numbered, "As an \<actor\>, I want \<feature\>, so that \<benefit\>" format, deliberately long/extensive), Implementation Decisions (modules, interfaces, architecture, schema/API — explicitly no file paths or code snippets since they go stale fast, **except** a prototype-derived snippet that encodes a decision precisely, e.g. a state machine/reducer/schema/type shape, which may be inlined with a note that it came from a prototype), Testing Decisions (what makes a good test, which modules, prior art), Out of Scope, Further Notes. [to-spec SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-spec/SKILL.md)

Notably, this is the clearest explicit tie between `prototype` and the rest of the pipeline: prototype output (a state machine/reducer/schema snippet) is the one case where code is allowed to survive into a spec document. [to-spec SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-spec/SKILL.md)

### to-tickets
Source: [skills/engineering/to-tickets/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md)

```yaml
name: to-tickets
description: Break a plan, spec, or the current conversation into a set of tracer-bullet tickets, each declaring its blocking edges, published to the configured tracker (edges as text in one file per ticket locally, or native blocking links on a real tracker).
disable-model-invocation: true
```

User-invoked. Decomposes a plan/spec/conversation into **tracer-bullet tickets** — vertical slices cutting through all layers (schema, API, UI, tests) rather than horizontal layers, each independently demoable and sized to fit one context window. This is the execution-planning counterpart to wayfinder's decision-planning: wayfinder produces decisions, `to-spec` turns them into a spec, `to-tickets` turns the spec into buildable work items. [to-tickets SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md)

Process: (1) gather context from the conversation/spec; (2) explore the codebase, applying domain vocabulary; (3) draft vertical slices under strict completeness/scope rules; (4) quiz the user on granularity and blocking edges before publishing; (5) publish either to local files or the native issue tracker with real blocking relationships. Notably reuses the same tracker-native-blocking-edges mechanic as wayfinder's tickets. [to-tickets SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md)

Vertical-slice rules: each ticket is a complete narrow-but-full-stack path through all layers, independently verifiable, sized for a single context window, with any needed prefactoring done first. A **wide-refactor exception** exists for mechanical, large-blast-radius changes (renaming/retyping shared symbols): use expand–contract (add the new form alongside the old, migrate call sites in batches, then remove the old form) instead of tracer-bullet slicing. [to-tickets SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md)

Publication format mirrors wayfinder's tracker-agnostic design: local mode writes `.scratch/<feature-slug>/issues/<NN>-<slug>.md` (one file per ticket, numbered by dependency order); real-tracker mode uses native blocking relationships and applies the `ready-for-agent` label (same label `to-spec` applies). [to-tickets SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md)

### implement
Source: [skills/engineering/implement/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/implement/SKILL.md)

```yaml
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
```

Full body (short): implement the work described in the spec/tickets; use `/tdd` where possible at pre-agreed seams; run typechecking and single-test-file checks regularly, full test suite once at the end; once done, run `/code-review`; commit to the current branch. This is the final stage of the pipeline: wayfinder (decide) → to-spec (synthesize) → to-tickets (slice) → implement (build) → code-review (check). [implement SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/implement/SKILL.md)

*(Note: the repo also has a `docs/` tree with human-readable descriptions per skill, e.g. `docs/productivity/grilling.md`, separate from the `skills/` tree of actual SKILL.md instruction files — used below where the raw SKILL.md path wasn't resolvable.)*

### research
Source: [skills/engineering/research/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/research/SKILL.md)

No `disable-model-invocation` flag, so it is model-invokable like prototype. Body: spin up a background agent to investigate a question against **primary sources** (official docs, source code, specs, first-party APIs) rather than secondary write-ups, following every claim back to its owning source; write findings to a single Markdown file with per-claim citations; save it wherever the repo already keeps such notes, matching existing convention, or picking a sensible location and stating it if there's no convention. [research SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/research/SKILL.md)

This is the exact skill wayfinder's "research" ticket type calls, run as a subagent so multiple research tickets can resolve in parallel — the one exception to wayfinder's "never resolve more than one ticket per session" rule. [research SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/research/SKILL.md)

### domain-modeling
Source: [skills/engineering/domain-modeling/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/domain-modeling/SKILL.md)

Builds and refines a project's domain model through active discipline: challenging terminology, creating edge-case scenarios, and documenting decisions in real time. Key practices: challenge glossary conflicts immediately; sharpen vague language into precise terms; stress-test domain relationships against concrete scenarios; cross-reference statements against actual code; update `CONTEXT.md` as terms resolve (glossary content only, no implementation detail); create ADRs only when a change is hard to reverse, surprising without context, and the result of a genuine trade-off (not for every decision). File structure: a single bounded context uses one root `CONTEXT.md`; multiple contexts use a `CONTEXT-MAP.md` pointing to per-context files. Files are created lazily — only once there's actual content to write, not upfront scaffolding. [domain-modeling SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/domain-modeling/SKILL.md)

This is the "creates docs (ADRs and glossary) as we go" half of `grill-with-docs`, and is the same skill wayfinder calls alongside grilling both when naming the destination and, by default, when resolving any ticket type it's unsure how to handle. [domain-modeling SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/domain-modeling/SKILL.md)

### grilling
Doc summary source: [docs/productivity/grilling.md](https://github.com/mattpocock/skills/blob/main/docs/productivity/grilling.md) (a human-readable reference doc, distinct from the SKILL.md instruction file)

Grilling is an interview technique that stress-tests plans, decisions, or ideas before implementation, mapping the subject as a **design tree** where decisions branch into dependent sub-decisions. Three core concepts: (1) **Design Tree** — decisions with sub-decisions branching off; (2) **Frontier** — the set of questions whose prerequisites are already settled (directly parallel to wayfinder's own "frontier" of unblocked tickets); (3) **Rounds** — each round asks *all* current frontier questions simultaneously, not one at a time, so ~13 total questions might resolve in 3 rounds rather than 13 sequential back-and-forths. Questions arrive numbered, with title, body, and a recommended answer marked `➡️`, so the user can reply tersely by number instead of quoting the question back. The skill distinguishes **facts** (delegated to sub-agents to research) from **decisions** (which require actual user input) — mirroring wayfinder's research-ticket vs. grilling-ticket split. Grilling stops when the frontier is empty and then requires the user to confirm shared understanding. It can be inverted into a one-question-at-a-time mode via `CLAUDE.md` configuration for users who prefer that. [docs/productivity/grilling.md](https://github.com/mattpocock/skills/blob/main/docs/productivity/grilling.md)

**Note on skill-chaining reliability**: the repo's own docs flag that "a skill that names another skill does not reliably cause that skill to load" — meaning `grill-with-docs`'s one-line body ("call the Skill tool twice, for 'grilling' and 'domain-modeling'") and wayfinder's similar references are not a guaranteed auto-chain in practice; worth checking in day-to-day use that a named sub-skill actually engaged. [docs/productivity/grilling.md](https://github.com/mattpocock/skills/blob/main/docs/productivity/grilling.md)

### tdd
Source: [skills/engineering/tdd/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/tdd/SKILL.md) (model-invoked; no `disable-model-invocation` flag observed)

Covers the red-green-refactor cycle, emphasizing "tests worth keeping" and domain-aligned test vocabulary. Key points: good tests verify behavior through public interfaces, not implementation details; **seams** are pre-agreed public boundaries where tests should live (the same "seam" concept `to-spec` asks the user to confirm before writing a spec); named anti-patterns include implementation coupling, tautological assertions, and horizontal slicing; loop rules mandate writing a failing (red) test first, working one vertical slice at a time, and refactoring only in a dedicated review phase. Links out to sibling reference files `tests.md`, `mocking.md`, and to the `codebase-design` skill for deeper guidance not captured in this summary pass. This is the skill `implement` explicitly invokes ("use /tdd where possible, at pre-agreed seams") during the build phase. [tdd SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/tdd/SKILL.md)

### Overall skill-chain shape
Putting the pieces together, the repo's engineering skills form a pipeline that wayfinder and prototype sit inside, not apart from: **grilling/domain-modeling** (clarify + document) → **wayfinder** (chart decisions for big/foggy efforts) or **grill-with-docs** (for smaller single-session efforts) → **to-spec** (synthesize into a spec) → **to-tickets** (slice into tracer-bullet work items) → **implement** (build, using `tdd` at seams) → **code-review** (check). `prototype` and `research` are cross-cutting utility skills any stage — especially wayfinder ticket resolution — can reach for when a question needs a concrete artifact or outside-repo facts respectively. [wayfinder SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/wayfinder/SKILL.md), [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)

## 5. Practical Adoption — Day-to-Day Invocation

### One-time prerequisite: setup-matt-pocock-skills
Source summary: [skills/engineering/setup-matt-pocock-skills/SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/setup-matt-pocock-skills/SKILL.md)

Before wayfinder (and to-spec/to-tickets, which also reference "the issue tracker... should have been provided to you") can be used in a repo, a one-time `/setup-matt-pocock-skills` run scaffolds per-repo configuration covering: (1) **issue tracker location** — GitHub Issues (default), GitLab Issues, local markdown under `.scratch/`, or a custom system; (2) **triage label vocabulary** — defaults to five canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), overridable; (3) **domain documentation layout** — single root `CONTEXT.md` vs. per-package `CONTEXT-MAP.md` for monorepos. [setup-matt-pocock-skills SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/setup-matt-pocock-skills/SKILL.md)

Five-step process: explore the repo's current state (git remotes, existing `CONTEXT.md`/`AGENTS.md`/`CLAUDE.md`, ADR directories, monorepo signals) → present findings and defaults, decided section by section with the user → show draft config in `docs/agents/` before writing → write/update docs and add an "Agent skills" section to `CLAUDE.md` or `AGENTS.md` → confirm and explain which skills can now use the configuration. User confirmation is required at every step before anything is written. [setup-matt-pocock-skills SKILL.md](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/setup-matt-pocock-skills/SKILL.md)

### Third-party coverage confirming usage pattern
Search turned up independent write-ups of wayfinder (not primary sources, but corroborating the SKILL.md analysis in Section 2): [Wayfinder: The Claude Code Skill That Plans Projects Too Big for One Session](https://pasqualepillitteri.it/en/news/12137/wayfinder-claude-code-skill-plan-big-projects), [The /wayfinder Skill: Navigating the "Fog of War" of Planning](https://www.latent.space/p/wayfinder-skill), [Matt Pocock's Skills, Three Months Later: Fork or Subscribe](https://nathanfennel.com/blog/matt-pocock-skills-three-months-later). One summary describes the invocation as a slash command `/wayfinder`, and structures work into three concepts — **Maps** (accumulated decisions), **Tickets** (categorized grilling/prototype/research/task), and **Sessions** (individual working threads) — with an "orchestrator" managing handoffs between sessions, consistent with the SKILL.md's own two-mode invocation ("chart the map" vs. "work through the map"). [Wayfinder coverage via web search](https://pasqualepillitteri.it/en/news/12137/wayfinder-claude-code-skill-plan-big-projects)

### Author commentary (Matt Pocock, via Latent Space interview)
Source: [The /wayfinder Skill: Navigating the "Fog of War" of Planning](https://www.latent.space/p/wayfinder-skill)

Direct quotes attributed to Pocock on the design philosophy:
- On context management driving the whole approach: "You're managing the context of the agent you're working in — you need to think about the information flow."
- On why domain terminology matters before charting a map: "Once you've figured out the words, then those entities can be really clearly mapped out by the agent." — this is the rationale tying `domain-modeling`/`grilling` in as wayfinder's first step.
- On the fog-of-war framing itself: wayfinder is designed for projects where "you can't quite decide everything right at the start," reflecting that real decisions clarify progressively as work proceeds rather than all being knowable up front. [Latent Space](https://www.latent.space/p/wayfinder-skill)

**Invocation confirmed**: `/wayfinder` slash command, used for projects with an unclear end state. Pocock's explicit guidance on when to reach for it vs. the lighter `grill-me` skill: use wayfinder when "you can feel the fog of war in front of you" (multi-session, genuinely uncertain scope); use `grill-me` when the path is already visible and planning fits in a single session. [Latent Space](https://www.latent.space/p/wayfinder-skill)

**Real-world workflow example**: Pocock reports testing wayfinder on a website re-architecture project in Claude Code. In practice it orchestrates multiple "grilling session" child sessions while keeping one centralized map document (decisions) and per-decision ticket documents (specific open questions), which he credits with eliminating manual session-to-session handoff management — the human doesn't have to re-explain context to each new agent session; the map carries it. [Latent Space](https://www.latent.space/p/wayfinder-skill)

### Confirmed invocation mechanics (repo docs)
Source: [docs/engineering/wayfinder.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md)

- **Trigger**: type `/wayfinder` in a Claude Code session. It is strictly manual-trigger (matches the `disable-model-invocation: true` flag confirmed in Section 2) — quoted directly: "You invoke this by typing `/wayfinder`; the agent won't reach for it on its own." [docs/engineering/wayfinder.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md)
- **Mid-session handoff**: an existing session that has grown too large/unwieldy can transition into wayfinder's map-based planning by saying "hand off to `/wayfinder`." [docs/engineering/wayfinder.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md)
- **Setup dependency**: wayfinder cannot function without the tracker configuration `setup-matt-pocock-skills` establishes — a "Wayfinding operations" section describing how the map, child tickets, blocking edges, and frontier queries map onto the chosen tracker (GitHub/GitLab/local markdown), referenced via `CLAUDE.md`/`AGENTS.md` rather than a hardcoded path, defaulting to local markdown if nothing is configured. [docs/engineering/wayfinder.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md)
- **When to use it vs. not**: multi-session work with a genuinely unclear route → `/wayfinder`; single-session planning → `/grill-with-docs` instead. [docs/engineering/wayfinder.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md)
- **Full day-to-day pipeline after a map completes** (all decision tickets resolved): hand off to `/to-spec` (collapses the linked decisions into one spec) → run `/to-tickets` (slices the spec into implementation tickets) → execute via `/implement`. This confirms the pipeline order inferred in Section 4 directly from the repo's own docs. [docs/engineering/wayfinder.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md)
- **Prototype's role inside this pipeline**: explicitly described as resolving tickets that require a concrete artifact, invoked from within wayfinder specifically when "talking cannot settle" a question about appearance or behavior — i.e., prototype is not usually typed directly by the user day-to-day; it's reached for by wayfinder (or by the agent's own model-invocation judgment per its SKILL.md) at the moment a HITL "prototype"-type ticket comes up. [docs/engineering/wayfinder.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md)

### Confirmed prototype invocation mechanics (repo docs)
Source: [docs/engineering/prototype.md](https://raw.githubusercontent.com/mattpocock/skills/main/docs/engineering/prototype.md)

- **Slash command**: `/prototype`, plus **automatic trigger** — the agent invokes it on its own when a task fits the criteria, consistent with the absence of `disable-model-invocation` in its SKILL.md frontmatter (Section 3). [docs/engineering/prototype.md](https://raw.githubusercontent.com/mattpocock/skills/main/docs/engineering/prototype.md)
- **Framed as a "reach-for-it-anytime standalone" skill**, deployed when design questions can't be settled through discussion alone. Direct quote capturing the philosophy: "Stop grilling, build the throwaway version, look at it, then answer in one line." [docs/engineering/prototype.md](https://raw.githubusercontent.com/mattpocock/skills/main/docs/engineering/prototype.md)
- **Three integration points** in daily use: (1) *upstream* — replaces an extended grilling/discussion session once dialogue hits diminishing returns; (2) *wayfinder consumer* — automatically filed as a decision-ticket type when design uncertainty is blocking wayfinder's progress; (3) *downstream* — feeds validated models/UI directions into `to-spec`. [docs/engineering/prototype.md](https://raw.githubusercontent.com/mattpocock/skills/main/docs/engineering/prototype.md)
- **Explicit failure mode called out**: agents sometimes recommend `/prototype` incorrectly when the design direction is already settled — in that case the user should reach for `/implement` instead. Useful practical caution for day-to-day use. [docs/engineering/prototype.md](https://raw.githubusercontent.com/mattpocock/skills/main/docs/engineering/prototype.md)
- **Output branches confirmed**: logic branch → self-contained HTML file with state panels + guided walkthroughs; UI branch → multiple structural variants switchable via URL parameter. Both land on a throwaway `prototype/<name>` branch linked from the implementation ticket, never merged to main — consistent with, and slightly more specific than, SKILL.md's general "throwaway branch" instruction in Section 3. [docs/engineering/prototype.md](https://raw.githubusercontent.com/mattpocock/skills/main/docs/engineering/prototype.md)

### Installation (one-time, before any of this is usable)
Source: [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)

For Claude Code specifically, the skills package is distributed as a plugin on Claude Code's **official marketplace**: install via `claude plugins install mattpocock-skills` from a terminal, or `/plugin install mattpocock-skills` from inside a Claude Code session. The README notes: "It's in Claude Code's official marketplace, so there's nothing to add first, and updates arrive automatically." For non-Claude-Code agents (e.g. Codex), the README gives a generic installer: `npx skills@latest add mattpocock/skills`. [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)

After installing, `/setup-matt-pocock-skills` must be run once per repo (see above) before wayfinder, to-spec, or to-tickets can operate against a real tracker. [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md)

### Summary: a solo engineer's realistic day-to-day loop
Synthesizing the above into the practical sequence a solo engineer would follow:
1. **Once per machine**: `/plugin install mattpocock-skills` (or `claude plugins install mattpocock-skills`).
2. **Once per repo**: `/setup-matt-pocock-skills` — pick issue tracker (GitHub/GitLab/local markdown), triage labels, doc layout.
3. **Per feature/idea, day to day**:
   - Small, single-session, path-already-clear work → `/grill-with-docs` (interview + ADR/glossary capture), then straight to `/to-spec` → `/to-tickets` → `/implement`.
   - Large, multi-session, genuinely foggy work → `/wayfinder` to chart a map, then repeated `/wayfinder` sessions (or `/wayfinder <map-url>`) to resolve one decision ticket at a time until the map clears, then hand off to `/to-spec` → `/to-tickets` → `/implement`.
   - Whenever a design question ("does this state model feel right" / "what should this look like") can't be settled by talking — either typed explicitly as `/prototype`, or auto-triggered by the agent, or filed as a wayfinder `prototype`-type ticket — build the throwaway artifact, capture the verdict, discard the code.
4. **Anytime research is needed** (docs/API facts) — `/research` (or auto-triggered), captured as a cited Markdown file, or auto-fired in parallel by wayfinder for `research`-type tickets.
5. **At implementation time** — `/implement` drives `/tdd` at agreed seams, then `/code-review` before commit. [README.md](https://raw.githubusercontent.com/mattpocock/skills/main/README.md), [docs/engineering/wayfinder.md](https://github.com/mattpocock/skills/blob/main/docs/engineering/wayfinder.md), [docs/engineering/prototype.md](https://raw.githubusercontent.com/mattpocock/skills/main/docs/engineering/prototype.md)
