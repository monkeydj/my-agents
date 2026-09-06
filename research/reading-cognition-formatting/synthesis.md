# Synthesis: Readability & Visual Comprehension Rules for ghostwriter.md

**Status:** COMPLETE
**Last updated:** 2026-09-04

---

## Scope note

This synthesis feeds a proposed *readability/structure* addition to
`agents/ghostwriter.md`. It does not touch that file's Voice Profile,
Anti-Patterns table, Per-Medium Rules, or Length section — those are owned
separately. Every proposed rule below is additive or a targeted refinement,
checked against the existing file so nothing here duplicates or contradicts
what already exists.

Source files read in full: `cognitive-load.md`, `visual-structure.md`,
`applied-standards.md` (all `Status: COMPLETE`), and `agents/ghostwriter.md`
(current, unmodified).

---

## 1. Executive Summary

- **Sentence length converges on 15–20 words average, ~25-word ceiling** across independent lineages (US federal plain language, GOV.UK, Flesch-Kincaid weighting, the American Press Institute comprehension curve). This is the single most operationalizable number for a formatting rule, but the underlying readability formulas were shown in a 2025 study to be weak predictors of actual reading ease — treat the number as a heuristic proxy, not a guarantee.
- **Front-loading/BLUF is the strongest cross-cutting finding**, not because of one big study but because four independent institutional lineages (US federal plain language, GOV.UK, Google, Microsoft) converge on "put the important word/idea first" at four different zoom levels: sentence, paragraph, heading, and document. Convergent validity across unrelated sources is stronger evidence here than any single number.
- **Bullets vs. prose is conditional, not a blanket "bullet more" instruction** — bullets measurably help recall of genuinely parallel, homogeneous items (steps, discrete facts) but a peer-reviewed 3-experiment study found bulleting *hurts* recall of the surrounding non-bulleted prose, and bullets structurally strip the connective words that carry causal/argumentative logic. This is the highest-value refinement for ghostwriter.md, which currently has no explicit bullets-vs-prose decision rule.
- **Headers are primarily retrieval/navigation aids, not guaranteed comprehension boosters** for a document read once, linearly, start to finish — which describes most of what ghostwriter drafts (Slack, status updates, MR replies). Headers matter most for reference material a reader revisits (Confluence pages, RFCs), which is already where ghostwriter's current Per-Medium Rules put them.
- **Bold/emphasis works by contrast, and contrast is a spendable budget** — overuse causes "emphasis fatigue," mechanistically the same as eye-tracking-validated banner blindness (increased workload, degraded search, and worse recall of the over-emphasized content itself). This backs up, rather than changes, the direction ghostwriter/prima-flint already lean (reserve emphasis for the genuinely exceptional).
- **No direct L2/non-native-reader study was found in any of the three source files.** The closest proxy is GOV.UK's accessibility data (5–8 word sentences understood without difficulty by people with moderate learning disabilities) and ISO 24495-1's framing that plain-language thresholds should calibrate to the audience's prior knowledge, not a fixed universal number. This is noted as an inference in Section 2, not asserted as a finding — flagging per the "don't force a connection that isn't there" instruction.

---

## 2. Key Findings by Theme

### Sentence and paragraph length thresholds

- American Press Institute comprehension curve: **8 words ≈ 100% comprehension, 14 words ≈ 90%, 43+ words ≈ <10%**. Widely cited, but no independently locatable primary study — treat as a directional industry benchmark, not a peer-reviewed figure. *(cognitive-load.md §3)*
- US Federal Plain Language Guidelines: average **15–20 words/sentence**, general target to stay under 20. *(applied-standards.md §1, cognitive-load.md §5)*
- GOV.UK content design: **5–8 words** understandable without difficulty by readers with moderate learning disabilities; **~25 words** as an aspirational upper bound using plain words, not a hard cap. *(applied-standards.md §1)*
- 20-word threshold commonly used as the practical "long sentence" cutoff in accessibility/plain-language style guides. *(cognitive-load.md §3)*
- Readability formulas (Flesch-Kincaid, Gunning Fog, SMOG, Coleman-Liau, Dale-Chall) all treat sentence length as a core input — convergent evidence that length matters — but a 2025 arXiv study found these formulas (and LLM-based estimators) are **poor predictors of actual reading ease** against real reader outcomes. Use as heuristic, not proof. *(cognitive-load.md §3)*
- Gibson's Dependency Locality Theory: a syntactic working-memory ceiling of roughly **4 unresolved grammatical dependencies** before a sentence becomes unprocessable (center-embedding, long subject-verb distance) — independently converges with Cowan's ~4-chunk limit below, from an entirely separate research tradition (sentence parsing vs. general working memory). *(cognitive-load.md §1)*
- Paragraphs: the reliable test is **one idea, summarizable in one sentence** — more reliable than any word-count rule. Context-dependent norms: academic/long-form ~5–8 sentences (100–200 words); web/scanning content ~2–4 sentences (40–70 words); CDC caps at 5 sentences; other plain-language guides recommend 2–3 sentences for public material. *(cognitive-load.md §4, applied-standards.md §1)*

