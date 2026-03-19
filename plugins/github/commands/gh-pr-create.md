---
description: >
  Drafts a new GitHub pull request with title and structured body generated from
  the current branch's diff and commits, detects PR templates, validates for
  quality, then creates it after explicit user confirmation.
argument-hint: "[description or intent] [--draft] [--base branch] [--label label1,label2] [--reviewer user1,user2]"
disable-model-invocation: true
allowed-tools: Bash(*), Write
---

# Create GitHub Pull Requests

## Mode: CREATE-ONLY

Your role: **analyze the branch → gather diff and commit context → detect templates → detect conflicts → draft title and body → validate for quality → present for review → incorporate feedback → create the PR.**

**Creating the PR** means opening a new pull request on GitHub. It does NOT mean: implementing anything, merging, writing code, running tests, or making any other changes to the repo.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` to verify)
- Directories: `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}` must be writable
- Write permissions on the repository
- Git repo with current branch ahead of base branch (commits to include in the PR)

## Context

**Repository Info:**

```
!`gh repo view --json url,defaultBranchRef,languages,description 2>/dev/null | jq -r -f "${CLAUDE_PLUGIN_ROOT}/queries/gh_repo_view.jq" || echo "Unable to fetch repo info. Check gh auth status."`
```

**Branch Info:**

```
!`DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main"); echo "Current branch: $(git branch --show-current 2>/dev/null || echo unknown)"; echo "Default branch: ${DEFAULT_BRANCH}"; echo "Ahead: $(git rev-list --count "${DEFAULT_BRANCH}"..HEAD 2>/dev/null || echo unknown) commit(s)"; echo "Behind: $(git rev-list --count HEAD.."${DEFAULT_BRANCH}" 2>/dev/null || echo unknown) commit(s)"; echo "Remote tracking: $(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo 'not set')"`
```

**Diff Stat:**

```
!`DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main"); git diff --stat "${DEFAULT_BRANCH}"...HEAD 2>/dev/null || echo "Unable to compute diff stat."`
```

**Commits on Branch:**

```
!`DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "main"); git log --oneline "${DEFAULT_BRANCH}"..HEAD 2>/dev/null || echo "No commits ahead of ${DEFAULT_BRANCH}."`
```

**Available PR Templates:**

```
!`if [ -f .github/PULL_REQUEST_TEMPLATE.md ]; then echo "Template: PULL_REQUEST_TEMPLATE.md"; echo "---"; cat .github/PULL_REQUEST_TEMPLATE.md; elif [ -d .github/PULL_REQUEST_TEMPLATE ]; then find .github/PULL_REQUEST_TEMPLATE -type f -name '*.md' -exec basename {} \; 2>/dev/null | sort; else echo "No PR templates found."; fi`
```

**Session State (draft tracking):**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/create_session.md" 2>/dev/null || true`
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

### 1. **Validate & Fetch**

- Verify `gh` authentication; if not authenticated, stop and ask user to run `gh auth login`
- Fetch repository info (URL, default branch, languages, description); if fetch fails, stop and show error
- Check current branch is not the default branch; if on default branch, stop: "You're on the default branch. Create or switch to a feature branch first."
- Check there are commits ahead of base; if none, stop: "No commits to include in a PR. Commit your changes first."
- Check for uncommitted changes; if found, warn: "You have uncommitted changes that won't be included in the PR."
- Load session state: check if there's an existing draft from this session

### 2. **Smart Argument Parsing**

- **Parse user arguments for:**
  - PR description/intent (the main text, if provided)
  - Base branch: `--base develop` (defaults to repo default branch)
  - Draft mode: `--draft` flag
  - Labels: `--label bug,enhancement`
  - Reviewers: `--reviewer user1,user2`
  - Assignees: `--assignee username`
  - Linked issues: references like "fixes #42", "closes #15"

