---
name: issue-develop
description: >
  Promotes a draft implementation plan (from /gh:issue-plan) into an
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

**This command bridges planning and implementation.** It takes the human-reviewed draft plan from `/gh:issue-plan` and sets up the development environment: branch, execution plan file, and draft PR. After this, the engineer (with or without agent assistance) implements the tasks.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` to verify)
- Directories: `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}` must be writable
- Write permissions on the repository
- Git repo with clean working tree (no uncommitted changes)
- A draft plan comment must exist on the issue (posted by `/gh:issue-plan`)

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

**Existing PR (current branch):**

```
!`CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo ""); DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main"); if [ -n "${CURRENT_BRANCH}" ] && [ "${CURRENT_BRANCH}" != "${DEFAULT_BRANCH}" ]; then gh pr list --head "${CURRENT_BRANCH}" --state open --json number,title,url --jq '.[] | "PR #\(.number): \(.title) (\(.url))"' 2>/dev/null || true; fi`
```

**Existing PR (expected branch):**

```
!`ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo ""); slug_from_title() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//;s/-$//' | cut -c1-50; }; TITLE_SLUG=$(slug_from_title "$(gh issue view "${ISSUE_NUM}" --json title --jq .title 2>/dev/null)"); GENERATED="${ISSUE_NUM}/${TITLE_SLUG}"; if [ "${GENERATED}" != "${CURRENT_BRANCH}" ]; then gh pr list --head "${GENERATED}" --state open --json number,title,url --jq '.[] | "PR #\(.number): \(.title) (\(.url))"' 2>/dev/null || true; fi`
```

**Existing Plan File:**

```
!`ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); ls .github/claude/plans/${ISSUE_NUM}-*.md 2>/dev/null || true`
```

**Session State:**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/gh-issue-develop-state.md" 2>/dev/null || true`
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
  - If no plan found, stop: "No draft plan found on issue #N. Run `/gh:issue-plan N` first to create one."
  - If plan found, extract it for expansion
- **Check working tree:** If uncommitted changes exist, stop: "You have uncommitted changes. Commit or stash them before running this command."
- **Check current branch:** If not on default branch, warn: "You're on branch '[name]', not the default branch. The new branch will be created from the latest 'origin/[default]'. Proceed?"
- **Detect matching branch:** Check if the current branch name contains the issue number as a distinct segment (e.g., for issue 42: `42/fix-login`, `issue-42`, `fix/42-login`, `42-fix-login` all match). If the current branch matches:
  - Skip branch creation entirely in step 8
  - Note in step 6: "Using current branch '[name]' (matches issue #N)"
  - If the current branch does NOT match and is not the default branch, warn as before
- **Check for existing PR:** If an open PR already exists for the current branch or the generated branch name, warn: "An open PR #N already exists for this branch. Running develop will commit the plan and update the existing PR context. Proceed, or use `/gh:pr-edit N` instead?"
- **Check for prior run (session state):** Load session state from `gh-issue-develop-state.md`. If it shows a partial run (e.g., `status: branch_created` or `status: plan_committed`), inform the user: "A previous run completed through [step]. Resume from [next step]?" If it shows `status: pr_created`, inform: "Development was already set up for #N. Re-run to update the plan, or view current status?"
- **Check for prior run (repo state):** If the "Existing Plan File" context block found a plan file for this issue in `.github/claude/plans/`, inform the user even if session state is empty (cross-session re-run): "A plan file already exists for #N at [path]. Update with a new plan, or view current status?" This check works across sessions because the repo is the source of truth.

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

- **If current branch already matches the issue** (detected in step 1), skip branch name generation entirely. Use the current branch as-is.
- Derive branch name from issue number and title:
  ```
  Format: <issue-number>/<slugified-title>
  Example: 42/fix-login-500-error
  ```
- Rules:
  - Lowercase, hyphens for spaces
  - Max 60 characters total — slug is truncated to 50 characters to leave room for the `<issue-number>/` prefix
  - Strip special characters
  - **Important:** Both the context block and step 8a define `slug_from_title()` with identical logic. If you change the slug pipeline, update both locations or the branch name check and creation will diverge.
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
**Created:** [YYYY-MM-DD]

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

## Progress Tracking

As you complete each task:

