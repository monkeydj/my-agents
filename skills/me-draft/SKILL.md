---
name: me-draft
description: >
  Craftsman-driven requirements review, codebase analysis, and development planning.
  Transforms tickets, specs, or PRDs into a reasoned, dependency-ordered implementation plan.
  TRIGGER whenever the user provides requirements, a ticket, spec, or PRD and wants to
  understand and plan before coding — even if they don't say "me-draft" explicitly.
  Activate for phrases like: "review this ticket", "analyze the spec", "let's plan this",
  "draft a plan", "what's the approach for this?", "help me understand what needs to change",
  "break this down before we code", "analyze the requirements", "plan the implementation".
  Also trigger when the user pastes a Jira/Linear/GitHub issue and expects analysis and planning
  before any code is written. Output: a confirmed, persisted development plan ready for me-craft.
allowed-tools: Read, Grep, Glob, Bash, TaskCreate, get_context_tree, semantic_code_search, semantic_identifier_search, semantic_navigate, get_file_skeleton, search_memory_graph, upsert_memory_node, create_relation, undo_change
---

# me-draft: Requirements Review & Development Planning

This skill takes you from raw requirements to a confirmed, reasoned development plan.
It enforces the craftsman principle of understanding before implementing — no code is written here.

Work through the phases in order. Mark each phase done before moving on.

---

## Phase 1: Review & Analyze

> **Craftsman mindset:** A software craftsman understands that quality starts before the first line of code is written. Thorough analysis prevents expensive rework and ensures the final work is maintainable, testable, and valuable.

Read everything the user has provided: tickets, specs, PRDs, Jira issues, inline requirements,
linked files. If the user referenced something without pasting it, ask for it.

### Step 1: Understand the "What" and "Why"

Before touching any code, articulate in your own words:
- **What** is being built or fixed? (the explicit requirement)
- **Why** does this need to exist? (the underlying problem or value)
- **Who** will use this? (the user/customer perspective)

If you cannot explain the "why" clearly, ask the user. A craftsman never assumes intent — they seek to understand.

### Step 2: Map the Codebase

Use **contextplus MCP** for semantic codebase navigation when available. See [`rules/code-analysis.md`](rules/code-analysis.md) for the full tool reference.

If contextplus is not available, use `ls`, `grep`, `glob`, and file reads manually —
but prioritize semantic tools when available.

### Step 3: Analyze with Craftsmanship Principles

For each potential change, evaluate through the lens of Software Craftsmanship:

| Principle | Questions to Ask |
|-----------|------------------|
| **Well-Crafted** | Will this code be readable, testable, and extendable? Does it follow existing patterns? Will future developers understand it? |
| **Steadily Adding Value** | Does this solve the real problem? What are the downstream effects of this design choice? Is this sustainable? |
| **Community of Professionals** | Are there existing patterns I should match? Would a peer recognize this as idiomatic? |
| **Continuous Learning** | Am I learning something new about this codebase? Does this reveal any technical debt worth noting? |

### Step 4: Identify Scope with Reasoning

Document your findings with **explicit reasoning** for each decision. Challenge your assumptions:

- **Type of change:** feature | bug fix | refactor | chore | data migration
  - *Reasoning:* Why this classification matters for the workflow
- **Affected scope:** which files, modules, services, or APIs are likely involved
  - *Reasoning:* How you identified these (via contextplus tools or manual exploration)
- **Technical constraints:** performance, backward compatibility, framework-specific rules
  - *Reasoning:* Why these constraints exist and how they shape the implementation
- **Testing approach:** Can this be tested in isolation? What are the boundaries?
  - *Reasoning:* TDD-readiness assessment — can we write tests first?
- **Refactoring opportunities:** Does the existing code need cleanup before adding new behavior?
  - *Reasoning:* "Clean code first" principle — don't layer new mess on old mess
- **Data migration flag:** if this is a migration, tests will be skipped in implementation
  - *Reasoning:* Migration safety — why tests are inappropriate for schema changes

### Step 5: Risk Assessment

Before proceeding to Phase 2, identify:
- **Integration points:** What other systems/modules does this touch?
- **Breaking changes:** Could this affect existing consumers? (API, DB, contract)
- **Rollback strategy:** How would we undo this if it fails?
- **Edge cases:** What are the failure modes no one mentioned?
- **Spike consideration:** If uncertainty is high, should you prototype first before full implementation?