- **Detect PR template:**
  - Check `.github/PULL_REQUEST_TEMPLATE.md` (single template)
  - Check `.github/PULL_REQUEST_TEMPLATE/` directory (multiple templates)
  - If templates found, use the template structure for the body
  - If multiple templates exist, present choices: "Found these templates: [list]. Which fits best?"

- **Resume option:**
  - If session state shows unsaved draft, ask: "You have a PR draft from [timestamp]. Resume, start fresh, or discard?"

### 3. **Clarify Intent (If Needed)**

- **If description provided:** Confirm scope ("I'll draft a PR for adding dark mode support")
- **If no description:** Infer intent from branch name, commits, and diff — confirm: "Based on the commits, this PR adds [summary]. Correct?"
- If branch has unrelated commits (multiple distinct concerns), suggest splitting or ask which to focus on
- If the diff is very large (1000+ lines), ask if a summary description is sufficient or if the user wants detailed coverage

### 4. **Detect Conflicts & Contradictions**

**Before drafting, check for:**

- **Existing PR:** Check if an open PR already exists for this branch; if found, stop: "An open PR already exists for this branch: #N. Use `/gh-pr-edit N` to modify it."
- **Base branch divergence:** If base branch is significantly ahead, warn: "Base branch is N commits ahead. Consider rebasing before creating the PR."
- **Session conflicts:** If earlier draft in session contradicts current intent, ask: "Earlier you drafted a different PR. Start fresh?"
- **Uncommitted changes:** If working tree is dirty, remind user those changes won't be in the PR
- **Unpushed commits:** If local branch is ahead of remote, note that commits will be pushed

**If conflicts detected:**

- Show conflict summary
- Ask user to confirm: "Proceed anyway?" or "Let me know what changed"
- Do NOT proceed without confirmation

### 5. **Draft the PR**

Generate a title and structured body from the diff, commits, and user description.

**Title:**

- Imperative mood, under 72 characters
- Derived from: user description, branch name, or commit messages
- Examples: "Add dark mode support to settings page", "Fix login 500 error on expired sessions"

**Body structure** (adapt if PR template exists):

```markdown
## Summary

[What changed and why — 2-3 sentences derived from commits and diff]

## Changes

[Logical groups of changes, referencing relevant files]

- **[area]:** [what changed]
- **[area]:** [what changed]

## Risk Level

[Low / Medium / High — with brief explanation based on what the diff touches]

## Testing

[How changes should be verified — derived from test files in diff, or mark as TODO]

## Impact

[Users affected, breaking changes, dependencies — omit if not relevant]
```

**Content generation rules:**

- Focus on what changed and why based on the actual diff and commits
- Do not speculate beyond visible changes in the diff or commits
- Reference relevant files when useful
- Adapt structure for the specific change; omit sections that are not relevant
- If a PR template exists, follow its structure faithfully and fill in sections from context
- Note missing details with `[TODO: ...]` rather than inventing information
- If the diff includes linked issues (`fixes #42`), carry them into the body

### 6. **Validate for Quality**

Before presenting to user, conduct a validation review:

**Check:**