1. Update the task heading in this file: `[ ] Not started` → `[x] Complete`
2. Check off each acceptance criterion as it passes
3. Commit the updated plan file alongside the implementation
4. Update the corresponding task checkbox in the PR body (`gh pr edit --body`)
```

**Expansion rules:**

- **Preserve the draft plan's intent:** Don't redesign; expand and add detail
- **Add file-level specificity:** Exact paths, line numbers where known, new vs. modify
- **Add acceptance criteria per task:** Specific, verifiable conditions
- **Add test strategy per task:** What to test, not the test code itself
- **Add commit message per task:** Following repo conventions (conventional commits if used)
- **Task status checkboxes:** `[ ] Not started` for all tasks (tracked during implementation)
- **No complete code blocks:** This is still a plan, not an implementation. Code comes during task execution.
- **Keep expansion proportional:** The execution plan should be roughly 2–3x the length of the draft plan. Each task section should be 10–20 lines. If the plan exceeds 500 lines total, it's likely over-specified — consolidate. If the draft plan itself is already 200+ lines, the expansion should add specificity (file paths, acceptance criteria) without repeating prose — aim for 1.5–2x rather than 2–3x.

### 5. **Validate Execution Plan**

Before presenting to user, conduct a validation review:

**Check:**

| Check                      | Validation                                                               | Action if Failed                                                    |
| -------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| **Draft intent preserved** | Expansion didn't redesign the draft plan's approach?                     | Revert to draft intent; expand without changing direction           |
| **File paths valid**       | Paths are real (from repo) or explicitly marked as new?                  | Verify paths exist or mark as "(new)"                               |
| **Acceptance criteria**    | Each task has specific, verifiable criteria?                             | Replace vague criteria ("works correctly") with testable conditions |
| **Test strategy present**  | Each task describes what to test, not test code?                         | Add test strategy; remove any implementation code                   |
| **Commit messages**        | Follow repo conventions (conventional commits if used)?                  | Detect convention and match                                         |
| **Task count matches**     | Same number of tasks as draft plan?                                      | Don't add or remove tasks during expansion                          |
| **No implementation code** | Plan contains no code blocks beyond brief snippets?                      | Remove code; describe the change in prose                           |
| **Branch name valid**      | Follows naming rules, under 60 chars?                                    | Adjust slug length or format                                        |
| **Issue link correct**     | Issue number and URL are accurate?                                       | Verify against fetched issue data                                   |
| **Plan length**            | Roughly 2–3x draft length? Each task 10–20 lines? Under 500 lines total? | Consolidate over-specified sections; remove redundancy              |

**If any check fails:** Revise the execution plan before step 6. Do NOT proceed with a flawed plan.

### 6. **Present for Confirmation**

Show what will happen:

```
---
**Ready to begin development for issue #N: [Title]**

**Actions I will take:**
1. Create branch: `42/fix-login-500-error` from `origin/main` (or "Using existing branch: `issue-42`" if current branch matches)
2. Save execution plan to: `.github/claude/plans/42-fix-login-500-error.md`
3. Commit: `docs(plan): add execution plan for #42`
4. Push branch and open draft PR (assigned to you)

**Execution plan preview:**

[FULL EXECUTION PLAN]

---

_Proceed, or tell me what to change?_
```

### 7. **Handle User Feedback**

- **If user confirms** (`"proceed"`, `"yes"`, `"looks good"`, `"👍"`): Proceed to step 8
- **If user requests changes to the plan**: Revise and return to step 5 → 6 (max 3 rounds — repeated revisions consume context window and yield diminishing returns; after 3 rounds, suggest editing the plan file directly in `.github/claude/plans/` post-creation)
- **If user wants to change the branch name**: Update and return to step 5 → 6
- **If user says cancel** (`"no"`, `"cancel"`): Stop
- **If no response**: Ask once more: "Should I proceed with creating the branch and draft PR?"

### 8. **Execute: Branch, Save, Commit, PR**

Run the following sub-steps in order. If any fails, stop and show the error — do NOT continue with partial state.

**Before executing, re-verify prerequisites** — the user may have taken minutes to review the plan:

- Check working tree is still clean (`git status --short`). If dirty, stop: "Working tree changed since validation. Commit or stash before proceeding."
- If creating a new branch, verify it still doesn't exist (checked below in 8a).

**8a. Derive variables and create branch:**

```bash
# Derive all variables from arguments and issue context
ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#')
SESSION_DIR="${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}"
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
if [ -z "${REPO}" ]; then echo "ERROR: Unable to determine repository. Check gh auth status."; exit 1; fi