If anything is ambiguous or underspecified, ask now — it's cheaper to clarify before planning
than to backtrack mid-implementation. A craftsman clarifies before acting.

---

## Phase 2: Craft & Persist the Development Plan

> **Craftsman mindset:** A development plan is not just a checklist — it's a contract with future-you and your team. Each task should be intentional, each decision reasoned.

Break the work into ordered, concrete tasks. Think through dependencies — what has to happen
before what. Identify which files need to change and roughly how.

> **Scaling the plan:** For small, straightforward changes (e.g., one-file fix, simple feature), use a simplified version of this template. For complex changes involving multiple modules, refactoring, or uncertain paths, use the full structure below. If uncertainty is high, add a **Spike** task to prototype before committing to an approach.

### Plan Structure with Reasoning

Every decision in the plan must include **why** — not just what. This follows the craftsmanship principle of "well-crafted" communication:

```
# Plan: [Feature/Fix Name]

## Context
[1-2 sentences on what and why]

**Ticket:** [ID if provided, e.g., BP-1234]
**Type:** feat | fix | chore | refactor | migration

## Analysis Summary
- **Why this approach?** [Explain reasoning — e.g., "Using existing pattern X because..."]
- **What are the risks?** [List identified risks from Phase 1]
- **What constraints must be honored?** [Performance, backward compat, etc.]

## Implementation Steps

### 1. [First concrete task]
- **Files:** [list affected files/modules]
- **Reasoning:** [Why this task first? What dependencies does it establish?]
- **Craftsmanship notes:** [Any pattern matching, refactoring needs, or testability concerns]

### 2. [Second task]
- **Files:** [list affected files/modules]
- **Reasoning:** [Why this task follows the previous one]
- **Craftsmanship notes:** [Edge cases, error handling, or design considerations]

...

## Test Strategy
- **Type:** unit | integration | e2e | skip
- **Reasoning:** [Why this test approach? TDD-feasible? What boundaries are being tested?]
- **TDD consideration:** [Can we write tests first? If not, why not?]

## Code Quality Gates
- [ ] **Readability:** Will another developer understand this in 6 months?
- [ ] **Testability:** Can this be tested in isolation?
- [ ] **Extensibility:** Will future changes require rewriting this?
- [ ] **Error handling:** Are failure modes explicit and handled?
- [ ] **Consistency:** Does this match existing codebase patterns?

## Refactoring Opportunities (Optional)
- [Any cleanup identified during analysis that could be done alongside this change]
- **Reasoning:** [Why do this now vs. later? "If not now, when?" principle]

## Rollback Plan
- [How to undo this change if it fails in production]
- **Reasoning:** A craftsman thinks about reversibility — forward progress without a retreat path is reckless

## Critical Files
[Key files that will be read or modified — with brief notes on what aspect matters]
```

### Task Tracking

**Track the plan with TaskCreate** — create one task per implementation step immediately after
drafting the plan. Include the reasoning as task notes when possible. Always append this fixed task at the end:

```
[ ] Commit, push & create MR
```

**Order tasks by dependency, not convenience.** The logical sequence matters more than what's easiest.

### Alignment Check

Present the plan to the user and **wait for confirmation** before handing off to me-craft.
This is the most important pause in the workflow — alignment here prevents expensive rework.

**Before presenting, verify:**
1. Each task has a clear "done" state
2. Dependencies are explicit (Task B needs Task A first)
3. Test strategy is defensible
4. Risks are acknowledged, not hidden

A craftsman plans with the same care they write code.

---

## Handoff to me-craft

Once the user confirms the plan, this skill's work is done.

Prompt the user:
```
Plan confirmed. Ready to implement — invoke me-craft to begin Phase 0.
```

The confirmed plan and created tasks are the handoff artifact. me-craft picks up from here.

---

## Code Analysis & Exploration

For codebase navigation and static analysis tools used during Phase 1, see:

- **[`rules/code-analysis.md`](rules/code-analysis.md)** — contextplus MCP tools, Context7 for library/framework references, and static analysis tools
