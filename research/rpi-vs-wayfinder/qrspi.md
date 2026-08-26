# QRSPI Approach

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
> Every claim needs a source. Every source needs a clickable URL inline.
> Do NOT collect sources at the end -- put them inline with the facts.
>
> If, after genuine effort, you cannot find a defined framework/methodology literally named "QRSPI" (or a very close variant), do NOT invent or guess a plausible-sounding definition. Instead: (a) report clearly in Section 1 that no such named framework was found, (b) list the closest real things you DID find (e.g. similarly-named or similarly-shaped frameworks, expansions of the acronym you found evidence for, or note if it appears to be a typo/variant of a known framework like RPI or CRISPY), and (c) set Status to COMPLETE with that honest null result rather than fabricating content.
>
> When you are DONE, change "Status: IN PROGRESS" to "Status: COMPLETE" at the top.

---

## 1. What Is QRSPI? (Existence Check & Origin)

**Existence confirmed, but with an important caveat: QRSPI is not one single canonical, centrally-published framework (unlike RPI, which HumanLayer/Dex Horthy own and document). It is a community-coined name/acronym for an extension pattern on top of RPI, implemented independently as several GitHub repos/Claude Code skills, each with slightly different phase lists.** Initial web search: [WebSearch: "QRSPI" framework methodology](web search, 2026-08-26) surfaced multiple independent GitHub repositories using the QRSPI name.

