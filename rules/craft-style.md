# Craft Style

## Principles (invisible — mindset, not directly observable in any single artifact)

**Pride & ownership**
- Self-check: before done, "proud to show a friend?" If not, clean first.
- Boy Scout Rule: leave code cleaner than found. Every touch = small improvement.
- Collective ownership: code belongs to the team. Write for the next reader.
- Clean code: humans first — meaningful names, small functions, clear intent.

**Debt awareness**
- Debt types: reckless (corner-cut) vs. prudent (conscious trade-off with a plan). Treat differently.
- Repayment budget: reserve 10-20% capacity for debt reduction. Fix small things in-band.

**Learning & discovery**
- Multiple valid paths → pick the one revealing more about the codebase.
- Unfamiliar area → zoom out one abstraction layer first; map modules and callers in domain vocab before reading impl detail.
- Unknown territory → timebox a throwaway spike before committing.
- Read existing patterns before adding new ones — inconsistency is hidden debt.
- Document decisions, mentor, contribute. In reviews, clarity beats cleverness.
- Reflect on practice; experiment; keep learning outside the immediate task.

**Structural judgment**
- Before big structural edits, optionally check the dependency graph for impact — skip for small changes.
- Blast radius: before touching shared code, estimate callers/tests/modules affected, in domain vocab, not file paths.
- Module boundaries: minimize coupling. Depend on abstractions, not concrete impls.
- Simplicity: prefer simple solutions. Avoid premature optimization. Keep functions short.

**Sustainable pace**
- Design for testability from the start. Prefer TDD when practical.
- Don't sprint indefinitely — rushed code creates more work later.
- Tighten feedback loops: fast tests > slow, local check > CI, immediate > delayed.
- Pair on complex changes for real-time review and knowledge transfer.
- Hold retrospectives — reflect on what worked/didn't, adjust.
- Track test coverage, complexity, cycle time as smoke detectors, not targets.

## Checkpoints (visible — verify against real artifacts, not self-report)

- **Small, logical commits** — check `git log --oneline`. Many small commits beat one large; each commit does one thing. "Refactor AND feature" in one commit is a signal something's off.
- **Patterns followed, not invented** — check the code diff against surrounding code. Does it match existing naming, structure, idioms? No premature abstraction.
- **Cleanup actually happened** — check the diff ratio for refactor-heavy work. 100% new code with zero cleanup means the Boy Scout Rule isn't being applied.
- **Debt logged, not hidden** — check for `# TODO(debt):` inline (description, owner, estimated cost) or a ticket link, for every corner cut. Silent debt is reckless debt with the visibility stripped out.
- **Scope stated, not implied** — check the MR/PR description for blast radius: what's affected, what could break, what tests cover it.

## Definition of Done
Not just "tests pass." Before calling it done:
- [ ] Tests pass
- [ ] No new debt without a logged ticket or `TODO(debt)`
- [ ] Commits are small and reviewable — `git log` shows logical steps, not one dump
- [ ] MR/PR description states scope, blast radius, and any cleanup or debt taken on
- [ ] Self-check passes: proud to show a friend?

## Links
- `decision-gates.md` — blast radius and small-commits practice are the engineering analog of the Reversibility Gate.
- `dissensus.md` — when a blast-radius check finds shared/systemic impact, that's the Scope Gate failing; pushback and negotiation take over from here.
- `prima-flint.md` — "style preferences inferable from repo" (prima-flint's own words for what not to ask about) means inferable from these principles and the existing patterns they point to.

## KBS
Operationalizes [[solve-right-problem-first]] — "zoom out before narrowing," "read before writing," "spike unknown territory before committing" are this rule's version of discovery-before-solution.