### Chunking / working-memory limits

- Miller's "7±2" (1956) is the popular figure but was self-described as rough/rhetorical. Cowan's 2001 reanalysis found the real limit, once rehearsal and grouping tricks are controlled for, is closer to **~4 chunks**. *(cognitive-load.md §2)*
- What counts as "one chunk" depends on the reader's expertise (chess masters chunk 20+ pieces into ~5 groups) — this is the mechanistic link back to ISO 24495-1's audience-dependent framing (Section 2, "sentence/paragraph length"). *(cognitive-load.md §2)*
- Practical translation: cap each sentence/paragraph at roughly **4 new interdependent facts** before the reader must resolve them — this is a chunk-count rule, not a word-count rule, and is the mechanism behind why "one idea per sentence/paragraph" works.
- List length: Microsoft's style guide recommends **2–7 items** per list, sized so a reader sees at least 2–3 at a glance without scrolling. *(applied-standards.md §3)*
- Nesting depth: no direct study on comprehension-vs-nesting-depth was found. The inference (3+ levels likely defeats the chunking benefit, because sub-items must be held together with their parent instead of independently) is reasoned from Miller/Cowan capacity limits, not a cited experiment — flagged explicitly as inference in the source file. *(applied-standards.md §5)*

### Headers as retrieval aids

- The **strongest, most consistent effect** of headings is on retrieval/relocation — readers who could answer "where is X" questions used heading structure to find answers reliably better than readers given the same text without headings. *(visual-structure.md §2)*
- The effect on raw first-pass comprehension is more conditional: headings can **bias what's remembered** toward heading-flagged content rather than uniformly improving depth of understanding. A vague or inaccurate heading actively misdirects recall — it's not a neutral label. *(visual-structure.md §2)*
- The "layer-cake" scanning pattern (fixate on headings/subheadings, dip into body text) is NN/g's most effective scan mode — but it **only emerges when headings are specific, descriptive, and visually distinct**; vague or decorative headers collapse the pattern back into unproductive F-shaped skimming. Heading quality, not heading presence, is the lever. *(visual-structure.md §1)*
- Front-load the highest-information word in a heading — the working assumption in NN/g's research is that a scanning reader absorbs only the **first ~2 words** of a heading. *(applied-standards.md §2)*
- Structural rules with cross-guide convergence (Google + Microsoft, independently): strict heading hierarchy with no skipped levels, unique/descriptive headings, never an empty heading, sentence case not Title Case. *(applied-standards.md §3)*

### Bullets vs. prose — the connective-tissue distinction

- Bullets measurably help **recall and processing speed for genuinely parallel, homogeneous items** (steps, discrete facts, options) — one industry source claims ~25% faster reading in bullet form (not peer-reviewed, treat as directional). *(visual-structure.md §3)*
- This benefit **shrinks or reverses when items are heterogeneous** (not truly parallel in kind). *(cognitive-load.md §6)*
- Peer-reviewed, 3-experiment study (John Benjamins): bulleting the listed items can improve recall of *those items* while simultaneously **hurting recall of the surrounding non-bulleted prose** — converting everything to bullets is not a free win. *(visual-structure.md §3, cognitive-load.md §6)*
- Mechanism: bullets strip connective words ("but," "and," "so," "because") that in prose encode *how* ideas relate — causal, contrastive, sequential. A list of causally-linked facts rendered as parallel bullets reads as if the items were independent, when they aren't. *(visual-structure.md §3)*
- **The decision test**: do these items relate causally/sequentially (keep in prose, or use a numbered list if strictly sequential), or are they atomic and independently true (bullet them)? This directly parallels prima-flint's own Register Ladder necessity test ("would full sentences add connective meaning here?") — the same test, applied to a different register decision.
- GOV.UK: one idea and one sentence per bullet; if a point needs more than one sentence, use a heading + paragraph instead of forcing it into a bullet. *(applied-standards.md §1)*