Repos found so far (to be verified individually):
- [jaeyunha/QRSPI-workflow](https://github.com/jaeyunha/QRSPI-workflow) — states explicitly: "This methodology is based of QRSPI workflow. (Question -> Research -> Spec/Design -> Plan -> Implement)"
- [earlmundorf/rice-qrspi](https://github.com/earlmundorf/rice-qrspi) — description: "QRSPI: a stack-neutral, config-driven ticket workflow skill for Claude Code — Ticket → Research → Design → Structure → Plan → Implement → Validate."
- [matanshavit/qrspi](https://github.com/matanshavit/qrspi) — description: "QRSPI — 8-phase workflow for Claude Code: Question, Research, Structure, Plan, Implement" (note: description lists only 5 names for an "8-phase" workflow — needs verification of the full phase list from the README).
- [dfrysinger/qrspi-plus](https://github.com/dfrysinger/qrspi-plus) — "A structured agentic development pipeline for Claude Code — extends QRSPI with worktree parallelization, tiered reviews, integration verification, acceptance testing, and replanning" — this is explicitly a fork/extension of a pre-existing QRSPI, implying QRSPI itself predates this repo.
- [kmhalvin/openspec-schemas](https://github.com/kmhalvin/openspec-schemas/blob/main/openspec/schemas/qrspi/README.md) — has a `qrspi` schema directory, suggesting QRSPI is being treated as a semi-standardized workflow schema in at least one other project.

**VERIFIED via direct primary-source fetch** of [jaeyunha/QRSPI-workflow README](https://github.com/jaeyunha/QRSPI-workflow/blob/main/README.md):

- QRSPI = **Questions, Research, Spec/Design, Plan, Implement**.
- It is presented as an evolution of **RPI** (Research, Plan, Implement) — the HumanLayer/Dex Horthy framework — "inspired by Dex Horthy's talk on why monolithic AI coding prompts fail and how to fix them."
- **Important honesty note from the source itself**: the repo author explicitly states this is an **unofficial, community implementation** — "the HumanLayer team has not yet open-sourced their own version" of QRSPI. So even the most detailed primary source found is a third-party's interpretation/build, not an official HumanLayer-published spec.
- Named attributions in the doc: methodology credited to Dex Horthy and the HumanLayer team; the "12 Factor Agents" concept credited to Dex Horthy; "instruction budget" research credited to "Kyle (HumanLayer)".

**Conclusion for Section 1**: QRSPI is a real, documented, named pattern in circulation among AI-coding-workflow enthusiasts — but it exists as multiple independent, non-identical community implementations (see repos below), not as one canonical spec from a single authority. Treat "QRSPI" as a family of RPI-derived workflows sharing a name and a core idea (split monolithic AI planning prompts into small, human-reviewable, sequential stages with fresh context per stage), rather than a single fixed methodology. This is analogous to how "RPI evolved into CRISPY at HumanLayer" per the task brief — QRSPI appears to be a **parallel/independent community fork of RPI**, not the same lineage as CRISPY, and not (per available evidence) authored or endorsed by HumanLayer itself.

**Official-vs-community check (search: [`site:github.com humanlayer QRSPI`](web search, 2026-08-26))**: The [HumanLayer GitHub organization](https://github.com/humanlayer) (21 repos, includes [humanlayer/rpi-coordination-template](https://github.com/humanlayer/rpi-coordination-template) for their **RPI** workflow) does **not** appear to have any repo literally named QRSPI or using that term in an official capacity. Every direct hit for "QRSPI" traces back to third-party repos (jaeyunha, earlmundorf, matanshavit, dfrysinger, kmhalvin). The jaeyunha README states this outright: "the HumanLayer team has not yet open-sourced their QRSPI workflow" — i.e., even the community authors describe QRSPI as their own extrapolation from Dex Horthy's public talks/essays, not a framework HumanLayer itself shipped or named. **This is the single most load-bearing fact in this research**: QRSPI is a community-coined name for a pattern inspired by (but not published by) HumanLayer.

**Talk citation check (search: [`"Everything We Got Wrong About Research-Plan-Implement" Dexter Horthy`](web search, 2026-08-26))**: The talk is real — a keynote by Dexter Horthy (HumanLayer) at the "Coding Agents Conference," Computer History Museum, **March 3, 2026** ([YouTube](https://www.youtube.com/watch?v=YwZR6tc7qYg), also covered by [Podwise](https://podwise.ai/episodes/7669928) and referenced on [X/dexhorthy](https://x.com/dexhorthy/status/2033980488688541696)). Content per search-engine summary (not yet directly transcript-verified): RPI hit three failure modes at scale — instruction budget overflow, "magic word" dependencies, and a "plan-reading illusion" — and Horthy's proposed refinement is described in one summary as **"CRISPI (or QRSPI in some references)"** involving stages like Questions, Research, Design, Structure, Implement. **This is a significant new finding: it suggests "QRSPI" and the task brief's "CRISPY" may be garbled/alternate renderings of the same underlying Horthy talk/proposal (CRISPI vs. CRISPY vs. QRSPI), rather than fully separate lineages as tentatively concluded above.** This needs one more direct-source check before treating it as settled — see next entry.

A directly relevant secondary source also surfaced: [**"From RPI to QRSPI: Rebuilding the First Structured Workflow for Coding Agents"**](https://alexlavaee.me/blog/from-rpi-to-qrspi/) — a practitioner blog post whose title matches this research's exact question. **VERIFIED via direct fetch, and this resolves the open question above**: this source states outright, "The framework is also referred to as **CRISPY** in the article, though **QRSPI** appears to be the technical acronym," and cites a YouTube talk titled **"CRISPY / QRSPI Framework Talk."**

**REVISED CONCLUSION (supersedes the earlier "parallel/independent lineage" hypothesis above)**: QRSPI and CRISPY appear to be **the same underlying framework/proposal from Dex Horthy's March 2026 talk, known by two different names in different coverage** — QRSPI being the more literal phase-initial acronym (Questions-Research-...-Plan-Implement, sometimes extended to 7-8 stages), CRISPY being an alternate/informal name used in at least one piece of coverage for what looks like the identical 8-phase structure. This directly contradicts this research task's framing premise (that QRSPI "might be related, might not be" to CRISPY as a separate thing from RPI's HumanLayer evolution) — the evidence gathered here says they are very likely the **same** thing, not a separate fork. Caveat: this equivalence rests on one secondary blog post's characterization ("also referred to as CRISPY") plus the video title "CRISPY / QRSPI Framework Talk" — not on a HumanLayer-authored primary text using both terms side by side, so it should be flagged to whoever is researching CRISPY separately for cross-check rather than treated as fully closed.

Per this source's 8-phase breakdown (Questions → Research → Design Discussion → Structure Outline → Plan → Work Tree → Implement → Pull Request), attributed directly to Dex Horthy (CEO, HumanLayer, YC F24) as the successor to his own RPI framework — this is the closest thing to an "official-adjacent" account found in this research pass, since it traces to Horthy's own talk rather than a third party's independent guess. It still is not a HumanLayer-published repo/doc, only third-party coverage of his talk.

## 2. Phases / Steps

**Primary variant — [jaeyunha/QRSPI-workflow](https://github.com/jaeyunha/QRSPI-workflow/blob/main/README.md) (5 phases):**

| # | Phase | Slash Command | Input | Output |
|---|-------|---------|-------|--------|
| 1 | Questions | `/qrspi_questions` | Ticket/task | 5–12 research questions |
| 2 | Research | `/qrspi_research` | Questions only (ticket deliberately hidden) | Facts-only research document |
| 3 | Spec/Design | `/qrspi_design` | Ticket + research doc | ~200-line design document |
| 4 | Structure | `/qrspi_structure` | Ticket + research + design | ~2-page outline with vertical, testable implementation slices |
| 5 | Plan | `/qrspi_plan` | All prior artifacts | Full tactical implementation plan |

Note the acronym "QRSPI" (5 letters) covers Questions/Research/Spec-Design/Plan/Implement, but the table above lists 5 *planning* phases ending at "Plan" — actual "Implement" execution is a separate step after the plan artifact exists (implementation itself isn't a slash command in this repo's table, consistent with QRSPI being fundamentally a *planning* discipline, same as RPI, with execution being where the plan gets carried out).

**Other variant — VERIFIED via direct fetch: [earlmundorf/rice-qrspi](https://github.com/earlmundorf/rice-qrspi)**:
- QRSPI here = **Q**uestion → **R**esearch → **D**esign → **S**tructure → **P**lan → **I**mplement → **V**alidate — 7 stages (note the letters don't map 1:1 to the acronym order; "D" and "S" and "V" aren't in "QRSPI" — the acronym name is retained from the base pattern even though this variant added Design/Structure/Validate as extra named stages beyond the literal 5 letters).
- Explicitly attributed to "Research-Plan-Implement (RPI) methodology created by Dex Horthy (HumanLayer)" — same lineage claim as the jaeyunha repo.
- Positioned as "a single, config-driven, stack-neutral skill" for Claude Code — i.e., a productized/generalized version, not tied to one project's conventions.
- Three human gates: after Design, after Structure, and after Validate (before PR).

**Other variant — VERIFIED via direct fetch: [matanshavit/qrspi](https://github.com/matanshavit/qrspi)**:
Confirms the "8-phase" claim with the full list: **Question → Research → Design → Structure → Plan → Worktree → Implement → PR**. (The short GitHub description only names 5 of the 8 — description was abbreviated, not wrong.)
- Attribution list is the richest found so far: builds on the original RPI methodology; cites "Advanced Context Engineering for Coding Agents" (HumanLayer repo), **"Everything We Got Wrong About Research-Plan-Implement" — attributed to Dexter Horthy, MLOps.community, March 2026** (note: this is a specific, checkable talk/article citation — not independently verified by this research pass, flagged here as a claim from the source, not confirmed firsthand), and "12 Factor Agents" (HumanLayer).
- The "Worktree" phase (creating a git worktree before Implement) is unique to this variant vs. the other two repos checked.

**Closest-to-source variant — VERIFIED via direct fetch: [alexlavaee.me blog, "From RPI to QRSPI"](https://alexlavaee.me/blog/from-rpi-to-qrspi/)**, describing Dex Horthy's own talk (8 phases, same shape as matanshavit's repo):

Alignment phases (human-reviewed, sequential):
1. **Questions** — identifies gaps in agent knowledge via targeted inquiry
2. **Research** — gathers objective codebase facts; feature ticket is hidden during this phase (same anti-bias design as every other variant checked)
3. **Design Discussion** — agent "brain dumps" its understanding; human does "brain surgery" to redirect toward correct patterns (Horthy's own metaphor per this source)
4. **Structure Outline** — defines signatures, types, high-level phases; enforces vertical slices
5. **Plan** — tactical implementation document

Execution phases:
6. **Work Tree** — organizes tasks into a hierarchy based on the vertical slices
7. **Implement** — agent writes the code
8. **Pull Request** — human review and ownership

## 3. Deliverables & Artifacts Per Phase

**Verified for jaeyunha/QRSPI-workflow:**
- Convention: `thoughts/shared/tasks/ENG-XXXX-description/` directory holding numbered markdown artifacts:
  - `ENG-XXXX-01-questions.md`
  - `ENG-XXXX-02-research.md`
  - `ENG-XXXX-03-design.md`
  - `ENG-XXXX-04-structure.md`
  - `ENG-XXXX-05-plan.md`
- Each phase is meant to run in a **fresh Claude session** — critical for phase 2 (Research), where the original ticket must be hidden from context to prevent "opinion leakage" contaminating the supposedly-objective research doc.
- Rationale given for the design-doc-sized output (~200 lines): review leverage — "a 1000-line plan requires identical review effort to implementation itself, yet plans diverge from actual code," so catching problems at the smaller design-doc stage is cheaper.

**Verified for earlmundorf/rice-qrspi** ([source](https://github.com/earlmundorf/rice-qrspi)):
- Q: ticket restatement + 8–15 neutral research questions.
- R: codebase facts with file:line citations, no proposed solutions ("blind research" — ticket context excluded, same anti-opinion-leakage design as jaeyunha's variant).
- D: ~200-line design doc with Q&A and success criteria (first human gate).
- S: work divided into vertical slices with verification checkpoints (second human gate).
- P: checkboxed tactical plan with config-resolved (not hardcoded) commands.
- I: slice-by-slice implementation, one commit per slice, stops on failed checks.
- V: re-verified criteria, diff-ownership gate, PR opened only after human approval (third human gate).
- Persisted artifacts include a `findings/` notes directory intended to carry forward research for future tickets.

**Verified for the alexlavaee.me account of Horthy's talk** ([source](https://alexlavaee.me/blog/from-rpi-to-qrspi/)):
- Research phase produces "a factual record of what the code does."
- Design Discussion yields a "~200-line markdown artifact" covering current state, desired end state, and design decisions — same ~200-line convention independently corroborated across jaeyunha, earlmundorf, and matanshavit variants, suggesting this specific figure traces back to Horthy's own talk rather than being coincidental across unrelated authors.
- Structure Outline is described as resembling "a C header file" — i.e., signatures/types/interfaces without full implementation logic.

## 4. Tooling & Implementations

**Verified — [jaeyunha/QRSPI-workflow](https://github.com/jaeyunha/QRSPI-workflow)**:
- Ships as a `.claude/skills/` directory a user copies into their project (Claude Code custom slash commands).
- Integrates with HumanLayer's companion agents: `codebase-locator`, `codebase-analyzer`, `codebase-pattern-finder`.
- MIT licensed.

**Verified — [earlmundorf/rice-qrspi](https://github.com/earlmundorf/rice-qrspi)**:
- Single `working-docs/config.json` profile per project drives stack-specific behavior (build verbs, `changeTypeVerbs`, `researchLayers`, `protectedPaths`, `apiBoundary`, `jira.mode` for mcp/manual/none ticket sourcing).
- `sync-commands.sh` publishes `/cq:*` slash commands.
- Ships pre-built profiles for storefront (React/Vite), Spring Boot, and FastAPI stacks, plus example projects (`examples/fastapi-todo`, `examples/react-todo`).
- Four ceremony tiers scale process to ticket complexity: trivial, simple, full, comprehensive — i.e., not every ticket runs the full 7-stage gate sequence.

**Verified — [matanshavit/qrspi](https://github.com/matanshavit/qrspi)**:
- Deliverables: `task.md` + `questions.md` (Question) → `research.md` ~300 lines (Research) → `design.md` ~200 lines (Design) → `structure.md` ~2 pages (Structure) → `plan.md` (Plan) → git worktree (Worktree) → code changes + commits (Implement) → GitHub PR (PR).
- Required companion agents in `.claude/agents/`: `codebase-locator`, `codebase-analyzer`, `codebase-pattern-finder`, `web-search-researcher`.
- Installation: copy `.claude/commands/qrspi/` and `.claude/agents/` into project root; run via `/qrspi/` commands.

**Verified — [dfrysinger/qrspi-plus](https://github.com/dfrysinger/qrspi-plus)**:
- Describes base QRSPI as: "every phase produces a reviewable artifact, gets human approval, and runs in isolated context" — consistent with the other two verified variants.
- States the base framework is "7-8 stages depending on the source" — i.e., this repo's own documentation acknowledges QRSPI is **not standardized across sources**, corroborating the "family of implementations, not one canonical spec" conclusion in Section 1.
- **Attribution claim (third-party, not independently confirmed)**: credits QRSPI to "HumanLayer's Dex Horthy," citing conference talks, the "Advanced Context Engineering for Coding Agents" essay, YouTube presentations, plus secondary practitioner writeups/podcasts. **Caveat: this is dfrysinger's own claim about attribution, not a link to a HumanLayer-owned page that itself uses the name "QRSPI."** No source found in this research pass shows HumanLayer's own website/repo (github.com/humanlayer) using the literal term "QRSPI" — all direct evidence of the name comes from third-party repos. This distinction matters and is carried into Section 1's conclusion.
- Extends base QRSPI with 5 new phases (Goals, Phasing, Integrate, Test, Replan) plus extended/split versions of Design, Structure, Plan, and Parallelize/Implement.
- Built as a Claude Code plugin; also claims GitHub Copilot CLI compatibility; uses git worktrees, bats-core tests (442 total: 308 unit, 134 acceptance), 57 specialized reviewer agents, `gh` CLI integration for PR creation.
- [kmhalvin/openspec-schemas](https://github.com/kmhalvin/openspec-schemas/blob/main/openspec/schemas/qrspi/README.md) — has a dedicated `qrspi` schema folder, suggesting an attempt to formalize/schematize the QRSPI artifact format for tooling interop.

**Fact check on "CRISPY" (per task brief's own claim)**: search [`QRSPI Claude Code plugin skill marketplace`](web search, 2026-08-26) confirms qrspi-plus ships an actual Claude Code plugin manifest + marketplace listing config (mechanically consistent with the earlier dfrysinger findings), but surfaced no new naming information. **As established in Section 1, the weight of evidence (the alexlavaee.me source and its "CRISPY / QRSPI Framework Talk" citation) points to QRSPI and CRISPY being the *same* Horthy proposal under two names, not separate lineages** — this should be flagged to whichever other agent is researching CRISPY/RPI so the two research threads can cross-check instead of independently duplicating conclusions.

**Additional tool mentioned in the alexlavaee.me source**: "Atomic" — described there as "open-source research-to-execution for complex codebases," referenced at `github.com/bastani-inc/atomic`. Not independently fetched/verified in this pass; flagged as an unconfirmed lead, not a confirmed fact.

## 5. Practical Adoption for a Solo Engineer Using Claude Code

Based on the four independently-verified implementations above (jaeyunha, earlmundorf, matanshavit, dfrysinger) plus the closest-to-source account (alexlavaee.me / Horthy's talk), here is what a solo engineer can reasonably take from QRSPI:

**What's consistent across every variant checked (safe to adopt as-is):**
- Split a non-trivial ticket into small, sequential, human-reviewed artifacts rather than one giant planning prompt — every source cites the same root problem (LLM "instruction budget" exhausted by monolithic prompts, ~150-200 instructions reliably followed vs. ~85+ in a mega-prompt per jaeyunha's source).
- Keep the raw ticket **hidden** from the Research phase specifically, so the research doc stays fact-only and doesn't get contaminated by solution-shaped thinking ("opinion leakage") — this is the one mechanical trick repeated in all four repo variants and worth adopting even without the rest of the ceremony.
- A ~200-line design doc is cited independently across three sources as the sweet spot for human review leverage — small enough to actually read carefully, big enough to catch wrong assumptions before code is written.
- Run each phase in a fresh context/session where practical — Claude Code's `/clear` or a new conversation per phase approximates this without needing any specific plugin.

**What varies and requires a pick, not a "the" framework to follow verbatim:**
- Phase count ranges 5 (jaeyunha) to 7 (earlmundorf) to 8 (matanshavit, and Horthy's own talk per alexlavaee.me). The 8-phase version (Question → Research → Design → Structure → Plan → Worktree → Implement → PR) is the one that traces closest to Horthy's own talk, so it's the most defensible one to imitate if the goal is "do what QRSPI's originator described," but it's also the heaviest.
- Config-driven, multi-stack tooling (earlmundorf's `working-docs/config.json`, ceremony tiers) is aimed at teams/multi-project use — for a **solo engineer on one repo**, this is likely over-engineering; the lighter jaeyunha-style flat `.claude/skills/` directory with plain markdown task folders is more proportionate.

**Concrete adoption path for this repository (my-agents), given this repo's own existing conventions** (per `/Users/duy.ton/Documents/Workshop/my-agents.feat-rpi/CLAUDE.md` and `README.md`, this repo already distinguishes Skills = interactive/human-facing vs. Agents = programmatic, and already has an `me-draft` skill for "planning & design exploration before implementation" and an `me-craft` skill for "code → test → commit cycles"):
1. QRSPI's phase-by-phase artifact pattern is not a wholesale replacement for `me-draft`/`me-craft` — it's a more granular internal structure that could inform how `me-draft` organizes its own working notes (e.g., adopting the "hide the ticket during research" trick, and a fixed small-artifact-per-stage convention under a `thoughts/`-style directory) rather than importing an entire separate 5-to-8-phase skill wholesale.
2. Given this repo's stated Skill-vs-Agent split, the cleanest fit (if adopted at all) would be a lightweight addition to `me-draft`'s existing workflow phases, not a new top-level `/qrspi` skill — avoids duplicating an already-similar skill and keeps the one-skill-per-job structure this repo already follows.
3. Given this is a **solo** engineer context (not a team needing config-driven multi-stack tiers, human approval gates for *other people*, or PR review by teammates), the multi-repo tooling in earlmundorf/matanshavit/dfrysinger (config profiles, 57 reviewer agents, worktree parallelization, bats-core test suites) is disproportionate ceremony for the stated use case. The two ideas actually worth lifting are: (a) hide-the-ticket-during-research, and (b) a hard artifact-size ceiling (~200 lines) as a self-imposed design-doc discipline before touching code — both are cheap, mechanical, and don't require adopting anyone's full plugin.
4. **Limitation/uncertainty flag**: none of the QRSPI repos found have visible adoption metrics (stars, forks, issue activity) captured in this research pass — this document cannot state how widely used or battle-tested any specific QRSPI variant is beyond "several independent people built one." Treat adoption as "early/niche community pattern," not an established industry standard, when deciding how much process overhead to take on.

---

**Note on scope boundary**: per the task brief, RPI (HumanLayer's baseline) and Matt Pocock's wayfinder/prototype skills are being researched separately by other agents and are intentionally out of scope here beyond the attribution context needed to place QRSPI. The CRISPY-vs-QRSPI naming overlap flagged in Section 1 should be cross-checked against whatever that other research finds about CRISPY specifically.
