---
description: >
  Promotes a draft implementation plan (from /gh-issue-plan) into an
  execution-ready plan, creates a feature branch, saves the plan as a
  markdown file in the repo, commits it, and opens a draft PR. This is
  the transition from planning to implementation.
argument-hint: "<issue-number> [--base branch]"
disable-model-invocation: true
allowed-tools: Bash(*), Write
---

# Promote Plan to Execution

## Mode: DEVELOP — PLAN → BRANCH → COMMIT → DRAFT PR

Your role: **find the draft plan → expand it into an execution-ready plan → create a branch → save the plan in the repo → commit → open a draft PR.**

**This command bridges planning and implementation.** It takes the human-reviewed draft plan from `/gh-issue-plan` and sets up the development environment: branch, execution plan file, and draft PR. After this, the engineer (with or without agent assistance) implements the tasks.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` to verify)
- Directories: `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}` must be writable
- Write permissions on the repository
- Git repo with clean working tree (no uncommitted changes)
- A draft plan comment must exist on the issue (posted by `/gh-issue-plan`)

## Context

**Issue Number:**

```
!`echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'`
```

**Current Issue (always fresh):**

```
!`ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); gh issue view "${ISSUE_NUM}" --json number,title,url,body,state,labels,comments 2>/dev/null | jq -r -f "${CLAUDE_PLUGIN_ROOT}/queries/gh_issue_view.jq" || echo "Unable to fetch issue. Check the issue number and gh auth status."`
```

**Draft Plan (from issue comments):**

```
!`ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)"; gh api "repos/${REPO}/issues/${ISSUE_NUM}/comments" --paginate 2>/dev/null | jq -rs --arg marker "<!-- gh-claude:issue-plan issue=${ISSUE_NUM} -->" '[.[][] | select(.body | contains($marker))] | last | .body // empty' || echo "Unable to fetch plan comment."`
```

**Repository Info:**

```
!`gh repo view --json url,defaultBranchRef,languages,description 2>/dev/null | jq -r -f "${CLAUDE_PLUGIN_ROOT}/queries/gh_repo_view.jq" || echo "Unable to fetch repo info."`
```

**Working Tree Status:**

```
!`git status --short 2>/dev/null || echo "Not a git repo or git unavailable."`
```

**Current Branch:**

```
!`echo "Branch: $(git branch --show-current 2>/dev/null || echo unknown)"; DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main"); echo "Default: ${DEFAULT_BRANCH}"`
```

**Session State:**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/develop_session.md" 2>/dev/null || true`
```

**Session Notes (optional, non-authoritative):**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/session_notes.md" 2>/dev/null || true`
```

**User Request:**

```
!`echo "$ARGUMENTS"`
```

## Workflow

### 1. **Validate Prerequisites**

- Parse issue number from the first argument; if missing or not a number, ask the user
- Verify `gh` authentication; if not authenticated, stop and ask user to run `gh auth login`
- Fetch issue details; if fetch fails, stop and show error
- **Find the draft plan:** Look for a comment containing `<!-- gh-claude:issue-plan issue=N -->` on the issue
  - If no plan found, stop: "No draft plan found on issue #N. Run `/gh-issue-plan N` first to create one."
  - If plan found, extract it for expansion
- **Check working tree:** If uncommitted changes exist, stop: "You have uncommitted changes. Commit or stash them before running this command."
- **Check current branch:** If not on default branch, warn: "You're on branch '[name]', not the default branch. The new branch will be created from your current branch. Switch to [default] first, or proceed?"
- Load session state: check if this develop flow was already started for this issue

### 2. **Parse Arguments & Plan**

- **Parse user arguments for:**
  - Base branch: `--base develop` (defaults to repo default branch)

- **Parse the draft plan for:**
  - Plan type (Bug Fix, Feature, Refactor, etc.)
  - Task list with estimates
  - Affected areas (file paths)
  - Open questions and dependencies
  - Risk level

- **Check for blockers:**
  - If Open Questions in the plan are critical (e.g., "Which database table?"), warn: "The plan has unresolved questions that may block implementation. Proceed anyway?"
  - If Dependencies list items that are not merged/resolved, warn: "Dependency PR #99 is still open. Proceed anyway?"

### 3. **Generate Branch Name**

- Derive branch name from issue number and title:
  ```
  Format: <issue-number>/<slugified-title>
  Example: 42/fix-login-500-error
  ```
- Rules:
  - Lowercase, hyphens for spaces
  - Max 60 characters (truncate title slug if needed)
  - Strip special characters
- Check if branch already exists locally or remotely:
  - If exists locally: "Branch '42/fix-login-500-error' already exists. Switch to it, or use a different name?"
  - If exists remotely only: "Remote branch exists. Fetch and track it, or use a different name?"

### 4. **Expand Plan to Execution Format**

Transform the high-level draft plan into an execution-ready plan. This is the detailed version that lives in the repo and guides implementation.

**Execution plan structure:**

```markdown
# [Feature/Fix Name] — Execution Plan

