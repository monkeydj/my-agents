# Craft Style

## Pride & Self-Check

- **Self-check**: Before marking work done — "Proud to show this to a friend?" If not, clean first.
- **Boy Scout Rule**: Leave code cleaner than found. Every touch = small improvement.
- **Collective ownership**: Code belongs to team. Write for the next reader.

## Technical Debt

- **Log debt**: After each session, note tech debt found — `# TODO(debt):` inline or a ticket.
- **Debt types**: Reckless (corner-cut) vs. prudent (conscious trade-off). Log both. Treat differently.
- **Debt visibility**: Log with description, owner, estimated fix cost.
- **Repayment budget**: Reserve 10-20% of capacity for debt reduction. Fix small things in-band.
- **Definition of done**: Not just "tests pass" — no new debt without a ticket.

## Learning & Discovery

- **Learn bias**: Multiple valid paths? Pick the one that reveals more about the codebase.
- **Spike first**: Unknown territory → timebox a throwaway experiment before committing to approach.
- **Read before writing**: Understand existing patterns before adding new ones. Inconsistency = hidden debt.

## Structural Impact

- **Graph check**: Before big structural edits, optionally check code graph for impact. Skip for small changes.
- **Blast radius**: Before touching shared code — estimate callers, tests, modules affected.
- **Module boundaries**: Minimize coupling. Depend on abstractions, not concrete implementations.
- **Small commits**: Many small commits > one large. Easier to review, revert, reason about.

## Collaboration & Process

- **Pair consideration**: For complex changes, consider pairing for real-time review and knowledge transfer.
- **Review mindset**: Code reviews = learning opportunities. Clarity over cleverness.
- **Retrospectives**: Reflect regularly on what worked and what didn't. Adjust practices.
- **Metrics**: Track test coverage, complexity, cycle time to guide improvements.

## Sustainable Craft

- **Testability**: Design code to be easily tested from the start. Prefer TDD when practical.
- **Sustainable pace**: Don't sprint indefinitely. Rushed code creates more work than it saves.
- **Tighten feedback loops**: Fast tests > slow tests. Local check > CI check.
- **Courage**: Refactor when needed. Don't leave known rot because it's scary to touch.
