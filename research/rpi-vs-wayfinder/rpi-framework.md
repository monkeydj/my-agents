# RPI Framework: Research, Plan, Implement

**Status:** COMPLETE
**Last updated:** 2026-08-26

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

## 1. Origin & Philosophy

**Origin.** RPI (Research, Plan, Implement) was created by HumanLayer (Dex Horthy and team) as a three-phase framework for structuring AI coding-agent work. It is documented and referenced by third parties such as the ZenML LLMOps Database and LinearB's blog, both of which attribute it to HumanLayer: [HumanLayer: Evolving AI Coding Agent Workflows from Research-Plan-Implement to CRISPY — ZenML LLMOps Database](https://www.zenml.io/llmops-database/evolving-ai-coding-agent-workflows-from-research-plan-implement-to-crispy), [Ralph loops make agentic coding reliable with ruthless context resets — LinearB Blog](https://linearb.io/blog/dex-horthy-humanlayer-rpi-methodology-ralph-loop).

**Philosophy.** The core idea: don't throw an entire ticket/task at a coding agent and hope for the best. Instead break the work into three discrete phases so intent and context are made explicit and reviewable at each handoff, rather than compressed into a single opaque prompt-to-code jump: [ZenML LLMOps Database](https://www.zenml.io/llmops-database/evolving-ai-coding-agent-workflows-from-research-plan-implement-to-crispy).

