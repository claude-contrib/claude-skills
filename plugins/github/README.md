# github

GitHub integration for Claude Code — slash commands for managing issues and pull requests.

Each command follows a **draft → iterate → confirm → execute** workflow. Nothing is posted or applied until you explicitly confirm.

## Installation

```
/plugin install github@claude-skills
```

## Requirements

- [`gh` CLI](https://cli.github.com/) installed and authenticated (`gh auth status`)
- Write permissions on the target repository

## Commands

### `/gh-issue-comment`

Draft and post a comment on a GitHub issue.

```
/gh-issue-comment thank the reporter and ask for a reproduction case
/gh-issue-comment summarize the discussion so far
/gh-issue-comment
```

The command fetches the issue, infers a helpful comment from context if no argument is given, validates for tone and quality, shows you a draft, and posts only after you confirm.

**Environment:** `$GH_ISSUE_NUMBER` must be set (e.g., via `gh claude issue chat`).

---

### `/gh-issue-edit`

Edit the title and/or body of a GitHub issue.

```
/gh-issue-edit add a definition of done section
/gh-issue-edit shorten the title and add reproduction steps
/gh-issue-edit rewrite the description as a bug report
```

Only the requested changes are applied — existing wording and structure are preserved unless explicitly changed. Titles are kept under 72 characters.

**Environment:** `$GH_ISSUE_NUMBER` must be set.

---

### `/gh-issue-plan`

Generate a comprehensive TDD-style implementation plan for a GitHub issue and post it as a comment.

```
/gh-issue-plan
/gh-issue-plan focus on the database migration
/gh-issue-plan focus on the auth module
```

The plan includes: goal, architecture, affected files, task breakdown with estimates (XS/S/M/L), TDD steps (write test → fail → implement → pass → commit), effort summary, and open questions. Idempotent: if a plan comment already exists (identified by a tracking marker), it updates rather than duplicates.

**Environment:** `$GH_ISSUE_NUMBER` must be set.

---

### `/gh-pr-comment`

Draft and post a comment on a GitHub pull request.

```
/gh-pr-comment ask the author to add tests for the edge cases
/gh-pr-comment summarize the changes in this PR
/gh-pr-comment
```

Aware of PR state (draft/open/merged), review decision, and recent activity. Detects redundancy and warns before posting similar content to existing comments.

**Environment:** `$GH_PR_NUMBER` must be set (e.g., via `gh claude pr chat`).

---

### `/gh-pr-edit`

Edit the title and/or body of a GitHub pull request.

```
/gh-pr-edit add a testing section and update the summary
/gh-pr-edit shorten the title
/gh-pr-edit rewrite the description to include risk level
```

Warns if the PR has approved reviews (edits may affect reviewer confidence). Only requested changes are applied.

**Environment:** `$GH_PR_NUMBER` must be set.

---

### `/gh-pr-review`

Draft and submit a structured code review for a GitHub pull request.

```
/gh-pr-review
/gh-pr-review approve
/gh-pr-review request-changes
/gh-pr-review comment focus on error handling
/gh-pr-review approve focus on the auth changes
```

Analyzes the diff and organizes findings by severity: **High** (blocks approval), **Medium** (logic/edge cases), **Low** (minor improvements). If no outcome is specified, it is determined from the findings. Checks for a prior AI-generated review on the same commit before submitting to prevent duplicates.

**Environment:** `$GH_PR_NUMBER` must be set.

---

## Environment Variables

| Variable | Used by |
|----------|---------|
| `GH_ISSUE_NUMBER` | Issue commands — identifies the issue to operate on |
| `GH_PR_NUMBER` | PR commands — identifies the PR to operate on |
| `CLAUDE_SESSION_ID` | All commands — session ID used to derive the session state directory (`~/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}`) |
| `CLAUDE_PLUGIN_ROOT` | All commands — path to jq query files bundled with this plugin |

These variables are set automatically when using `gh claude issue chat` or `gh claude pr chat` sessions. When using commands standalone, set them manually:

```bash
export GH_ISSUE_NUMBER=42
export CLAUDE_SESSION_ID=my-session-id
```