### Whitespace

- A "wall of text" is perceived as harder *before* a single word is read — a pure perception effect, independent of actual content difficulty. *(visual-structure.md §4)*
- Reported: increased margin whitespace correlated with ~20% higher comprehension (secondary/industry citation, not independently verified against a primary study — flag as directional). *(visual-structure.md §4)*
- Mechanism ties directly to working-memory capacity: whitespace/paragraph breaks are consolidation points where germane load (understanding) can convert into long-term schema before more load is added. *(cognitive-load.md §4, visual-structure.md §4)*
- Whitespace/chunking serves both skimmers (faster location) and close readers (lower load per chunk) simultaneously — not a tradeoff between the two reading modes.

### Tables vs. prose

- Strongest primary-study evidence in the whole research set: a **pre-registered RCT** ("fact boxes," 2,300+ participants, multiple medical topics, 6-week follow-up) found tabular presentation of comparative/numerical risk data produced better immediate comprehension *and* better 6-week recall than the same content in prose — held across numeracy/education levels. *(visual-structure.md §5)*
- Tables win specifically for **comparative, numerical content across shared attributes** — the same working-memory bottleneck bullets solve (holding values across sentences to compare them) is what tables solve for numbers.
- Tables strip relational/causal language the same way bullets do — bad fit for narrative, explanatory, or causal content.
- **Split-attention cost**: a table plus surrounding prose that references it forces the reader to cross-reference between two visual locations — a real cognitive tax, not free scaffolding. A table immediately followed by prose that just restates its cells is pure redundancy. *(visual-structure.md §5)*
- Decision test: is the content fundamentally comparative/numerical (multiple items scored across the same attribute set)? Table. Otherwise, prose.

### Bold / emphasis economy

- Emphasis works only by **contrast** with its surroundings — visual salience theory. Bolding one word in an otherwise plain paragraph draws the eye; bolding half of every paragraph removes the contrast that made it work, and "emphasizes nothing, since everything is emphasized." *(visual-structure.md §6)*
- Mechanism-equivalent evidence from peer-reviewed, eye-tracking-validated banner-blindness research: overused visual patterns get tuned out by the reader's attention system, and the effect **backfires on both the task at hand and on recall of the over-emphasized content itself**. *(visual-structure.md §6)*
- The cost compounds: each additional bold span in a document makes every other bold span less effective, it doesn't stay flat.
- Rule implication already directionally consistent with ghostwriter/prima-flint's existing posture (reserve emphasis for security warnings, irreversible-action confirmations, genuinely critical content) — this research gives that existing posture an empirical mechanism, it doesn't change the posture.

### BLUF / inverted pyramid / front-loading

- BLUF's justification is the **primacy/recency effect** — a well-established general cognitive-psychology finding (content at the start and end of a message is retained better than content in the middle). *(cognitive-load.md §6, applied-standards.md §4)*
- **No dedicated peer-reviewed study isolating BLUF's own effect on comprehension/cognitive load was found** — the applied-standards research explicitly flags this: BLUF-as-technique is well-established practitioner consensus applying a real psychological mechanism, not itself an RCT-validated intervention. *(applied-standards.md §4)*
- Widely-cited (but not independently verified) practitioner figure: **70% of readers stop reading after the third paragraph** — treat as directional, not peer-reviewed. *(applied-standards.md §4)*
- A 2025 *Applied Cognitive Psychology* study ("First Come, First Remembered") found text position **directly affects attention allocation and recall in digital reading specifically** — a primacy effect demonstrated in the actual reading-comprehension domain, not just general list-memory psychology. This is one of the stronger, more recent, more directly-applicable findings in the whole set. *(cognitive-load.md §4)*
- Corpus evidence: in text specifically vetted for readability (IELTS Academic Reading passages), topic sentences appear at the **start of the paragraph 60% of the time**, end 30%, middle only 10% — confirming paragraph-initial placement as the dominant pattern in text that already works. *(cognitive-load.md §4)*
- Front-loading converges independently at four levels: sentence (put the condition before the instruction — Google), paragraph (topic sentence first — Google, IELTS corpus), heading/bullet (lead word first — GOV.UK, NN/g), and document (BLUF/inverted pyramid). Four unrelated institutional lineages landing on the same structural principle at different zoom levels is the strongest form of evidence in this research set — stronger than any single quantified number. *(applied-standards.md §3, §4 cross-cutting synthesis)*

