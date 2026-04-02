## Commit, Push & Create MR

> **Mandatory.** This phase must run on every invocation. If tests are skipped (migration), commit
> and push immediately after Phase 3. Never stop the workflow here without completing all three.

> **Craftsman mindset:** A commit is a unit of history. Make it meaningful. Don't pollute the timeline with WIP commits — squash before you push. Your work isn't done until it's visible to others.

### Step 1: Pre-commit Review

Before running `git commit`, review what you're actually committing:

```bash
git diff --staged
```

Ask yourself:
- Does this tell a coherent story?
- Is the commit message accurate?
- Are there any temp files, debug logs, or unintended changes?

### Step 2: Commit

Use **conventional commits** with the ticket ID in the scope position:

```
<type>(TICKET-ID): <short imperative description>

[optional body — explain the why, not the what]
```

**Types:** `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `migration`

**Examples:**
```
feat(BP-1234): add rate limiting middleware to API gateway
fix(GG-5678): handle null response from payment provider
chore(DRM-9012): upgrade deps to address CVE-2024-1234
migration(DATA-3456): add user_preferences column to accounts table
refactor(ARB-7890): extract auth logic into dedicated service
```

If no ticket ID was provided, use a descriptive scope: `feat(auth): ...`

Stage files intentionally — name them explicitly rather than using `git add .`. Don't
accidentally include env files, secrets, or unrelated changes.

**Squash WIP commits:** If you have commits like "WIP", "temp", or "fix typo", squash them before pushing. Clean history matters.

**Test files (from Phase 4) are staged in the same commit as the implementation.** A feature and
its tests are one logical unit — they belong together. Use a separate `test(...)` commit only when
adding or fixing tests for code that was already committed previously.

**Don't amend unless necessary.** If you've already pushed, don't amend — create a new commit.

### Step 3: Push

Push to the current branch. Confirm it is not `main`, `master`, or `release-*` first.

```bash
git push -u origin <current-branch>
```

### Step 4: Create MR

After pushing, **always print the current branch name**. Then check for an existing MR on this branch:

- If an MR exists: print its URL prominently as the final output line.
- If no MR exists: **create a Draft MR automatically** using the GitLab MCP tool (`mcp__gitlab__create_merge_request`). Set `draft: true`. The user will open/ready it manually when ready. Print the newly created MR URL.

**Populate the MR description:** Don't leave it blank. Include:
- What this change does (summary)
- Why this change exists (context from Phase 1)
- How to test it (if not obvious)
- Any screenshots or demo steps for UI changes

Don't make reviewers hunt for context. A craftsman makes their work easy to review.

**End-of-workflow output format (always):**

```
Branch: <current-branch>
MR: <MR URL>
```

Never omit this block. It is the final line of the workflow.