# Detect if current branch already matches this issue
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
SKIP_BRANCH_CREATION=false
if echo "${CURRENT_BRANCH}" | grep -qE "(^|[^0-9])${ISSUE_NUM}([^0-9]|$)"; then
  SKIP_BRANCH_CREATION=true
  BRANCH_NAME="${CURRENT_BRANCH}"
fi

ISSUE_TITLE=$(gh issue view "${ISSUE_NUM}" --json title --jq .title 2>/dev/null)
# Canonical slug pipeline — must match the one in "Existing PR (expected branch)" context block
slug_from_title() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//;s/-$//' | cut -c1-50; }
TITLE_SLUG=$(slug_from_title "${ISSUE_TITLE}")
if [ "${SKIP_BRANCH_CREATION}" != "true" ]; then
  BRANCH_NAME="${ISSUE_NUM}/${TITLE_SLUG}"
fi
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main")
BASE_BRANCH="${DEFAULT_BRANCH}"
MAYBE_BASE=$(echo "$ARGUMENTS" | awk '{for(i=1;i<=NF;i++) if($i=="--base") print $(i+1)}')
if [ -n "${MAYBE_BASE}" ]; then BASE_BRANCH="${MAYBE_BASE}"; fi

# Create and switch to the new branch (skip if already on a matching branch)
if [ "${SKIP_BRANCH_CREATION}" != "true" ]; then
  # Check if branch already exists
  if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    # Local branch exists — treat as resumable partial progress
    echo "Local branch '${BRANCH_NAME}' already exists — switching to it"
    git checkout "${BRANCH_NAME}"
    # Check if it's been pushed; if not, step 8e will handle the push
    if ! git ls-remote --exit-code --heads origin "${BRANCH_NAME}" >/dev/null 2>&1; then
      echo "Note: branch exists locally but not on remote — push will happen in step 8e"
    fi
  elif git ls-remote --exit-code --heads origin "${BRANCH_NAME}" >/dev/null 2>&1; then
    # Remote branch exists but not local — fetch and track it
    echo "Remote branch '${BRANCH_NAME}' exists — fetching and tracking"
    git fetch origin "${BRANCH_NAME}"
    git checkout -b "${BRANCH_NAME}" "origin/${BRANCH_NAME}"
  else
    # Branch is new — create from remote base
    git fetch origin "${BASE_BRANCH}"
    git checkout -b "${BRANCH_NAME}" "origin/${BASE_BRANCH}"
  fi
fi
mkdir -p .github/claude/plans

# Write incremental session state: branch created
mkdir -p "${SESSION_DIR}/state"
cat > "${SESSION_DIR}/state/gh-issue-develop-state.md" << EOFSTATE
---
issue: ${ISSUE_NUM}
branch: ${BRANCH_NAME}
plan_path: .github/claude/plans/${ISSUE_NUM}-${TITLE_SLUG}.md
status: branch_created
---
EOFSTATE
```

**8b. Save execution plan to repo:**

Check if `.github/claude/plans/${ISSUE_NUM}-${TITLE_SLUG}.md` already exists. If it does, warn: "Plan file already exists from a previous run. Overwrite with the new plan, or abort?" If the user confirms, proceed. Then use the Write tool to save the execution plan.

**8c. Commit the plan (skip if unchanged):**

```bash
PLAN_FILE=".github/claude/plans/${ISSUE_NUM}-${TITLE_SLUG}.md"
git add "${PLAN_FILE}"

# Check if there's anything to commit
if git diff --cached --quiet; then
  echo "Plan file unchanged — skipping commit"
  PLAN_COMMITTED=false
else
  # Use appropriate message for new vs. updated plan
  if git log --oneline -1 -- "${PLAN_FILE}" 2>/dev/null | grep -q .; then
    git commit -m "docs(plan): update execution plan for #${ISSUE_NUM}"
  else
    git commit -m "docs(plan): add execution plan for #${ISSUE_NUM}"
  fi
  PLAN_COMMITTED=true
  # Update session state: plan committed (portable across macOS and Linux)
  if sed --version >/dev/null 2>&1; then
    sed -i 's/status: branch_created/status: plan_committed/' "${SESSION_DIR}/state/gh-issue-develop-state.md"
  else
    sed -i '' 's/status: branch_created/status: plan_committed/' "${SESSION_DIR}/state/gh-issue-develop-state.md"
  fi