### L2 / non-native-reader relevance (flagged, not forced)

- None of the three source files located a study specifically on L2/non-native English readers' comprehension.
- The closest available proxies: GOV.UK's accessibility figures (5–8 word sentences for readers with moderate learning disabilities) and ISO 24495-1's principle that "understandability" is an audience-calibrated outcome (first-read comprehension for *this* audience), not a fixed universal word count — and that a reader's prior/domain knowledge (intrinsic load) changes how hard a given sentence is to process. *(cognitive-load.md §5)*
- This is an **inference**, not a finding: a non-native reader plausibly carries somewhat higher intrinsic load per sentence of equivalent objective complexity, which would argue for erring toward the lower end of the 15–20 word sentence-length range rather than the ~25-word ceiling — but no study in the source material tested this directly. ghostwriter.md's Voice Profile identity line ("Vietnamese high-intermediate English") is about *voice naturalness*, not comprehension accessibility, and this synthesis does not recommend touching that line — it is flagged here only because the task asked to note if anything bears on it.

---

## 3. Contradictions or Tensions Found

1. **Sentence-length numbers disagree across sources, but not irreconcilably.** The API comprehension curve implies near-total comprehension only below ~14 words; federal plain language targets a 15–20 word average; GOV.UK allows an aspirational ceiling of ~25. These are different statistics (a comprehension-rate curve vs. an average vs. an upper bound), not a real contradiction — but a rule needs one operational number. Resolution used below: **15–20 words as the average target, ~25 as a hard-flag ceiling**, matching applied-standards.md's own cross-cutting synthesis.

2. **"Add more structure" pulls against ghostwriter's existing "no padding" / "never over-polish" anti-patterns.** Headers, tables, and BLUF framing are visual/structural apparatus, not word-count padding — but a Slack message or short ask that gains headers or a table it didn't need before would read as over-engineered, which is exactly the failure mode the existing Anti-Patterns table (`Padding a document to length`, `Multiple polish passes`) already guards against. **Resolution: scope all new structural rules to longer mediums** (Confluence, reports, RFCs, proposals) and explicitly exclude Slack/short asks/MR replies, which are already governed by the Length table and should not gain apparatus they don't currently have.

3. **Bullets-help vs. bullets-hurt-surrounding-prose is a real tension, and it cuts against a naive "bullet more" instinct.** The peer-reviewed finding that bulleting reduces recall of nearby non-bulleted prose is direct evidence *against* over-bulleting — meaning a readability rewrite done carelessly (mechanically converting more content to bullets) would work against the very research being used to justify it. This validates ghostwriter's current casual-prose-first Slack style rather than arguing for changing it.

4. **Headers-as-retrieval-aid vs. headers-as-comprehension-aid.** visual-structure.md is explicit that the comprehension benefit of headers is more conditional than the retrieval benefit. Most of what ghostwriter drafts (Slack, status updates, single-read MR replies) is read once, linearly — exactly the case where headers help least. ghostwriter's existing per-medium split (no headers in Slack; headers in Confluence) already reflects this correctly. **The recommendation is to reinforce this split, not add headers more broadly.**

5. **Shorthand register vs. "preserve connective words."** cognitive-load.md's key implication is that stripping articles/conjunctions to compress text *increases* extraneous load by forcing the reader to silently reconstruct relationships the writer removed. ghostwriter's `register: "shorthand"` override (see Input Contract) currently says only "domain shorthand assumed shared" without stating a carve-out for causal/argumentative content. prima-flint's own Register Ladder already scopes shorthand correctly (density-is-the-content only — parallel enumerations, checklists — never arguments), so this is not a contradiction in principle, but ghostwriter's own description of the override doesn't currently state that scope explicitly, which is worth tightening (Section 5, Rule 9).

