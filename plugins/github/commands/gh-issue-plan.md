---
description: >
  Drafts a comprehensive, bite-sized implementation plan for the current GitHub
  issue with TDD-style task breakdown and performance estimates. Posts as comment
  after explicit user confirmation. Accepts an optional focus area argument to
  scope the plan.
argument-hint: "<issue-number> [focus area or aspect to plan]"
disable-model-invocation: true
allowed-tools: Bash(*), Write
---

# Draft and Post GitHub Issue Implementation Plans

## Mode: PLAN-ONLY → EXECUTION-READY

Your role: **read the issue → parse context → detect conflicts → draft comprehensive plan with estimates → validate for quality → present for review → incorporate feedback → post the plan.**

**Posting the plan** means creating or updating a plan comment. It does NOT mean: implementing anything, writing code, running tests, or making changes to the repo.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` to verify)
- Directories: `~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}` must be writable (for draft state tracking)
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
!`cat "~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/plan_session.md" 2>/dev/null || true`
```

**Session Notes (optional, non-authoritative):**

```
!`cat "~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/session_notes.md" 2>/dev/null || true`
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
  - Template hints (e.g., "bug fix", "feature", "refactor", "migration")

- **Auto-fetch linked context:**

  ```bash
  # If user mentions issue #X, fetch it:
  gh issue view X --json title,body

  # If user mentions PR #Y, fetch it:
  gh pr view Y --json title,body,commits
  ```

- **Detect issue template:**
  - Check `.github/ISSUE_TEMPLATE/` for bug/feature/etc templates
  - If repo has structured templates, align plan to their sections

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
  Template: Feature request
  ```

### 4. **Detect Conflicts & Contradictions**

**Before drafting, check for:**

- **Recent activity:** If comments added in last 30 min, fetch and summarize: "Someone added context 15min ago: '[summary]'"
- **State contradictions:** If issue is closed but user wants implementation plan, confirm: "This issue is closed. Still plan implementation?"
- **Dependency issues:** If linked issue #15 is blocked or closed, flag it
- **Working tree conflicts:** If local changes match issue scope, note: "Local changes in [files] may relate to this"
- **Session conflicts:** If earlier draft in session contradicts current intent, ask: "Earlier you planned this as frontend-only, now backend. Start fresh?"

**If conflicts detected:**

- Show conflict summary
- Ask user to confirm: "Proceed anyway?" or "Let me know what changed"
- Do NOT proceed without confirmation

### 5. **Draft the Comprehensive Plan**

Write the plan following this structure:

#### **Plan Header**

```markdown
# [Feature Name] Implementation Plan

**For Issue:** [#issue-number](repo_url/issues/issue-number)

**Goal:** [One sentence: what this builds]

**Architecture:** [2-3 sentences explaining the approach and key design decisions]

**Tech Stack:** [Key technologies, libraries, frameworks relevant to this work]

**Key Principles:** DRY, YAGNI, TDD, frequent commits

**Performance Estimate:** [Overall: Small (1-2 days) | Medium (3-5 days) | Large (1+ weeks)]

**Risk Factors:** [High: database migration | Medium: API changes | Low: internal utilities]

---
```

#### **Likely Affected Areas**

```markdown
## Likely Affected Areas

- [`path/to/file.ext`](repo_url/blob/branch/path/to/file.ext) — reason why
- [`path/to/module.ext:123-145`](repo_url/blob/branch/path/to/module.ext#L123-L145) — specific reason
```

#### **Task Structure (TDD-Style, Bite-Sized with Estimates)**

For plans with 8+ tasks, use descriptive steps with key code snippets instead of complete code for every step — keep the GitHub comment readable.

````markdown
### Task N: [Component or Feature Name] — [Size: XS/S/M/L]

**Estimate:** [Task size] (XS=15min, S=30min, M=1-2hr, L=2-4hr)
**Risk:** [Low/Medium/High] — reason if >Low
**Files:**

- Create: `exact/path/to/new_file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/path/to/test_file.py`

**Step 1: Write the failing test**

[COMPLETE TEST CODE]

**Step 2: Run test to verify it fails**

Run: `pytest tests/path/to/test.py::test_name -v`

Expected: FAIL

**Step 3: Write minimal implementation**

[COMPLETE IMPLEMENTATION CODE]

**Step 4: Run test to verify it passes**

Run: `pytest tests/path/to/test.py::test_name -v`

Expected: PASS

**Step 5: Commit**

```bash
git add tests/path/to/test.py src/path/to/file.py
git commit -m "feat: add component feature"
```
````

#### **Summary Section**

````markdown
## Effort Summary

