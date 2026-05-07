# Craft Style

## Pride & Self-Check

- **Self-check**: Before done — "Proud to show friend?" If not, clean first.
- **Boy Scout Rule**: Leave code cleaner than found. Every touch = small improvement.
- **Collective ownership**: Code belongs to team. Write for next reader.
- **Clean code**: Humans first — meaningful names, small functions, clear intent.

## Technical Debt

- **Debt types**: Reckless (corner-cut) vs. prudent (conscious trade-off with plan). Log both. Treat differently.
- **Debt visibility**: Log each session — `# TODO(debt):` inline or ticket — include description, owner, estimated fix cost.
- **Repayment budget**: Reserve 10-20% capacity for debt reduction. Fix small things in-band.
- **Definition of done**: Not just "tests pass" — no new debt without ticket.

## Learning & Discovery

- **Learn bias**: Multiple valid paths? Pick one revealing more about codebase.
- **Zoom out**: Unfamiliar area → go up one abstraction layer first. Map all relevant modules and callers using project's domain vocabulary before reading implementation detail.
- **Spike first**: Unknown territory → timebox throwaway experiment before committing.
- **Read before writing**: Understand existing patterns before adding new. Inconsistency = hidden debt.
- **Knowledge sharing**: Document decisions; mentor others; contribute to community. In reviews, clarity > cleverness.
- **Continuous improvement**: Reflect on practices; experiment; attend conferences.

## Structural Impact

- **Graph check**: Before big structural edits, optionally check code graph for impact. Skip small changes.
- **Blast radius**: Before touching shared code — estimate callers, tests, modules affected. Use domain vocabulary (not file paths) when describing impact.
- **Module boundaries**: Minimize coupling. Depend on abstractions, not concrete implementations.
- **Simplicity**: Prefer simple solutions; avoid premature optimization; keep functions short.
- **Small commits**: Many small > one large. Easier to review, revert, reason about.

## Collaboration & Process

- **Pair consideration**: Complex changes → consider pairing for real-time review and knowledge transfer.
- **Retrospectives**: Reflect regularly on what worked/didn't. Adjust.
- **Metrics**: Track test coverage, complexity, cycle time.

## Sustainable Craft

- **Testability**: Design for easy testing from start. Prefer TDD when practical.
- **Sustainable pace**: Don't sprint indefinitely. Rushed code creates more work.
- **Tighten feedback loops**: Fast tests > slow. Local check > CI. Immediate > delayed.