---
description: >
  Drafts a high-level implementation plan for a GitHub issue — a human-readable
  design document meant for review and iteration. Posts as a comment after
  explicit user confirmation. This is a planning stage; execution happens via
  /gh-issue-develop once the plan is approved.
argument-hint: "<issue-number> [focus area or aspect to plan]"
disable-model-invocation: true
allowed-tools: Bash(*), Write
---

# Draft High-Level Implementation Plans

## Mode: PLAN-ONLY → HUMAN-REVIEW

Your role: **read the issue → parse context → detect conflicts → draft a high-level implementation plan → validate for quality → present for review → incorporate feedback → post the plan.**

**This is a design document, not an execution script.** The plan should be readable by an engineer in 2-3 minutes, outline the approach clearly enough for review and discussion, and serve as the input for `/gh-issue-develop` when ready.

**Posting the plan** means creating or updating a plan comment. It does NOT mean: implementing anything, writing production code, running tests, or making changes to the repo.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` to verify)
- Directories: `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}` must be writable (for draft state tracking)
- Write permissions on the repository
- Git repo recommended (for working-tree context, optional)

## Context

**Issue Number:**

```
!`echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'`
```

**Current Issue (always fresh):**

```
!`ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); gh issue view "${ISSUE_NUM}" --json number,title,url,body,state,labels,comments 2>/dev/null | jq -r -f "${CLAUDE_PLUGIN_ROOT}/queries/gh_issue_view.jq" || echo "Unable to fetch issue. Check the issue number and gh auth status."`
```

**Recent Comments (conflict detection):**

```
!`ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); gh issue view "${ISSUE_NUM}" --json comments 2>/dev/null | jq -r '.comments[-3:] | map("\(.author.login) (\(.createdAt | split("T")[0])): \(.body[:100])") | .[]' || echo "Unable to fetch comments."`
```

**Session State (draft tracking):**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/plan_session.md" 2>/dev/null || true`
```

**Session Notes (optional, non-authoritative):**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/session_notes.md" 2>/dev/null || true`
```

**Repository Info:**

```
!`gh repo view --json url,defaultBranchRef,languages,description 2>/dev/null | jq -r -f "${CLAUDE_PLUGIN_ROOT}/queries/gh_repo_view.jq" || echo "Unable to fetch repo info."`
```

**User Request:**

```
!`echo "$ARGUMENTS"`
```

## Workflow

### 1. **Validate & Fetch**

- Parse issue number from the first argument (`$ARGUMENTS`); if missing or not a number, ask the user
- Fetch issue details (title, body, state, labels, comments); if fetch fails, stop and show error
- Check user has write permissions to the repo (auth required)
- **Optional:** Check working tree status for context:
  ```bash
  git status --short
  git diff --stat HEAD
  ```
  (If git is unavailable or not a repo, skip silently and proceed)
- Load session state: check if there's an existing draft for this issue

### 2. **Smart Argument Parsing & Context**

- **Parse user arguments for:**
  - Focus area (e.g., "backend part", "auth flow")
  - Linked issues (e.g., "consider #42", "depends on #15")
  - Branch/PR references (e.g., "like PR #99")
  - Plan type hints (e.g., "bug fix", "feature", "refactor", "migration")

- **Auto-fetch linked context:**

  ```bash
  # If user mentions issue #X, fetch it:
  gh issue view X --json title,body

  # If user mentions PR #Y, fetch it:
  gh pr view Y --json title,body,commits
  ```

- **Resume option:**
  - If session state shows unsaved draft for this issue, ask: "You have a draft plan for #N from [timestamp]. Resume, start fresh, or discard?"

### 3. **Determine Plan Scope & Gather Context**

- **If focus area provided:** Scope plan to that area only
- **If empty:** Plan full implementation
- If the issue describes three or more independent workstreams with no shared dependencies, recommend splitting; ask how to proceed
- **Show context summary:**
  ```
  Linked issues: #15 (database schema), #42 (auth system)
  Depends on: PR #99 (utils refactor)
  Labels: bug, high-priority
  ```

### 4. **Detect Conflicts & Contradictions**

**Before drafting, check for:**

- **Recent activity:** If comments added in last 30 min, fetch and summarize: "Someone added context 15min ago: '[summary]'"
- **State contradictions:** If issue is closed but user wants implementation plan, confirm: "This issue is closed. Still plan implementation?"
- **Dependency issues:** If linked issue #15 is blocked or closed, flag it
- **Working tree conflicts:** If local changes match issue scope, note: "Local changes in [files] may relate to this"
- **Session conflicts:** If earlier draft in session contradicts current intent, ask: "Earlier you planned this as frontend-only, now backend. Start fresh?"
- **Existing plan:** If a plan comment already exists (tracking marker found), note: "A plan already exists. This will update it."

**If conflicts detected:**

- Show conflict summary
- Ask user to confirm: "Proceed anyway?" or "Let me know what changed"
- Do NOT proceed without confirmation

### 5. **Draft the High-Level Plan**

Write a concise, human-readable plan following this structure. **This is a design document — describe the approach, not the exact code.** Keep the entire plan readable in 2-3 minutes.

#### **Plan Structure**

```markdown
<!-- gh-claude:issue-plan issue=${ISSUE_NUM} -->