fi
```

**8d. Save PR body:**

Use the Write tool to save the PR body to `${SESSION_DIR}/drafts/develop_pr_body.md` (create the directory first: `mkdir -p "${SESSION_DIR}/drafts"`). Resolve all `${...}` variables with actual values from step 8a. Populate task names and count from the execution plan.

**8e. Create draft PR (skip if PR already exists):**

If an open PR already exists for the branch (detected in step 1):

- Check whether a new commit was created by reading the session state file (`grep -q 'status: plan_committed' "${SESSION_DIR}/state/gh-issue-develop-state.md"`). This is necessary because `PLAN_COMMITTED` from step 8c doesn't survive across separate tool invocations.
- If the plan was committed, regenerate the PR body (step 8d) and update the existing PR:
  ```bash
  PR_NUMBER=$(gh pr list --head "${BRANCH_NAME}" --state open --json number --jq '.[0].number' 2>/dev/null)
  gh pr edit "${PR_NUMBER}" --body-file "${SESSION_DIR}/drafts/develop_pr_body.md"
  ```
  Note to user: "Updated PR #N body to match the revised plan."
- If the plan was not committed (status is still `branch_created`), skip entirely: "PR #N exists and plan is unchanged. Nothing to update."

Otherwise, push the branch (idempotent — safe if already pushed) and create the draft PR:

```bash
git push -u origin "${BRANCH_NAME}" 2>/dev/null || git push origin "${BRANCH_NAME}"
gh pr create \
  --draft \
  --title "${ISSUE_TITLE}" \
  --body-file "${SESSION_DIR}/drafts/develop_pr_body.md" \
  --base "${BASE_BRANCH}"
# Assign separately so older gh versions don't break PR creation
PR_NUMBER=$(gh pr list --head "${BRANCH_NAME}" --state open --json number --jq '.[0].number' 2>/dev/null)
gh pr edit "${PR_NUMBER}" --add-assignee @me 2>/dev/null || true
```

**Draft PR body structure** (save to `${SESSION_DIR}/drafts/develop_pr_body.md` before running `gh pr create`):

```markdown
## Summary