6. **Readability-formula convergence vs. formula validity.** Nearly every classic readability formula uses sentence length as a core input, which is strong indirect evidence length matters — but a 2025 arXiv study found these formulas (and LLM-based estimators) are poor predictors of actual reading ease against real reader outcomes. This tempers confidence in treating any single word-count threshold as more than a heuristic proxy.

7. **No real tension, but worth flagging as confirming evidence:** GOV.UK's bullet rule (one idea, one sentence per bullet) is already the pattern ghostwriter's existing "Raising Concerns / Blockers" Slack template follows (`1. [blocker/question] — [why it matters in 1 clause]`). This is evidence the existing template is already well-formed, not a gap to fix.

---

## 4. Confidence Assessment

### Well-supported (named peer-reviewed studies, replicated, or RCT-grade)

- Cowan's ~4-chunk working-memory limit — 2001 reanalysis of decades of studies, controlling for rehearsal/grouping confounds. *(cognitive-load.md §2)*
- Gibson's Dependency Locality Theory (~4 unresolved-dependency ceiling) — published psycholinguistics research (MIT). *(cognitive-load.md §1)*
- NN/g F-pattern eye-tracking study (232 users, original 2006; replicated/updated 2017). *(visual-structure.md §1)*
- NN/g layer-cake scanning pattern — eye-tracking based. *(visual-structure.md §1)*
- Headings-as-retrieval-aid research (PubMed-indexed heading-processing studies; Reading Research and Instruction). *(visual-structure.md §2)*
- Bulleted-list recall study — 3-experiment, peer-reviewed (John Benjamins): homogeneous-item benefit, surrounding-prose cost. *(visual-structure.md §3)*
- Fact-boxes RCT — pre-registered, 2,300+ participants, 6-week durability check (PMC). *(visual-structure.md §5)*
- Banner-blindness research — peer-reviewed, eye-tracking-validated (perceived workload increase, degraded visual search, reduced recall). *(visual-structure.md §6)*
- "First Come, First Remembered" 2025 *Applied Cognitive Psychology* study — text-position effect on attention/recall in digital reading specifically. *(cognitive-load.md §4)*
- Miller (1956) / Cowan (2001) as foundational working-memory capacity research.

### Practitioner-convention / industry-source / unreplicated (flag as directional, not proof)

- American Press Institute 8/14/43-word comprehension percentages — widely repeated, no independently locatable primary study. *(cognitive-load.md §3)*
- "~25% faster reading in bullet form" — SEO/industry source (Yoast). *(visual-structure.md §3)*
- "~20% comprehension improvement from margin whitespace" — secondary citation, primary source not independently confirmed. *(visual-structure.md §4)*
- "70% of readers stop after the third paragraph" and "70% of bulleted lists get read" — web-content-strategy benchmark, uncited primary study. *(applied-standards.md §4)*
- BLUF-as-technique itself — the primacy/recency *mechanism* is well-established psychology; BLUF as an applied writing technique has no dedicated RCT found. *(applied-standards.md §4)*
- Nesting-depth thresholds (3+ levels defeats chunking) — reasoned inference from Miller/Cowan capacity, not a directly studied nesting-depth experiment; the source file itself flags this as inference. *(applied-standards.md §5)*
- Federal Plain Language Guidelines (15–20 words) and GOV.UK figures (5–8, ~25 words) — institutional standards backed by agency practice and accessibility-testing lineage, a notch more credible than a pure blog claim, but not themselves controlled experiments. Treat as strong practitioner consensus.
- Flesch-Kincaid-family readability formulas — long-established and mechanically sound, but a 2025 arXiv study found them (and LLM-based estimators) to be poor predictors of actual reading ease against real reader outcomes. *(cognitive-load.md §3)*

---

## 5. Concrete Rules Mapped to ghostwriter.md

Each rule below states what to add/change, exactly where in `agents/ghostwriter.md`, and its source. None of these touch Voice Profile's tone content, the Anti-Patterns table's existing rows, Per-Medium Rules' voice/structure content, or the Length section's numbers — only readability/structure is added or refined.