# [Feature/Fix Name] — Implementation Plan

**Issue:** [#N](url) — [title]
**Type:** [Bug Fix | Feature | Refactor | Migration | Security | Documentation]
**Estimate:** [Small (1-2 days) | Medium (3-5 days) | Large (1+ weeks)]
**Risk:** [Low | Medium | High] — [one-line reason if >Low]

---

## Goal

[2-3 sentences: what this achieves and why it matters]

## Approach

[3-5 sentences: the high-level strategy, key design decisions, and why this
approach was chosen over alternatives. Mention patterns, libraries, or
architectural choices.]

## Affected Areas

- `path/to/file.ext` — [why]
- `path/to/module/` — [why]
- `tests/path/to/` — [new tests needed for what]

## Tasks

### 1. [Task name] — [XS/S/M/L]

[2-4 sentences: what this task does, what files it touches, what the test
strategy is. Describe the change, not the code.]

### 2. [Task name] — [XS/S/M/L]

[2-4 sentences]

### 3. [Task name] — [XS/S/M/L]

[2-4 sentences]

## Task Dependencies

[Which tasks depend on others, or note "all tasks are independent" if true.
Show critical path if relevant: Task 1 → Task 3 (others parallel)]

## Open Questions

- [Genuine question that must be answered before or during implementation]
- [Missing context that affects the approach]

## Dependencies & Blockers

- [External dependency, e.g., "Requires PR #99 to be merged first"]
- [Or "None"]

---

_Plan ready? Run `/gh-issue-develop N` to promote to execution._
```

#### **Content rules:**

- **Describe, don't prescribe:** Say "Add a validation middleware that checks JWT expiry" not "Create file `src/middleware/auth.py` with the following code..."
- **Task descriptions, not step-by-step instructions:** Each task is 2-4 sentences explaining _what_ and _why_, not _how_ line-by-line
- **No code blocks in the plan** unless a brief snippet (under 5 lines) is essential to convey a non-obvious API or pattern choice
- **Estimates per task:** T-shirt sizes (XS=15min, S=30min, M=1-2hr, L=2-4hr)
- **Total 3-8 tasks** for most plans; if more are needed, the issue should probably be split
- **Open Questions are real:** Only list genuine unknowns; don't fabricate questions to fill the section
- **Tracking marker** at the top: `<!-- gh-claude:issue-plan issue=${ISSUE_NUM} -->` (used by `/gh-issue-develop` to find this plan)

### 6. **Validate Plan for Quality**

Before presenting to user, conduct a validation review:

**Check:**

| Check                     | Validation                                                | Action if Failed                                         |
| ------------------------- | --------------------------------------------------------- | -------------------------------------------------------- |
| **Readability**           | Can an engineer read this in 2-3 minutes?                 | Cut length; consolidate tasks; remove unnecessary detail |
| **Clarity**               | Each task clearly describes what changes and why?         | Rewrite vague tasks with specific intent                 |
| **No code dumps**         | No large code blocks (>5 lines)?                          | Replace with descriptive prose                           |
| **Estimates present**     | Every task has a size; total estimate in header?          | Add missing estimates                                    |
| **Affected areas**        | File paths are real (from repo), not invented?            | Verify paths exist or mark as "new file"                 |
| **Task count**            | 3-8 tasks? If more, recommend splitting the issue         | Consolidate or suggest split                             |
| **Open Questions**        | Only genuine unknowns, nothing fabricated?                | Remove speculative questions                             |
| **Dependencies**          | Task order makes sense; no circular dependencies?         | Reorder tasks                                            |
| **Risk calibration**      | Risk level matches what's actually being touched?         | Adjust risk and explain                                  |
| **Tracking marker**       | `<!-- gh-claude:issue-plan issue=N -->` present at top?   | Add marker                                               |
| **Actionable by develop** | Plan has enough detail for `/gh-issue-develop` to expand? | Add architectural context or design notes                |

**If any check fails:** Revise the draft before step 7. Do NOT proceed with a flawed plan.

### 7. **Present for Review**

Show the draft plan clearly with session context:

```
---
**Draft implementation plan for issue #N: [Title]**

**Session context:** This is draft #1 in this session
**Next step:** When approved, run `/gh-issue-develop N` to begin execution

[FULL PLAN CONTENT]

---

_Looks good to post, or what should I change?_
```

### 8. **Handle User Feedback**

- **If user confirms** (`"post"`, `"yes"`, `"looks good"`, `"👍"`): Proceed to step 9
- **If user requests changes**: Revise and return to step 6 → 7
- **If user says cancel** (`"no"`, `"cancel"`, `"discard"`): Stop and don't post
- **If scope changes**: Ask which part to focus on; restart from step 3
- **If no response to confirmation**: Ask once more: "Should I post this plan or make changes?"

### 9. **Save Draft & Track Session State**

- Create the drafts directory: `mkdir -p "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts"`
- Use the Write tool to save the plan to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft.md`
- Update session state file with: issue number, plan status, timestamp, posted URL (once posted)

### 10. **Post or Update Comment**

- Find existing plan comment and post or update (run as a single block to preserve variables):
  ```bash
  ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#')
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
  COMMENT_ID=$(gh api "repos/${REPO}/issues/${ISSUE_NUM}/comments" --paginate | jq -s --arg marker "<!-- gh-claude:issue-plan issue=${ISSUE_NUM} -->" '[.[][] | select(.body | contains($marker))] | last | .id // empty')
  if [ -n "${COMMENT_ID}" ]; then
    jq -Rs '{body: .}' "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft.md" > "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft_body.json"
    gh api "repos/${REPO}/issues/comments/${COMMENT_ID}" --method PATCH --input "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft_body.json" --jq .html_url
  else
    gh issue comment "${ISSUE_NUM}" --body-file "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft.md"
  fi
  ```

### 11. **Confirm Success**

- On success: Show the posted/updated comment URL and confirm whether it was created or updated
- Remind user: "When the plan is ready, run `/gh-issue-develop N` to begin execution."
- On failure: Display the full error and suggest `gh auth status`

---

## Rules & Guidelines

### Plan Philosophy

- **This is a design document, not a build script.** It should communicate intent, approach, and scope — not exact code.
- **Audience:** An engineer (or the author themselves, later) who needs to understand _what_ will change and _why_ before diving into implementation.
- **Iteration is expected:** Plans will go through 1-3 rounds of feedback before execution. Keep them easy to revise.
- **The plan feeds `/gh-issue-develop`:** Include enough architectural detail that the execution stage can expand tasks into concrete code without re-analyzing the issue from scratch.

### Content & Structure

- **Header required:** Every plan starts with Issue, Type, Estimate, Risk
- **Goal + Approach required:** What and why, 5-8 sentences total
- **Affected Areas:** Real file paths from the repo; mark new files as "(new)"
- **Tasks:** 3-8 tasks, each 2-4 sentences, with T-shirt size
- **No code blocks** unless a brief snippet (<5 lines) is essential to convey a pattern choice
- **Open Questions & Dependencies:** Only genuine items; omit sections if empty
- **Tracking marker:** Always at the top: `<!-- gh-claude:issue-plan issue=${ISSUE_NUM} -->`

### Estimates

- **T-shirt sizing:** XS (15min), S (30min), M (1-2hr), L (2-4hr)
- **Total in header:** Small (1-2 days) | Medium (3-5 days) | Large (1+ weeks)
- **Risk flags:** Mark tasks touching: database schema, API contracts, security, core utilities
- **Task dependencies:** Note critical path if tasks have ordering constraints

### Safety & Scope Boundaries

- **No implementation:** Never write code, edit files, or run commands (except git/gh queries)
- **No branches/commits:** Never create branches, commit, push, or open PRs
- **No build/test:** Never run build, test, formatter, linter, or package-manager commands
- **Plan-only focus:** Only safe to write `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/` and create that directory
- **Respect focus area:** If user requests one aspect, don't plan the full issue

### Context Awareness

- **Working tree:** If local changes detected, note at top of plan
- **Labels & urgency:** Consider labels (bug, feature, urgent, security) when ordering tasks
- **Existing discussions:** Reference prior comments if they inform approach
- **Repository context:** Use language/framework/conventions of the repo
- **Linked issues:** Auto-fetch and reference them; note if they're blocking

### Edge Cases

- **Very broad issues:** Recommend splitting; ask which area to plan
- **Too little context:** Use Open Questions section; don't invent details
- **Existing plan comment:** Find and update it (don't create duplicate)
- **Multiple focus areas:** Ask if user wants all or a specific area
- **Vague issue:** If issue doesn't explain what to build, ask before drafting
- **Closed issue:** Note state and confirm before planning

---

## Error Messages & Recovery

| Scenario                            | Action                                                  |
| ----------------------------------- | ------------------------------------------------------- |
| Issue number missing from arguments | Ask user: "Which issue? e.g. `/gh-issue-plan 42 ...`"   |
| `gh issue view` fails               | Show error, suggest `gh auth status`                    |
| Git unavailable                     | Skip working-tree check, proceed without that context   |
| Issue context unclear               | Use Open Questions; ask user to clarify before drafting |
| User wants to split scope           | Ask which part to plan; restart from step 3             |
| Posting/updating fails              | Show error, suggest `gh auth status`                    |
| Plan too long (>8 tasks)            | Recommend splitting the issue; ask how to proceed       |
| Existing plan found                 | Update it instead of creating duplicate                 |
| Conflict detected                   | Show conflict, ask user to confirm before proceeding    |
| Linked issue unavailable            | Note it, continue with what you have                    |
| Validation detects issues           | Revise in step 6; do NOT present flawed plan            |
| User interrupts drafting            | Ask: "Should I save the draft, discard it, or resume?"  |

---

## Plan Type Templates

Pick the closest type and adapt the plan accordingly.

| Type              | Typical Tasks | Estimate          | Focus                                                         |
| ----------------- | ------------- | ----------------- | ------------------------------------------------------------- |
| **Bug Fix**       | 2-4           | Small (1-2 days)  | Reproduction, root cause, fix, regression tests               |
| **Feature**       | 4-6           | Medium (3-5 days) | Tests, implementation, integration, edge cases                |
| **Refactor**      | 3-5           | Medium (2-4 days) | Test coverage first, gradual refactor, validate equivalence   |
| **Migration**     | 5-8           | Large (1+ weeks)  | Compatibility layer, gradual migration, deprecation, cleanup  |
| **Security**      | 2-4           | Medium (1-3 days) | Minimal changes, comprehensive tests, audit trail (High risk) |
| **Documentation** | 2-3           | Small (1-2 days)  | Example code that runs, clear prose, audience-appropriate     |