| Check                   | Validation                                   | Action if Failed                                 |
| ----------------------- | -------------------------------------------- | ------------------------------------------------ |
| **Title length**        | Title must be < 72 characters                | Shorten and ask user to confirm                  |
| **Title mood**          | Imperative mood (Add, Fix, Update, not Added)| Revise to imperative                             |
| **Markdown validity**   | Body Markdown renders correctly              | Fix formatting issues                            |
| **Diff accuracy**       | Body accurately reflects the actual diff     | Remove claims not supported by the diff          |
| **No invented details** | Nothing fabricated beyond diff and commits   | Remove speculation; mark unknowns as TODO        |
| **Template alignment**  | Body follows selected template structure     | Adjust to match template sections                |
| **Label validity**      | Requested labels exist in the repo           | Warn if labels don't exist; suggest alternatives |
| **Linked issues**       | Issue references are correctly formatted     | Fix reference syntax (Fixes #N, Closes #N)       |
| **Completeness**        | All relevant sections populated              | Fill in or mark as `[TODO: ...]`                 |

**If any check fails:** Revise the draft before step 7. Do NOT proceed with flawed content.

### 7. **Present for Review**

Show the draft clearly with session context:

```
---
**Draft new pull request**

**Branch:** [current] → [base]
**Commits:** [N] commit(s)
**Draft mode:** [yes/no]
**Labels:** [label1, label2] (or "none")
**Reviewers:** [user1, user2] (or "none")
**Template:** [template name] (or "default structure")
**Session context:** This is draft #1 in this session

# {title}

{body in GitHub-flavored Markdown}

---

_Create this PR, or tell me what to change?_
```

### 8. **Handle User Feedback**

- **If user confirms** (`"create"`, `"yes"`, `"looks good"`, `"👍"`): Proceed to step 9
- **If user requests changes**: Revise and return to step 6 → 7
- **If user says cancel** (`"no"`, `"cancel"`, `"discard"`): Stop and don't create
- **If user wants to add/change labels, reviewers, or draft mode**: Update and re-present
- **If no response to confirmation**: Ask once more: "Should I create this PR or make changes?"

### 9. **Extract & Save**

- Create the drafts directory: `mkdir -p "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts"`
- Extract the **first line** (after `# `) as the title; everything after is the body
- Use the Write tool to save the title to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_title_draft.txt`
- Use the Write tool to save the body to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_body_draft.md`
- If draft mode was requested, use the Write tool to save `true` to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_draft.flag`
- If a non-default base branch was specified, use the Write tool to save the branch name to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_base.txt`
- If labels were specified, use the Write tool to save them (one per line) to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_labels.txt`
- If reviewers were specified, use the Write tool to save them (one per line) to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_reviewers.txt`
- Update session state: track drafts in this session

### 10. **Create the PR**

```bash
SESSION_DIR="${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}"
ARGS=(
  --title "$(tr -d '\n' < "${SESSION_DIR}/drafts/pr_title_draft.txt")"
  --body-file "${SESSION_DIR}/drafts/pr_body_draft.md"
)
if [ -f "${SESSION_DIR}/drafts/pr_draft.flag" ]; then
  ARGS+=(--draft)
fi
if [ -f "${SESSION_DIR}/drafts/pr_base.txt" ]; then
  ARGS+=(--base "$(tr -d '\n' < "${SESSION_DIR}/drafts/pr_base.txt")")
fi
if [ -f "${SESSION_DIR}/drafts/pr_labels.txt" ]; then
  while IFS= read -r label; do
    ARGS+=(--label "${label}")
  done < "${SESSION_DIR}/drafts/pr_labels.txt"
fi
if [ -f "${SESSION_DIR}/drafts/pr_reviewers.txt" ]; then
  while IFS= read -r reviewer; do
    ARGS+=(--reviewer "${reviewer}")
  done < "${SESSION_DIR}/drafts/pr_reviewers.txt"
fi
gh pr create "${ARGS[@]}"
```

### 11. **Confirm Success**

- On success: Show the new PR URL and a brief summary of what was created (title, base branch, draft status, labels, reviewers)
- On failure: Display the full error and suggest next steps:
  - If push fails: suggest `git push -u origin HEAD`
  - If auth fails: suggest `gh auth status`
  - If permission error: suggest checking repo permissions

---

## Rules & Guidelines

### Content Generation

- **Diff-driven:** The PR body must reflect the actual diff and commits, not speculation
- **Concise technical language:** Match the tone and vocabulary of the repository
- **Structure adapts to scope:** Small fixes get a brief summary; large features get detailed sections
- **Honesty over completeness:** Mark unknown details as `[TODO: ...]` rather than inventing them
- **Template-first:** If a repo PR template exists, follow its structure faithfully
- **Title quality:** Imperative mood, under 72 characters; specific and descriptive
- **Body quality:** GitHub-flavored Markdown; readable sections; file references where useful

### PR Context Awareness

- **Branch naming:** Infer PR type from branch name conventions (e.g., `feature/`, `fix/`, `hotfix/`)
- **Implicit push:** `gh pr create` pushes the branch automatically; always note this to the user
- **Draft vs. ready:** If the diff is incomplete or tests are missing, suggest `--draft`
- **Base branch:** Respect `git config branch.<name>.gh-merge-base` if set; otherwise use repo default
- **Commit quality:** If commit messages are well-structured, lean on them for the PR body; if they're messy (e.g., "WIP", "fix"), rely more on the diff
- **Linked issues:** If commits reference issues (`fixes #42`), carry those into the body automatically

### Safety & Permissions

- If required context is missing, **ask rather than guess**
- If repo info or branch info fetch fails, **stop immediately** and ask user to:
  - Run `gh auth status` to check authentication
  - Confirm repo accessibility
- If `gh pr create` fails, show the full error and suggest next steps
- **Never invent technical details** not visible in the diff or commits
- **Never create a PR without user confirmation** (step 8)
- **Never push to the remote** without noting it — `gh pr create` pushes the branch automatically

### Edge Cases

- **On default branch:** Stop; instruct user to create or switch to a feature branch
- **No commits ahead:** Stop; instruct user to commit changes first
- **Uncommitted changes:** Warn that they won't be included in the PR
- **Existing PR for branch:** Stop; suggest `/gh-pr-edit N` instead
- **Very large diffs (1000+ lines):** Summarize by area; don't attempt line-by-line coverage in the body
- **Labels don't exist:** Warn the user: "Label '[name]' doesn't exist in this repo. Create it, use a different label, or skip?"
- **Reviewers don't exist:** Warn: "User '[name]' not found. Check the handle and try again."
- **Base branch divergence:** Warn and suggest rebasing if significantly behind
- **Sensitive info in diff:** If diff contains what looks like credentials, tokens, or secrets, warn before including in PR body
- **Branch not pushed:** Note that `gh pr create` will push the branch; confirm this is expected

---

## Error Messages & Recovery

| Scenario                          | Action                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------ |
| On default branch                 | Stop: "You're on the default branch. Create or switch to a feature branch first."    |
| No commits ahead of base          | Stop: "No commits to include in a PR. Commit your changes first."                    |
| `gh auth status` fails            | Show error, suggest `gh auth login`                                                  |
| Repo info fetch fails             | Show error, suggest `gh auth status`                                                 |
| Diff is empty                     | Stop: "No changes detected between your branch and base. Nothing to create a PR for."|
| PR already exists for branch      | Stop: "Open PR #N exists for this branch. Use `/gh-pr-edit N` to modify it."         |
| Description is too vague          | Infer from diff/commits; confirm with user                                           |
| Template detection fails          | Proceed with default structure; note templates couldn't be read                      |
| Labels don't exist in repo        | Warn and offer: create without label, use different label, or skip                   |
| Reviewers not found               | Warn and offer: create without reviewer, fix handle, or skip                         |
| Title exceeds 72 characters       | Flag in validation (step 6); shorten before presenting                               |
| Markdown body is malformed        | Fix in validation; show preview before presenting                                    |
| `gh pr create` fails (push)       | Show error, suggest `git push -u origin HEAD` then retry                             |
| `gh pr create` fails (auth)       | Show error, suggest `gh auth status` or repo permission check                        |
| User interrupts drafting          | Ask: "Should I save the draft, discard it, or resume?"                               |
| Validation detects issues         | Revise in step 6; do NOT present flawed draft                                        |
| Base branch significantly ahead   | Warn: "Base is N commits ahead. Consider rebasing before creating the PR."           |