**Rule 0 — scope guard (apply before any rule below).** State explicitly, wherever the new material is added, that headers/tables/BLUF-structure rules apply to longer mediums (Confluence, report, proposal, RFC, blog post) and not to Slack, Jira comments, or MR replies, which are already governed by the existing Length table. Prevents Contradiction #2 (Section 3) — new structure rules must not read as license to add apparatus to short comms.
*Target:* opening line of a new top-level section (see Rule 3 below).
*Source:* applied-standards.md §5 cross-cutting synthesis point 3; ghostwriter.md's own Anti-Patterns row `Padding a document to length`.

**Rule 1 — sentence length guidance.**
Add: "Target 15–20 words per sentence on average; flag/split sentences over ~25 words, and always split sentences with 3+ stacked subordinate clauses regardless of word count (a Gibson-style embedding problem, not just a length problem)."
*Target:* new bullet under Voice Profile's **Structure** line, or a new small subsection directly beneath it (e.g. "**Sentence length:**").
*Source:* cognitive-load.md §§3, 5; applied-standards.md §1.

**Rule 2 — paragraph structure (topic-sentence-first).**
Add: "Each paragraph opens with its main point; supporting detail follows. One idea per paragraph — if the paragraph's point needs two sentences to summarize, it should be two paragraphs." Note explicitly that ghostwriter's existing Slack structure (`context → what I'm doing → what I need from you`) is already this pattern at the message level — this rule extends the same logic to the paragraph level inside longer documents.
*Target:* refinement to Voice Profile's **Structure** line (add one clause) plus a new sentence under the "Longer documents" bullet in the **Length** section.
*Source:* cognitive-load.md §4 (topic-sentence placement, IELTS corpus); applied-standards.md §3 (Google's paragraph-structure rule).

**Rule 3 — new top-level section: "Readability Structure."**
Add a new top-level section, positioned after **Voice Profile** and before **Anti-Patterns**, holding Rules 4–8 below plus the Rule 0 scope guard. Rationale for placement: it's a structural complement to voice (how the words are arranged, not what they sound like), and it needs to sit before Anti-Patterns since one new row references it (Rule 8).

**Rule 4 — bullets-vs-prose connective-tissue test.**
Add: "Before converting content to bullets, check: do these items relate causally or sequentially (one depends on or follows from another), or are they independent and parallel (each true on its own)? Causal/argumentative content stays in prose — bullets strip the words (`because`, `so`, `but`) that carry the logic. Only bullet genuinely parallel items: steps, discrete facts, options. A numbered list is the sub-case for strictly sequential steps." Cross-reference: this is the same test as prima-flint's Register Ladder necessity check, applied to list-vs-prose instead of shorthand-vs-full-sentence.
*Target:* new "Readability Structure" section (Rule 3).
*Source:* visual-structure.md §3; cognitive-load.md §6.

**Rule 5 — header/subheader usage in longer docs.**
Add: "Headings must be specific and front-loaded with the highest-information word (a scanning reader absorbs roughly the first two words) — never a vague label. Use a strict hierarchy with no skipped levels, never leave a heading with no content under it, and use sentence case, not Title Case." This also refines **Per-Medium Rules > Confluence**, which currently says only "Use headers and bullets" with no quality criteria.
*Target:* new "Readability Structure" section (Rule 3), with a one-line pointer added under **Per-Medium Rules > Confluence**.
*Source:* visual-structure.md §§1–2; applied-standards.md §3 (Google, Microsoft).

**Rule 6 — table usage criteria.**
Add: "Use a table only when content is genuinely comparative/numerical across a shared set of attributes (multiple items, each scored the same way). Otherwise, keep prose — tables strip the same connective/causal language bullets do. Never follow a table with prose that just restates its cells; pick one." This is a usage-criteria addition — **Per-Medium Rules > Confluence** currently only specifies table *styling* (full-width, proportional columns), not when to use one at all.
*Target:* new sentence prepended to the existing **Tables** bullet under **Per-Medium Rules > Confluence**.
*Source:* visual-structure.md §5 (fact-boxes RCT).

**Rule 7 — bold/emphasis restraint.**
Add a new row to the existing **Anti-Patterns** table: `Bolding routine facts or every key term | Emphasis works by contrast — bolding more than the genuinely exceptional (a risk, a required action, a number the reader can't miss) erases the contrast that makes any of it work, and each added bold span makes every other one less effective.` This is additive to the existing table, not a change to any current row, and it gives an empirical mechanism for something ghostwriter/prima-flint already lean toward (Emphasis Escalation reserved for security warnings and irreversible actions).
*Target:* new row in the existing **Anti-Patterns** table.
*Source:* visual-structure.md §6 (banner blindness, contrast theory).

**Rule 8 — front-loading at every level, tied back into the Structure line.**
Add, in the new "Readability Structure" section: "Front-load the point at every level, not just the message level: the conclusion/ask first in the document (already ghostwriter's `context → what's changing → what I need` pattern), the topic sentence first in each paragraph (Rule 2), the highest-information word first in each heading (Rule 5), and the condition before the instruction in a sentence (e.g. `If X, do Y`, not `Do Y if X`)." This explicitly names the existing Voice Profile Structure line as the document-level instance of the same principle, so the addition reads as an extension, not a new competing idea.
*Target:* new "Readability Structure" section (Rule 3), with a one-clause cross-reference added to the existing **Structure** line in Voice Profile ("this ordering is BLUF — see Readability Structure for how the same principle applies inside paragraphs and headings").
*Source:* applied-standards.md §§3–4 cross-cutting synthesis (four-lineage convergence); cognitive-load.md §6.

**Rule 9 — scope the `shorthand` register override to density-appropriate content.**
Refine the existing Input Contract description of `register: "shorthand"` (currently: "forces domain-shorthand even for a broad audience... e.g. a deliberately terse internal changelog"). Add: "Shorthand still preserves connective words for causal or argumentative content — it applies to parallel enumerations, status lists, and checklists, not to reasoning or an argument's throughline (same boundary as prima-flint's Register Ladder)." Prevents Contradiction #5 (Section 3): as written today the override doesn't state this carve-out, even though prima-flint (which it borrows from) already implies it.
*Target:* one added sentence to the `register` bullet in **Input Contract**.
*Source:* cognitive-load.md §1 (key implication on connective words); prima-flint.md Register Ladder (already in repo, cited not rewritten).

**Rule 10 — list length and nesting depth (lower confidence — apply as a soft default, not a hard rule).**
Add: "Keep lists to roughly 2–7 items where practical. Avoid nesting bullets beyond one level in Confluence/report content — if a list needs a second level of sub-bullets, it's usually a sign the section needs a sub-heading instead." Flag inline that the nesting-depth guidance is a reasoned default (working-memory capacity argument), not a directly-studied threshold.
*Target:* new "Readability Structure" section (Rule 3), explicitly marked as lower-confidence per Section 4 above.
*Source:* applied-standards.md §3 (Microsoft's 2–7 item guidance, primary standard); applied-standards.md §5 (nesting-depth inference, explicitly flagged as unstudied in the source file).

---

## 6. Recommended Next Steps

1. **Get sign-off on Rules 1–10 before editing `ghostwriter.md` directly.** This file is shared/owned config (per the task framing, Voice Profile/Anti-Patterns/Per-Medium/Length are explicitly out of scope for this synthesis pass) — per the repo's own decision-gates logic, a change reaching a shared, already-tuned file should clear a Scope Gate before being applied, not be auto-applied from a research synthesis.
2. **When implementing, add one calibration example** to ghostwriter.md's existing **Calibration Examples** section demonstrating a bullets-vs-prose decision in practice (e.g., a report input with a causal chain of reasons vs. a report input with a parallel feature list) — the existing examples don't currently exercise this decision.
3. **No further research is needed for the load-bearing rules** (sentence length, front-loading, bullets-vs-prose, tables, emphasis) — sourcing is already sufficient and cross-checked in Section 4.
4. **If pursuing further research, two gaps are worth a targeted follow-up**, both explicitly flagged as unaddressed in the source material: (a) nesting-depth-specific comprehension studies (currently pure inference), and (b) any L2/non-native-English-reader-specific comprehension research (none found in this pass; Section 2's L2 note is an inference from adjacent accessibility research, not a direct finding).
5. **Do not extend this synthesis's numeric thresholds to override the Length section's existing per-medium sentence/paragraph counts** (e.g., "Heads-up/FYI: 1-3 sentences") — those are voice/brevity constraints already tuned for this user, and Rule 1's 15–20 word guidance is a within-sentence target, not a competing length rule.