**Issue:** [#N](url) — [title]
**Branch:** `<branch-name>`
**Type:** [Bug Fix | Feature | Refactor | Migration | Security | Documentation]
**Estimate:** [from draft plan]
**Risk:** [from draft plan]
**Created:** [date]

---

## Goal

[From draft plan — preserved as-is]

## Approach

[From draft plan — preserved as-is, may add implementation-specific notes]

## Affected Areas

[From draft plan — preserved, with line numbers added where known]

- `path/to/file.ext:L10-L45` — [why]
- `path/to/new_file.ext` (new) — [why]
- `tests/path/to/test_file.ext` (new) — [test coverage for what]

## Tasks

### Task 1: [Name] — [Size] — [ ] Not started

**What:** [From draft plan task description]

**Files:**

- Modify: `path/to/file.ext`
- Create: `path/to/new_file.ext`
- Test: `tests/path/to/test_file.ext`

**Test strategy:** [What to test; key scenarios and edge cases]

**Acceptance criteria:**

- [ ] [Specific, verifiable criterion]
- [ ] [Specific, verifiable criterion]

**Commit message:** `<type>: <description>`

---

### Task 2: [Name] — [Size] — [ ] Not started

[Same structure as Task 1]

---

## Task Dependencies

[From draft plan — preserved]

## Open Questions

[From draft plan — preserved; mark any resolved during expansion]

## Dependencies & Blockers

[From draft plan — preserved]
```

**Expansion rules:**

- **Preserve the draft plan's intent:** Don't redesign; expand and add detail
- **Add file-level specificity:** Exact paths, line numbers where known, new vs. modify
- **Add acceptance criteria per task:** Specific, verifiable conditions
- **Add test strategy per task:** What to test, not the test code itself
- **Add commit message per task:** Following repo conventions (conventional commits if used)
- **Task status checkboxes:** `[ ] Not started` for all tasks (tracked during implementation)
- **No complete code blocks:** This is still a plan, not an implementation. Code comes during task execution.

### 5. **Validate Execution Plan**

Before presenting to user, conduct a validation review:

**Check:**

| Check                      | Validation                                                | Action if Failed                                          |
| -------------------------- | --------------------------------------------------------- | --------------------------------------------------------- |
| **Draft intent preserved** | Expansion didn't redesign the draft plan's approach?      | Revert to draft intent; expand without changing direction  |
| **File paths valid**       | Paths are real (from repo) or explicitly marked as new?   | Verify paths exist or mark as "(new)"                     |
| **Acceptance criteria**    | Each task has specific, verifiable criteria?               | Replace vague criteria ("works correctly") with testable conditions |
| **Test strategy present**  | Each task describes what to test, not test code?           | Add test strategy; remove any implementation code          |
| **Commit messages**        | Follow repo conventions (conventional commits if used)?   | Detect convention and match                               |
| **Task count matches**     | Same number of tasks as draft plan?                        | Don't add or remove tasks during expansion                |
| **No implementation code** | Plan contains no code blocks beyond brief snippets?        | Remove code; describe the change in prose                 |
| **Branch name valid**      | Follows naming rules, under 60 chars?                      | Adjust slug length or format                              |
| **Issue link correct**     | Issue number and URL are accurate?                         | Verify against fetched issue data                         |

**If any check fails:** Revise the execution plan before step 6. Do NOT proceed with a flawed plan.

### 6. **Present for Confirmation**

Show what will happen:

```
---
**Ready to begin development for issue #N: [Title]**

**Actions I will take:**
1. Create branch: `42/fix-login-500-error` from `main`
2. Save execution plan to: `.claude/plans/42-fix-login-500-error.md`
3. Commit: `docs(plan): add execution plan for #42`
4. Push branch and open draft PR

**Execution plan preview:**

[FULL EXECUTION PLAN]

---

_Proceed, or tell me what to change?_
```

### 7. **Handle User Feedback**

- **If user confirms** (`"proceed"`, `"yes"`, `"looks good"`, `"👍"`): Proceed to step 8
- **If user requests changes to the plan**: Revise and return to step 5 → 6
- **If user wants to change the branch name**: Update and return to step 5 → 6
- **If user says cancel** (`"no"`, `"cancel"`): Stop
- **If no response**: Ask once more: "Should I proceed with creating the branch and draft PR?"

### 8. **Execute: Branch, Save, Commit, PR**

Run the following steps. If any step fails, stop and show the error — do NOT continue with partial state.

```bash
ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#')
SESSION_DIR="${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}"

# Step 1: Create and switch to the new branch
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main")
# Use --base if provided, otherwise default branch
BASE_BRANCH="${USER_SPECIFIED_BASE:-$DEFAULT_BRANCH}"
git checkout -b "${BRANCH_NAME}" "${BASE_BRANCH}"
```

```bash
# Step 2: Create plans directory and save the execution plan
mkdir -p .claude/plans
# (Use Write tool to save the execution plan to .claude/plans/${ISSUE_NUM}-${TITLE_SLUG}.md)
```

```bash
# Step 3: Commit the plan
git add .claude/plans/
git commit -m "docs(plan): add execution plan for #${ISSUE_NUM}"
```

```bash
# Step 4: Save the draft PR body and create the PR
mkdir -p "${SESSION_DIR}/drafts"
# (Use Write tool to save the PR body to ${SESSION_DIR}/drafts/develop_pr_body.md)
gh pr create \
  --draft \
  --title "[WIP] ${ISSUE_TITLE}" \
  --body-file "${SESSION_DIR}/drafts/develop_pr_body.md"
```

**Draft PR body structure** (save to `${SESSION_DIR}/drafts/develop_pr_body.md` before running `gh pr create`):

```markdown
## Summary

Execution plan for #N: [title]

## Plan

See [`.claude/plans/N-slug.md`](link) for the full execution plan.

## Status

- [ ] Task 1: [name]
- [ ] Task 2: [name]
- [ ] Task 3: [name]

## Notes

- This PR was created by `/gh-issue-develop` from the approved implementation plan
- Plan is in `.claude/plans/` and can be updated as implementation progresses

Closes #N
```

### 9. **Confirm Success**

- Update session state: track issue number, branch name, plan path, PR number, and timestamp in `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/develop_session.md`
- On success, show:

  ```
  Development environment ready for issue #N

  Branch:  42/fix-login-500-error
  Plan:    .claude/plans/42-fix-login-500-error.md
  PR:      #M (draft) — [URL]

  Next steps:
  - Review the execution plan in .claude/plans/
  - Implement tasks in order
  - Update task checkboxes as you complete them
  - Mark PR as ready for review when done
  ```

- On failure at any step:
  - Show the full error
  - Show which steps completed and which didn't
  - Suggest recovery:
    - Branch creation failed: "Branch may already exist. Check with `git branch -a`"
    - Commit failed: "Check `git status` for issues"
    - PR creation failed: suggest `git push -u origin HEAD` then `gh pr create --draft`

---

## Rules & Guidelines

### Plan Expansion

- **Preserve draft intent:** The execution plan expands the draft; it doesn't redesign it
- **Add specificity, not code:** File paths, line numbers, acceptance criteria, test strategy — but not implementation code
- **Acceptance criteria are verifiable:** "Returns 401 for expired tokens" not "handles auth properly"
- **Test strategy, not test code:** "Test expired token, missing token, and valid token cases" not full pytest code
- **Commit messages follow conventions:** Detect repo convention (conventional commits, etc.) and match

### Branch & PR

- **Branch naming:** `<issue-number>/<slugified-title>`, max 60 chars
- **Always draft PR:** The PR starts as draft; engineer marks ready when done
- **PR links to issue:** Body includes `Closes #N`
- **PR body is minimal:** Points to the plan file; includes task checklist for at-a-glance status
- **Plan lives in repo:** `.claude/plans/` directory, committed with the branch

### Safety & Permissions

- **Clean working tree required:** Don't create branches with uncommitted changes
- **Default branch check:** Warn if not on default branch before branching
- **Existing branch check:** Don't clobber existing branches
- **Atomic execution:** If any step in step 8 fails, stop immediately — don't leave partial state
- **Never implement:** This command creates the plan and PR scaffold. It does not write implementation code.

### Edge Cases

- **No plan exists:** Stop and redirect to `/gh-issue-plan N`
- **Plan has critical open questions:** Warn but allow proceeding
- **Branch already exists:** Ask to switch to it or use a different name
- **Dirty working tree:** Stop; ask to commit or stash
- **Not on default branch:** Warn and confirm
- **Plan was updated since last read:** Always fetch fresh from the issue comment
- **PR already exists for a branch with same name:** Note and ask how to proceed

---

## Error Messages & Recovery

| Scenario                           | Action                                                                      |
| ---------------------------------- | --------------------------------------------------------------------------- |
| Issue number missing               | Ask user: "Which issue? e.g. `/gh-issue-develop 42`"                        |
| No draft plan found on issue       | Stop: "No plan found. Run `/gh-issue-plan N` first."                        |
| `gh auth status` fails             | Show error, suggest `gh auth login`                                         |
| Working tree is dirty              | Stop: "Uncommitted changes. Commit or stash before proceeding."             |
| Not on default branch              | Warn: "You're on '[branch]'. New branch will fork from here. Switch first?" |
| Branch already exists (local)      | Ask: "Branch exists. Switch to it, or use a different name?"                |
| Branch already exists (remote)     | Ask: "Remote branch exists. Fetch it, or use a different name?"             |
| `git checkout -b` fails            | Show error; suggest checking branch state with `git branch -a`              |
| `git commit` fails                 | Show error; suggest `git status`                                            |
| `gh pr create` fails (push)        | Show error; suggest `git push -u origin HEAD` then retry                    |
| `gh pr create` fails (auth)        | Show error; suggest `gh auth status`                                        |
| Plan has unresolved open questions | Warn: "Plan has open questions. Proceed anyway?"                            |
| Plan has unresolved dependencies   | Warn: "Dependency PR #N is still open. Proceed anyway?"                     |
| Issue is closed                    | Warn: "Issue #N is closed. Still create development branch?"                |