- **Research** — essential in "brownfield" contexts (existing codebases): the agent must understand the existing system before proposing changes.
- **Plan** — a reasoning model (or a human) reviews the research output and writes a step-by-step plan; the plan is meant to compress "intent" into a clean, reviewable artifact.
- **Implement** — a separate agent executes the plan, deliberately starting from a fresh/empty context window (avoiding contamination from the research/plan conversation's noise).

Source: [ZenML LLMOps Database — Evolving AI Coding Agent Workflows from Research-Plan-Implement to CRISPY](https://www.zenml.io/llmops-database/evolving-ai-coding-agent-workflows-from-research-plan-implement-to-crispy).

**Evolution beyond RPI.** HumanLayer itself has since evolved RPI into a seven-stage successor called CRISPY (Context-Research-Iterate-Structure-Plan-sYnthesize), because RPI in practice produced inconsistent results across teams: engineers stopped reading the generated code, plans grew too complex to review effectively, and getting correct agent behavior relied on "magic words" baked into prompts. CRISPY decomposes the old monolithic 85+ instruction prompts into smaller focused stages (each under ~40 instructions) and adds explicit human-agent alignment checkpoints (design discussions, structure outlines) before implementation, aiming for engineers to read and own the actual code rather than lengthy plan documents. HumanLayer reports this produced more reliable 2-3x productivity gains while maintaining code quality: [ZenML LLMOps Database — Evolution from RPI to CRISPY](https://www.zenml.io/llmops-database/evolution-from-rpi-to-crispy-multi-stage-workflow-for-production-coding-agents).

*(Note: this document is being written after RPI's evolution to CRISPY was already public, but the two docs sites under research — Kilo Code and Goose/Block — document the original three-phase RPI, not CRISPY. This is treated as a limitation/context note in Section 6.)*

**Creator.** Dex Horthy, founder of HumanLayer, developed the RPI workflow; the exact creation date isn't stated in secondary sources: [Ralph loops make agentic coding reliable with ruthless context resets — LinearB Blog](https://linearb.io/blog/dex-horthy-humanlayer-rpi-methodology-ralph-loop).

**Problem it solves.** RPI targets agentic coding in "brownfield" (legacy/existing) codebases, where the agent must respect existing architecture and constraints. It exists to give AI automation structure so it doesn't "go off the rails" — a risk that's much higher when an agent has no scaffolding and is just handed a ticket: [LinearB Blog](https://linearb.io/blog/dex-horthy-humanlayer-rpi-methodology-ralph-loop).

**Relation to the "Ralph loop."** The Ralph loop is a separate, simpler pattern (a bash automation loop demonstrated by developer Geoff Huntley in June 2025) that showed "ruthless simplicity and frequent context resets" make agentic code execution reliable. RPI is described as an evolution that applies those same principles (context resets between phases, simplicity of artifacts) to more complex legacy/brownfield environments, where a bare loop isn't enough structure: [LinearB Blog](https://linearb.io/blog/dex-horthy-humanlayer-rpi-methodology-ralph-loop).

**Core principle — "you cannot outsource the thinking."** Horthy's stated philosophy: humans must drive architecture and strategic decisions; AI agents handle execution volume. The Plan phase in particular is framed as the human's opportunity to redirect early and cheaply — in his words, "with 200 lines of markdown" a human can reset the agent's direction "before you get more specific down the road" (i.e., before code is written and correction becomes expensive): [LinearB Blog](https://linearb.io/blog/dex-horthy-humanlayer-rpi-methodology-ralph-loop).

**Stated limitation — greenfield work.** Horthy explicitly notes RPI "falls flat for greenfield work," i.e. when there is no existing codebase to research — the Research phase has nothing to anchor to: [LinearB Blog](https://linearb.io/blog/dex-horthy-humanlayer-rpi-methodology-ralph-loop).

### Primary source found: HumanLayer's own documentation

The original write-up lives in HumanLayer's GitHub repo, `humanlayer/advanced-context-engineering-for-coding-agents` (file: `ace-fca.md` — "Advanced Context Engineering for Coding Agents"), also mirrored as a blog post: [ace-fca.md — humanlayer/advanced-context-engineering-for-coding-agents](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md), [Advanced Context Engineering for Coding Agents — HumanLayer Blog](https://www.humanlayer.dev/blog/advanced-context-engineering). A related, broader HumanLayer project, `12-factor-agents`, states the same foundational principle — "everything is context engineering" because LLMs are stateless functions, so output quality is entirely a function of input quality: [12-factor-agents — humanlayer](https://github.com/humanlayer/12-factor-agents), [12 Factor Agents — HumanLayer Blog](https://www.humanlayer.dev/blog/12-factor-agents).

**Concrete origin story.** RPI emerged from a specific operational problem at HumanLayer: a team member was shipping ~2,000-line PRs daily, creating an unsustainable code-review burden for the rest of the team. Rather than trying to read every line of every PR, the team adopted spec-driven development (Research → Plan artifacts as the review surface, instead of the diff) to keep everyone aligned while scaling output: [ace-fca.md](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md).

**"Frequent intentional compaction."** RPI is presented as one application of a broader technique HumanLayer calls "frequent intentional compaction" — deliberately structuring how context is fed to the AI throughout development, breaking work into discrete phases that each produce a structured markdown artifact distilling complex information, rather than one long continuous back-and-forth conversation: [ace-fca.md](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md).

**Context-utilization guidance (40-60%).** HumanLayer recommends keeping context-window utilization in the 40-60% range (adjusted for problem complexity), citing Geoff Huntley's observation that "the more you use the context window, the worse the outcomes you'll get." This is the underlying rationale for RPI's fresh-session-per-phase design described in Sections 2-4: keeping any single phase's context window from getting too full preserves output quality: [ace-fca.md](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md).

**HumanLayer's own phase descriptions (primary source, slightly different emphasis than the Kilo/Goose docs):**
- **Research** — understand the codebase, relevant files, information flow, and potential problem causes, using subagents for exploration.
- **Plan** — outline precise steps, file edits, and verification procedures, with "super precise" testing approaches aligned to the codebase's existing conventions.
- **Implement** — execute the plan phase-by-phase, compacting status back into the planning document after each verification phase.

HumanLayer states human review at the Research and Planning stages provides the highest leverage against downstream errors — i.e., catching a wrong assumption in Research/Plan is far cheaper than catching it after code has been written: [ace-fca.md](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md).

## 2. Research Phase

**Source:** [Research, Plan, Implement (RPI) — Kilo Code's Agentic Engineering docs](https://path.kilo.ai/introduction/patterns/rpi/)

**Deliverable/artifact.** A structured markdown document saved at a path like `thoughts/research/YYYY-MM-DD-HHmm-topic.md`. It includes git metadata, file/line references, flow descriptions, key components, open questions, and a technical map of the feature as it currently exists in the codebase: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Invocation.** The docs page describes a `/research` slash-command style invocation, e.g. `/research "look through the codebase and research how [feature] is implemented"`. (Note: the fetched summary attributed this specifically to "goose" tooling terminology inside the Kilo page — this needs cross-checking against the Goose docs directly in Section 5, since the page may be describing the pattern generically or citing Goose's implementation as an example.)

**Core mechanics.** The research phase spawns three parallel sub-agents/roles:
- **find_files** — locates relevant files (a "codebase locator")
- **analyze_code** — reads files and documents implementation details
- **find_patterns** — identifies similar existing features or conventions already in the repo

Source: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Key constraint — document only, don't prescribe.** The research phase's strict rule: document existing code only. No suggested changes, no critiques, no planning, no assumptions — everything must be grounded in actual code, not speculation. This keeps Research cleanly separated from Plan: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Handoff / validation gate.** Before progressing to the Plan phase, the research document is validated against a **"FAR" scale**:
- **Factual** — based on actual code, prevents hallucination
- **Actionable** — enables clear building direction, prevents vague requirements
- **Relevant** — solves the real user need, prevents solving the wrong problem

The docs are explicit that "a human must review the research document before proceeding" — this is a manual decision gate, not an automated pass/fail: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**When to use vs. skip.** Recommended for complex, multi-file tasks (refactors, migrations, feature additions, large upgrades). Explicitly skippable for simple single-file changes or obvious bug fixes: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

## 3. Plan Phase

**Source:** [Research, Plan, Implement (RPI) — Kilo Code's Agentic Engineering docs](https://path.kilo.ai/introduction/patterns/rpi/)

**Invocation.** Triggered via a slash command style invocation, e.g. `/plan a removal of the Tool Selection Strategy feature` — or, without dedicated tooling, via a manually written structured prompt for the phase: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Input.** The Plan phase reads the research document produced in Phase 2 as its foundational context — it does not start from a blank slate or from the raw ticket alone: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Process.** The agent: (1) reads the research output, (2) asks clarifying questions to surface unstated assumptions, (3) presents design options where multiple valid approaches exist, and (4) produces a phased implementation plan: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Deliverable/artifact.** Saved at a path like `thoughts/plans/YYYY-MM-DD-HHmm-description.md`. Contents:
- Explicit phases (complex work can have as many as 10 phases)
- Exact file paths requiring modification
- Code snippets showing what to change
- Automated success criteria
- Manual verification steps
- Checkboxes for tracking progress
- Atomic tasks per phase

Source: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Validation gate — the "FACTS" scale.** Each task in the plan must satisfy:

| Criterion | Definition |
|-----------|-----------|
| Feasible | Can actually be done with available tools/APIs |
| Atomic | Single, focused unit of work |
| Clear | Unambiguous instructions |
| Testable | Has clear success criteria |
| Scoped | Properly bounded |

Source: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Handoff to Implement.** The finished plan file becomes the direct input to the Implement phase, invoked e.g. as `/implement thoughts/plans/[plan-path].md`. This lets the Implement agent "execute phases in order," and the checkboxes in the plan allow resuming from interruptions. As with Research → Plan, human validation/review is required before proceeding from Plan → Implement — this is a deliberate manual decision gate, not automatic: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

## 4. Implement Phase

**Source:** [Research, Plan, Implement (RPI) — Kilo Code's Agentic Engineering docs](https://path.kilo.ai/introduction/patterns/rpi/)

**Invocation.** Triggered by passing the plan file directly, e.g. `/implement thoughts/plans/2025-12-23-remove-tool-selection-strategy.md`: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Context management.** The docs describe "fresh sessions per phase — LLM stays focused," i.e. each RPI phase (and per the case study, potentially each implementation phase within the plan) gets a dedicated/reset context window rather than a single continuous conversation carrying all of Research + Plan + Implement. This matches HumanLayer's original design intent noted in Section 1 (Implement starts from a fresh, empty context so it isn't polluted by research/plan discussion noise): [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Execution workflow.** The agent: (1) reads the plan completely, (2) executes phases in order, (3) runs verification after each phase, (4) updates checkboxes directly in the plan file as it goes. Guidance explicitly frames this as mechanical, not creative: "If it feels creative, something upstream is missing" — meaning ambiguity found during Implement is a sign Research or Plan was incomplete, not something to improvise around: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Verification / quality gates.** Each phase must pass: tests pass, build succeeds, linters pass, no regressions introduced. "If any gate fails, the implementation pauses. Fix the issue before proceeding." — gates are blocking, not advisory: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Progress tracking.** Relies on the checkboxes embedded in the plan.md itself; the agent checks off each atomic task as it completes it: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Interruption / recovery.** If the context window fills mid-implementation, the checkboxes let the agent compact and resume exactly where it left off. A documented case study: "Context window filled mid-way — AI compacted and resumed from checkboxes." This is presented as a practical resilience benefit of the plan-as-checklist artifact: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Human control levels.** Three feedback-loop granularities are offered, trading control for speed:
- Task-by-task — maximum control (review every atomic step)
- Phase-by-phase — balanced approach
- Full-plan validation — high confidence only (least oversight, fastest)

Source: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

**Gap noted (limitation of source):** the Kilo docs page, as fetched, does not explicitly describe a final commit/merge/PR step after implementation completes — this is not documented as a standard, named part of the RPI ceremony. Noting this per instructions to flag missing data rather than assume a git workflow is prescribed.

## 5. Tooling & Implementations (kilo.ai vs. goose/block)

**Sources:** [Kilo Code — Research, Plan, Implement (RPI)](https://path.kilo.ai/introduction/patterns/rpi/), [Goose docs — RPI tutorial](https://goose-docs.ai/docs/tutorials/rpi/)

### Goose/Block's presentation

Goose (Block's open-source AI agent) frames RPI explicitly as a workflow that "trades speed for clarity, predictability, and correctness" for complex codebase changes: [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/).

Goose implements each phase as a **named slash-command recipe**:

| Phase | Goose command | Purpose |
|-------|---------|---------|
| Research | `/research_codebase "topic"` | Document existing implementation without suggestions |
| Plan | `/create_plan "feature/task"` | Design changes with phases and success criteria |
| Implement | `/implement_plan "plan path"` | Execute phases mechanically with verification |
| Iterate | `/iterate_plan "plan path" + feedback` | Surgically update the plan if needed, without a full re-plan |

Source: [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/).

Notably, Goose's docs include a fourth command not seen (so far) in the Kilo docs: **`/iterate_plan`**, for surgically revising a plan given feedback, rather than restarting the Plan phase from scratch.

Goose's Research phase spawns the same three parallel subagents as described generically in Section 2 (`find_files`, `analyze_code`, `find_patterns`), operating independently without manual orchestration: [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/).

Artifact structure matches what's described in Sections 2-3 (`thoughts/research/YYYY-MM-DD-HHmm-topic.md`, `thoughts/plans/YYYY-MM-DD-HHmm-description.md`), suggesting this directory convention originates from Goose/HumanLayer's implementation and Kilo's docs describe the same convention: [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/).

Goose's usage guidance: recommended for refactors/migrations, multi-file feature additions, large upgrades, incident cleanup, and documentation overhauls; explicitly consider skipping for "basic, contained tasks where RPI becomes overkill." Goose's docs cite a worked example where the full Research→Plan→Implement cycle took 52 minutes, framing this as a deliberate slower-but-higher-quality tradeoff for complex work: [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/).

### Kilo Code's presentation

Kilo's docs (fetched in Sections 2-4) describe the pattern with slash commands `/research`, `/plan`, and `/implement` (shorter names than Goose's `/research_codebase`, `/create_plan`, `/implement_plan`) and the same FAR (Research) / FACTS (Plan) validation scales. **Open discrepancy to flag:** an earlier fetch of the Kilo page attributed the `/research "..."` command specifically to "goose (tool-specific)" usage inside its own text, versus offering a generic/tool-agnostic prompt otherwise. This suggests the Kilo docs page may itself be using Goose as its worked example/reference implementation rather than presenting an independent Kilo-specific command set — i.e., Kilo Code's docs may be documenting the *pattern* generically while borrowing Goose's actual command syntax for illustration. This needs one more direct check against the Kilo page before treating `/research` vs `/research_codebase` as a genuine terminology difference between the two tools rather than an artifact of how the page cites its example.

**Resolution of the discrepancy (confirmed via direct re-fetch):** Kilo's docs page presents RPI as a tool-agnostic pattern, then illustrates it with a section explicitly titled "goose implementation," stating "Block's goose tool provides built-in RPI support with slash commands." The commands shown there (`/research "..."`, `/plan "..."`, `/implement thoughts/plans/....md`, `/iterate "plan path" + feedback`) are explicitly attributed to Goose — not presented as Kilo's own product commands: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

However, this creates a **genuine cross-site naming mismatch**: Kilo's page shows Goose's commands as `/research`, `/plan`, `/implement`, `/iterate`, while Goose's own docs site shows the longer forms `/research_codebase`, `/create_plan`, `/implement_plan`, `/iterate_plan`: [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/). I don't know which is authoritative/current — this could reflect a Goose recipe-naming change over time, Kilo's docs using shorthand/paraphrased names rather than exact command strings, or a documentation error on one side. Treat the exact command string as unverified; the phase structure and handoff behavior described (which matches across both sites) is the reliable part.

**Kilo's own role:** Kilo Code's docs page does not present a Kilo-specific slash-command implementation of RPI; it presents RPI as a general "Agentic Engineering" pattern (part of a docs site called "path.kilo.ai," distinct from Kilo Code's own product commands) and uses Goose as the worked example. The page credits **HumanLayer** as the framework's creators and credits **Patrick Robinson** for the documentation itself. It also lists RPI as usable, in principle, with other AI coding tools by name: Claude, GitHub Copilot, Cursor, OpenAI, and Gemini — i.e., Kilo frames RPI as portable methodology, not something proprietary to any one vendor: [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/).

### Summary contrast

| Aspect | Kilo Code docs (path.kilo.ai) | Goose/Block docs (goose-docs.ai) |
|---|---|---|
| Framing | RPI as a general, tool-agnostic "Agentic Engineering" pattern; credits HumanLayer as originator | RPI as a Goose-specific tutorial/feature: "trades speed for clarity, predictability, and correctness" |
| Command style | Presents commands as an example ("goose implementation" section) — `/research`, `/plan`, `/implement`, `/iterate` (per Kilo's own text) | Presents commands as Goose's actual built-in recipes — `/research_codebase`, `/create_plan`, `/implement_plan`, `/iterate_plan` |
| Subagents | Describes `find_files` / `analyze_code` / `find_patterns` parallel subagents | Same three subagents, described as automatic/no manual orchestration needed |
| Validation scales | FAR (Research), FACTS (Plan) — named mnemonic acronyms | **Confirmed absent.** Directly re-checked: Goose's docs do not use "FAR" or "FACTS" or any named acronym. Instead they rely on plain human-judgment instructions: "As the human in the loop, be sure to review the research!" and "you as the human need to step in here to review the plan and make sure it's solid." Same underlying practice (human review gate), different presentation (Kilo formalizes it into a mnemonic; Goose states it as plain instruction). [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/) |
| Tool portability | Explicitly lists Claude, Copilot, Cursor, OpenAI, Gemini as compatible | Framed as a Goose recipe/tutorial specifically |
| Extra phase | Not confirmed to document `/iterate` as a distinct named phase beyond example text | `/iterate_plan` is a clearly named 4th command for surgical plan revision |
| Fresh sessions per phase | Described as "fresh sessions per phase — LLM stays focused" | Explicitly stated: "Sessions: It's important to do each phase in a new session to keep the LLM laser focused on only the task at hand. One goal per session!" [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/) |

## 6. Practical Adoption for a Solo Engineer Using Claude Code

*(This section is synthesis, not a source dump — grounded in Sections 1-5 above and in how Claude Code's own primitives map to RPI's mechanics.)*

**How Claude Code's primitives map onto RPI.** Claude Code supports three relevant building blocks that line up cleanly with RPI's phase structure: custom slash commands (Markdown prompt files in `.claude/commands/`, giving an explicit, repeatable terminal entry point per phase), subagents (isolated context windows that do exploration/work and return only a condensed result to the main session — this is the mechanism, not just a metaphor, for RPI's "fresh session per phase" requirement), and CLAUDE.md (for short, always-true repo conventions the Research/Plan phases should already respect rather than rediscover each time): [Claude Code Customization guide — alexop.dev](https://alexop.dev/posts/claude-code-customization-guide-claudemd-skills-subagents/), [Built-in slash commands — Anthropic docs](https://docs.anthropic.com/en/docs/claude-code/slash-commands).

**Minimal concrete setup.** Three custom slash commands would cover the ceremony directly:
- `/research <topic>` — prompt instructs Claude to explore the codebase only (no suggestions/critique), write findings to `thoughts/research/YYYY-MM-DD-topic.md` with file/line references, and stop for human review. Optionally, this command could dispatch parallel subagents (via `Agent`/Task tool) mirroring the `find_files` / `analyze_code` / `find_patterns` split documented by both Kilo and Goose (Section 2, Section 5).
- `/plan <research-file>` — reads the research doc, asks clarifying questions, proposes a phased plan with checkboxes and success criteria, writes to `thoughts/plans/YYYY-MM-DD-description.md`, and stops for human review before implementation.
- `/implement <plan-file>` — executes phase-by-phase in a **fresh session**, updating checkboxes as it goes, running tests/build/lint as a blocking gate after each phase (Section 4).

This is a direct, low-effort port of the pattern documented in Sections 2-5; nothing about it is Claude-Code-specific beyond the file/command mechanics.

**Existing repo overlap worth noting.** This repository (`my-agents`) already has a related split described in its own README: `skills/me-draft` for "planning & design exploration before implementation" and `skills/me-craft` for "craftsman-driven code → test → commit cycles" (see `/Users/duy.ton/Documents/Workshop/my-agents.feat-rpi/README.md`). That is a two-phase analog of RPI's Plan+Implement, but it currently has no explicit standalone Research phase artifact (a `thoughts/research/*.md` step) — it appears `me-draft` may currently fold research and planning together. **I don't know** the internal contents of `me-draft/SKILL.md` since it wasn't fetched as part of this task; if the goal is to adopt RPI faithfully, that file is the place to check whether Research is already a distinct sub-step or would need to be split out.

**When to invoke the full ceremony vs. skip it.** Every source examined agrees on the same shape of guidance, worth restating plainly since it is the single most actionable finding for a solo engineer:
- **Use full RPI** for: multi-file refactors, migrations, feature additions spanning several files, large upgrades, incident cleanup, documentation overhauls — anything "brownfield" where getting the existing system's shape wrong is the primary risk (Sections 2, 5; [Kilo Code RPI docs](https://path.kilo.ai/introduction/patterns/rpi/), [Goose docs](https://goose-docs.ai/docs/tutorials/rpi/)).
- **Skip it** for single-file changes, obvious/contained bug fixes, and small tasks — the ceremony becomes pure overhead rather than risk reduction (Sections 2, 5; also confirmed by the third-party `mmanzini/rpi-methodology` writeup: "For complex multi-file changes, this trade-off pays off. For single-file fixes, it's overhead." [mmanzini/rpi-methodology README](https://github.com/mmanzini/rpi-methodology/blob/main/README.md)).
- **Skip or adapt heavily** for greenfield work — RPI's Research phase assumes there's an existing system to document; Horthy (HumanLayer's creator) states this explicitly as a known limitation (Section 1; [LinearB Blog](https://linearb.io/blog/dex-horthy-humanlayer-rpi-methodology-ralph-loop)).

This maps directly onto the repo's own operating rules already in force: `rules/decision-gates.md`'s Scope and Reversibility gates are effectively the same triage RPI is encoding for engineering work specifically — a change that's local and cheaply reversible doesn't need Research/Plan ceremony; a change with wide blast radius or that's hard to undo does. RPI can be read as `craft-style.md`'s "blast radius" and "structural judgment" checkpoints made into concrete file artifacts, rather than a separate methodology to reconcile against them.

**What to weigh before adopting wholesale.** Two considerations from the research, both worth being explicit about rather than glossing over:
1. **HumanLayer itself has moved past RPI.** Per Section 1, HumanLayer's own current recommendation is CRISPY, a 7-stage successor, because RPI in practice led teams to stop reading generated code and plans became too complex to review — the exact failure mode a solo engineer should watch for even at small scale (an RPI plan doc becoming a rubber-stamp instead of a real review): [ZenML LLMOps Database — Evolution from RPI to CRISPY](https://www.zenml.io/llmops-database/evolution-from-rpi-to-crispy-multi-stage-workflow-for-production-coding-agents). For a solo engineer, adopting RPI's core discipline (separate context per phase, human review at Research and Plan, blocking test gates at Implement) captures most of the value without needing the full 7-stage CRISPY apparatus, which HumanLayer designed for team-scale review problems (2,000-line daily PRs) that don't apply to solo work.
2. **Command-name ambiguity across tools.** Section 5 found a real, unresolved discrepancy between what Kilo's docs say Goose's commands are named (`/research`, `/plan`, `/implement`, `/iterate`) versus what Goose's own docs say (`/research_codebase`, `/create_plan`, `/implement_plan`, `/iterate_plan`). Since this repo would define its own Claude Code slash commands from scratch anyway, this ambiguity is moot for implementation — but it's a reminder not to copy exact command syntax from secondary sources without checking the primary tool's current docs.

**Suggested minimal starting point.** Given `decision-gates.md` already exists in this repo and does similar triage work: rather than building a rigid 3-command RPI system immediately, the lower-risk first step is a single `/research` command (cheapest to build, highest leverage per Section 1's "human review at Research and Planning provides highest leverage against downstream errors") paired with the existing `me-draft` skill for planning, and only formalizing `/implement` as a separate fresh-session command once real usage shows the Boy Scout/blast-radius judgment calls in `craft-style.md` aren't already covering the same ground.