- Closes #${ISSUE_NUM}: ${ISSUE_TITLE}.
- [Claude execution plan](https://github.com/${REPO}/blob/${BRANCH_NAME}/.github/claude/plans/${ISSUE_NUM}-${TITLE_SLUG}.md).

## Tasks

- [ ] Task 1: [name from plan]
- [ ] Task 2: [name from plan]
- [ ] Task 3: [name from plan]
```

All `${...}` variables are derived in step 8a. Task names and count come from the execution plan. The Write tool must resolve all variables before saving.

### 9. **Confirm Success**

- Update session state to final form — add `pr_number`, `created` timestamp (use `date -u +%Y-%m-%dT%H:%M:%SZ`), and set `status: pr_created`:

  ```yaml
  ---
  issue: 42
  branch: 42/fix-login-500-error
  plan_path: .github/claude/plans/42-fix-login-500-error.md
  pr_number: 87
  created: 2026-03-20T14:30:00Z
  status: pr_created
  ---
  ```

  Substitute with actual values from step 8a. This is the final state — earlier sub-steps wrote `status: branch_created` and `status: plan_committed` incrementally.

- On success, show:

  ```
  Development environment ready for issue #N

  Branch:  42/fix-login-500-error
  Plan:    .github/claude/plans/42-fix-login-500-error.md
  PR:      #M (draft) — [URL]

  Next steps:
  - Review the execution plan in .github/claude/plans/
  - Implement tasks in order
  - Update task checkboxes in both the plan file and PR body as you complete them
  - Before marking PR as ready, clean up .github/claude/plans/ or keep as documentation
  - Mark PR as ready for review when done
  ```

- On failure at any step:
  - Show the full error
  - Show which steps completed and which didn't
  - Suggest recovery:
    - Branch creation failed: "Branch may already exist. Check with `git branch -a`"
    - Commit failed: "Check `git status` for issues"
    - Push failed: "Check remote access and branch protection rules"
    - PR creation failed: "Verify `gh auth status` and check if a PR already exists for this branch"

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
- **Plan lives in repo:** `.github/claude/plans/` directory, committed with the branch
- **Standardized PR format:** This command uses a fixed PR body (plan link + task checklist). Repo PR templates are not applied — the develop PR is a scaffold, not a final description. The engineer can update it before marking ready.
- **Plan lifecycle:** The plan file in `.github/claude/plans/` is useful during development. Before marking the PR as ready, the engineer may remove it in a cleanup commit or keep it as project documentation — this is a team preference.

### Safety & Permissions

- **Clean working tree required:** Don't create branches with uncommitted changes
- **Default branch check:** Warn if not on default branch before branching
- **Existing branch check:** Don't clobber existing branches
- **Fail fast:** If any step in step 8 fails, stop immediately and show recovery steps for whatever completed (earlier steps may have succeeded, leaving a branch or commit). Session state is written incrementally, so re-runs can detect and resume from partial progress.
- **Never implement:** This command creates the plan and PR scaffold. It does not write implementation code.

### Edge Cases

- **No plan exists:** Stop and redirect to `/gh:issue-plan N`
- **Plan has critical open questions:** Warn but allow proceeding
- **Branch already exists:** Ask to switch to it or use a different name
- **Dirty working tree:** Stop; ask to commit or stash
- **Not on default branch:** Warn and confirm
- **Plan was updated since last read:** Always fetch fresh from the issue comment
- **PR already exists for branch:** Skip PR creation; commit the plan only. Note the existing PR and suggest `/gh:pr-edit N` to update its description.
- **Already on matching branch:** Skip branch creation; use current branch. Note this in the confirmation step.
- **Plan file already exists:** Warn before overwriting; the file may be from a previous run or another branch.

---

## Error Messages & Recovery

| Scenario                           | Action                                                                                                                                                                |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Issue number missing               | Ask user: "Which issue? e.g. `/gh:issue-develop 42`"                                                                                                                  |
| No draft plan found on issue       | Stop: "No plan found. Run `/gh:issue-plan N` first."                                                                                                                  |
| `gh auth status` fails             | Show error, suggest `gh auth login`                                                                                                                                   |
| Working tree is dirty              | Stop: "Uncommitted changes. Commit or stash before proceeding."                                                                                                       |
| Not on default branch              | Warn: "You're on '[branch]'. New branch will be created from the latest 'origin/[default]'. Proceed?"                                                                 |
| Branch already exists (local)      | Switch to it automatically (resumable partial progress); note to user                                                                                                 |
| Branch already exists (remote)     | Fetch and track it automatically; note to user                                                                                                                        |
| `git checkout -b` fails            | Show error; suggest checking branch state with `git branch -a`                                                                                                        |
| `git commit` fails                 | Show error; suggest `git status`                                                                                                                                      |
| `git fetch origin` fails           | Show error; suggest checking network connectivity and remote access                                                                                                   |
| `git push` fails                   | Show error; suggest checking remote access, branch protection rules, and `gh auth status`                                                                             |
| `gh pr create` fails               | Show error; suggest verifying auth (`gh auth status`) and checking if PR already exists                                                                               |
| Plan file already exists           | Warn: "Plan file exists from a previous run. Overwrite, or abort?"                                                                                                    |
| Plan has unresolved open questions | Warn: "Plan has open questions. Proceed anyway?"                                                                                                                      |
| Plan has unresolved dependencies   | Warn: "Dependency PR #N is still open. Proceed anyway?"                                                                                                               |
| Issue is closed                    | Warn: "Issue #N is closed. Still create development branch?"                                                                                                          |
| Validation detects issues          | Revise in step 5; do NOT present flawed execution plan                                                                                                                |
| PR already exists for branch       | Skip PR creation; note "PR #N exists. Plan committed. Use `/gh:pr-edit N` to update."                                                                                 |
| Already on matching branch         | Skip branch creation; note "Using current branch '[name]'" in confirmation                                                                                            |
| Re-run: plan unchanged             | Skip commit; note "Plan file unchanged — nothing to commit"                                                                                                           |
| Re-run: plan updated, PR exists    | Update PR body automatically; note "Updated PR #N body to match revised plan"                                                                                         |
| Re-run: branch exists locally only | Switch to it; push will happen in step 8e                                                                                                                             |
| Re-run: partial state detected     | Show completed steps; offer to resume from next step                                                                                                                  |
| User wants to undo after step 8    | `gh pr close ${PR_NUMBER} --delete-branch` to close PR and delete remote branch; `git checkout ${DEFAULT_BRANCH} && git branch -D ${BRANCH_NAME}` to clean up locally |
| User interrupts during execution   | Show which steps completed; suggest recovery for partial state                                                                                                        |