- **Total estimate:** 5-7 hours (Medium)
- **By task:** Task 1 (S), Task 2 (M), Task 3 (S), Task 4 (L), Task 5 (XS)
- **Risk areas:** Task 4 (database changes require care)
- **Critical path:** Task 1 → Task 4 (others parallel)
- **Approx timeline:** 1 day for experienced engineer, 2-3 days for new to codebase
````

#### **Open Questions & Dependencies**

```markdown
## Open Questions

- {Specific question that must be clarified}
- {Missing information that affects approach}

## Dependencies & Blockers

- Requires PR #99 to be merged first
- Database schema change in #15 must be applied
```

(Omit sections if none exist.)

### 6. **Validate Plan for Quality**

Before presenting to user, conduct a validation review:

**Check:**

| Check                    | Validation                                          | Action if Failed                                        |
| ------------------------ | --------------------------------------------------- | ------------------------------------------------------- |
| **Actionability**        | All tasks are concrete (no vague language)?          | Replace vague steps with specific code/commands          |
| **Completeness**         | Each step has complete code/commands, not prose?     | Add full code blocks; no `...` or pseudocode             |
| **File paths**           | Exact paths from repo root, hyperlinked?             | Fix paths and add GitHub links                           |
| **Expected outputs**     | Verification steps show what success looks like?     | Add expected output for each test/run step               |
| **Commit messages**      | Logical and follow semantic messaging?               | Revise to match repo conventions                         |
| **TDD structure**        | Test -> fail -> implement -> pass -> commit?         | Reorder steps to follow TDD cycle                        |
| **No placeholders**      | No TODOs, `...`, or incomplete sections?             | Fill in all placeholders before presenting               |
| **Task sequence**        | Logical order with no circular dependencies?         | Reorder tasks to respect dependency chain                |
| **Effort estimates**     | Realistic and consistent across tasks?               | Adjust sizes; flag uncertainty in Open Questions         |
| **Risk flags**           | Accurate severity (not over/under-flagged)?          | Calibrate to actual impact                               |
| **Followability**        | An engineer new to codebase could follow this?       | Add context or simplify steps that assume prior knowledge |
| **Open Questions**       | Real blockers captured; nothing fabricated?           | Remove speculative questions; add genuine unknowns       |

**If any check fails:** Revise the draft before step 7. Do NOT proceed with incomplete plan.

### 7. **Present for Review**

Show the draft plan clearly with session context:

```
---
**Draft implementation plan for issue #N: [Title]**

**Session context:** This is draft #2 in this session (1 edited earlier)

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

- Create the drafts directory: `mkdir -p "~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts"`
- Use the Write tool to save the plan to `~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft.md`
- Update session state file with: issue number, plan status, timestamp, posted URL (once posted)
- Format: track all drafts/posts in this session for context in future calls

### 10. **Post or Update Comment**

- Find existing plan comment and post or update (run as a single block to preserve variables):
  ```bash
  ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#')
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
  COMMENT_ID=$(gh api "repos/${REPO}/issues/${ISSUE_NUM}/comments" --paginate | jq -s --arg marker "<!-- gh-claude:issue-plan issue=${ISSUE_NUM} -->" '[.[][] | select(.body | contains($marker))] | last | .id // empty')
  if [ -n "${COMMENT_ID}" ]; then
    jq -Rs '{body: .}' "~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft.md" > "~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft_body.json"
    gh api "repos/${REPO}/issues/comments/${COMMENT_ID}" --method PATCH --input "~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft_body.json" --jq .html_url
  else
    gh issue comment "${ISSUE_NUM}" --body-file "~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_plan_draft.md"
  fi
  ```

### 11. **Confirm Success**

- On success: Show the posted/updated comment URL and confirm whether it was created or updated
- On failure: Display the full error and suggest `gh auth status`

---

## Rules & Guidelines

### Planning Style & Audience

- **Audience:** Write assuming an engineer with zero codebase knowledge but solid development skills
- **Tone:** Plain English, conversational; explain _why_ not just _what_
- **Task granularity:** Each step takes 2-5 minutes; break large steps into smaller ones
- **Completeness:** Include complete code, exact commands, expected outputs; no vagueness
- **Honesty:** If you lack info, say so in Open Questions; don't invent details
- **Scope awareness:** If issue spans multiple independent areas, ask before planning all

### Performance Estimates

- **T-shirt sizing:** XS (15min), S (30min), M (1-2hr), L (2-4hr), XL (4-8hr), XXL (1+ day)
- **Why it matters:** User can gauge effort and prioritize
- **Risk flags:** Mark tasks touching: database schema, API contracts, security, core utilities
- **Critical path:** If tasks have dependencies, note which chain is longest
- **Totals:** Always provide both individual estimates AND total at bottom

### Code & Commands in Plans

- **Every code block must be complete:** No `...`, no "add this to that", no pseudocode
- **Exact file paths:** Always use full paths from repo root
- **Exact commands:** Show the full command and expected output/error
- **Expected outputs:** Show what success looks like: `PASSED`, `green`, specific output
- **Line references:** When modifying existing code, include line numbers: `path/to/file.py:123-145`
- **Test-first:** Lead with the failing test, then implementation

### Content & Structure

- **Header required:** Every plan starts with Goal, Architecture, Tech Stack, Principles, Effort, Risk
- **Performance section mandatory:** Effort Summary with individual + total estimates
- **Likely Affected Areas:** Hyperlink files on GitHub with line anchors when specific lines are known
- **Tasks labeled sequentially:** `Task 1:`, `Task 2:`, etc.; each has Size, Risk, Files
- **Files section per task:** Explicit list of Create/Modify/Test files with line numbers
- **Steps numbered 1-5:** Write test → Verify fail → Implement → Verify pass → Commit
- **Open Questions & Dependencies:** List anything blocking implementation; omit if none
- **Tracking marker:** Always append at the end: `<!-- gh-claude:issue-plan issue=${ISSUE_NUM} -->`

### Safety & Scope Boundaries

- **No implementation:** Never write code, edit files, or run commands (except git/gh queries)
- **No branches/commits:** Never create branches, commit, push, or open PRs
- **No build/test:** Never run build, test, formatter, linter, or package-manager commands
- **Plan-only focus:** Only safe to write `~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/` and create that directory
- **Respect focus area:** If user requests one aspect, don't plan the full issue

### Context Awareness

- **Working tree:** If local changes detected, note at top of plan
- **Labels & urgency:** Consider labels (bug, feature, urgent, security) when ordering tasks
- **Existing discussions:** Reference prior comments if they inform approach
- **Repository context:** Use language/framework/conventions of the repo
- **Dependencies:** Respect task ordering; earlier tasks shouldn't depend on later ones
- **Linked issues:** Auto-fetch and reference them; note if they're blocking

### Edge Cases

- **Very broad issues:** Recommend splitting; ask which area to plan
- **Too little context:** Use Open Questions section; don't invent details
- **Existing plan comment:** Find and update it (don't create duplicate)
- **Multiple focus areas:** Ask if user wants all or a specific area
- **Ambiguous requirements:** Flag in Open Questions; request clarification
- **Vague issue:** If issue doesn't explain what to build, ask before drafting
- **Closed issue:** Note state and confirm before planning

---

## Error Messages & Recovery

| Scenario                          | Action                                                          |
| --------------------------------- | --------------------------------------------------------------- |
| Issue number missing from arguments | Ask user: "Which issue? Pass the number as the first argument, e.g. `/gh-issue-plan 42 ...`" |
| `gh issue view` fails             | Show error, suggest `gh auth status`                            |
| Git unavailable                   | Skip working-tree check, proceed without that context           |
| Issue context unclear             | Use Open Questions; ask user to clarify before drafting         |
| User wants to split scope         | Ask which part to plan; restart from step 3                     |
| Comment API call fails            | Show full error, ask user to retry or cancel                    |
| Posting/updating fails            | Show error, suggest `gh auth status`                            |
| Plan has gaps                     | Revise and return to step 6; do NOT present incomplete plan     |
| Existing plan found               | Update it instead of creating duplicate                         |
| Conflict detected                 | Show conflict, ask user to confirm before proceeding            |
| Linked issue unavailable          | Note it, continue with what you have                            |
| Performance estimates unrealistic | Revise after user feedback in step 8                            |

---

## Template Library

Pick the closest template type and adapt the plan accordingly.

| Type | Tasks | Estimate | Focus |
| --- | --- | --- | --- |
| **Bug Fix** | 2-4 | Small (1-2 days) | Reproduction, root cause, fix, regression tests |
| **Feature** | 4-6 | Medium (3-5 days) | Tests, implementation, integration, edge cases |
| **Refactor** | 3-5 | Medium (2-4 days) | Test coverage first, gradual refactor, validate equivalence |
| **Migration** | 5-8 | Large (1+ weeks) | Compatibility layer, gradual migration, deprecation, cleanup |
| **Security** | 2-4 | Medium (1-3 days) | Minimal changes, comprehensive tests, audit trail (High risk) |
| **Documentation** | 2-3 | Small (1-2 days) | Example code that runs, clear prose, audience-appropriate |
