## Phase 8: Post-Commit Code Review (Optional)

> **Craftsman mindset:** A second set of eyes catches what you missed. Code review is not criticism — it's professional courtesy and quality insurance.

After pushing and creating the MR, prompt the user:

```
The commit is pushed and MR is ready. Would you like me to run a local code review?

Options:
- Yes, review the changes
- No, skip review
```

**If user says yes:**

1. **Check for available code review capabilities:**
   - Look for installed plugins/skills related to code review
   - Check for MCP tools that can analyze code (linters, static analysis with AI)
   - Common code review skills: `code-review`, `review`, `critique`

2. **If a code review skill is available**, activate it and run against the current diff/changes

3. **If no dedicated code review skill exists**, run a comprehensive local review manually:
   ```bash
   # Get the diff of changes
   git diff main...HEAD --stat
   git diff main...HEAD
   ```
   Then analyze for:
   - Code quality issues not caught by linters
   - Potential bugs or edge cases
   - Security concerns
   - Performance implications
   - Naming and readability
   - Test coverage gaps

4. **Present findings** in a structured format:

   ```
   ## Code Review Summary
   
   ### Issues Found
   - [Critical] ...
   - [Warning] ...
   - [Suggestion] ...
   
   ### Positive Observations
   - ...
   
   ### Recommendations
   - ...
   ```

5. **Offer to address** any issues in a follow-up if the user wants

**If user says no:** Acknowledge and end the workflow cleanly.

---

The workflow is complete. A craftsman delivers quality work and welcomes review.
