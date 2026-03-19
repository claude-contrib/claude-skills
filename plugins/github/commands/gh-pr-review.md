---
description: >
  Drafts a GitHub pull request review with structured code feedback and submits
  it after user confirmation. Supports approve, request-changes, or comment
  outcomes. Accepts an optional outcome and/or focus area argument, e.g.,
  "approve", "request-changes", or "focus on security."
argument-hint: "<pr-number> [approve|request-changes|comment] [focus area]"
disable-model-invocation: true
allowed-tools: Bash(*), Write
---

# Draft and Submit GitHub PR Reviews

## Mode: REVIEW-ONLY

Your role: **read the diff → analyze for issues → draft a structured review → validate for quality → present for review → incorporate feedback → submit the review to GitHub.**

**Submitting the review** means posting it to GitHub. It does NOT mean: merging, editing the PR, or creating separate comments.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` to verify)
- Directories: `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}` must be writable
- Write permissions on the repository
- Git repo with access to local commits (for diff context)

## Context

**PR Number:**

```
!`echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'`
```

**Current Pull Request (always fresh):**

```
!`PR_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); gh pr view "${PR_NUM}" --json number,title,url,body,labels,comments,isDraft,state,reviewDecision,reviews,commits 2>/dev/null | jq -r -f "${CLAUDE_PLUGIN_ROOT}/queries/gh_pr_view.jq" || echo "Unable to fetch PR. Check the PR number and gh auth status."`
```

**Review History (always fresh):**

```
!`PR_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); gh api "repos/$(gh repo view --json nameWithOwner --jq .nameWithOwner)/pulls/${PR_NUM}/reviews" --paginate 2>/dev/null | jq -s '[.[][] | {id: .id, state: .state, submitted_at: .submitted_at, body: (.body // "")}]' || echo "Unable to fetch review history."`
```

**Current Commit SHA:**

```
!`PR_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); gh pr view "${PR_NUM}" --json headRefOid --jq .headRefOid 2>/dev/null || echo "unknown"`
```

**Session Notes (optional, non-authoritative):**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/session_notes.md" 2>/dev/null || true`
```

**User Request (outcome):**

```
!`echo "$ARGUMENTS" | awk '{print $2}' | grep -xE 'approve|request-changes|comment' || true`
```

(PR number is the first word; outcome keyword must be the second word of arguments.)

**User Request (focus area):**

```
!`W2=$(echo "$ARGUMENTS" | awk '{print $2}'); if [ -z "$W2" ]; then true; elif echo "$W2" | grep -qxE 'approve|request-changes|comment'; then echo "$ARGUMENTS" | awk '{$1=$2=""; sub(/^[[:space:]]+/,""); print}'; else echo "$ARGUMENTS" | awk '{$1=""; sub(/^[[:space:]]+/,""); print}'; fi 2>/dev/null || true`
```

(Strips the PR number and, if word 2 is a valid outcome keyword, strips it too; remaining text is the focus area.)

## Forbidden Actions

**Do NOT:**

- Merge, close, or reopen the PR
- Edit the PR title or body
- Create branches, commit, push, or modify source files
- Run build, test, formatter, linter, or package-manager commands
- Write local files other than `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_review_draft.md` and `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/pr_diff.patch`

(Creating the `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/` and `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/` directories is allowed.)

## Workflow

### 1. **Check for Prior Reviews**

- Detect if an AI-generated review already exists for this commit (uses tracking marker)
- If found, ask: **"An AI-generated review already exists for this commit. Submit a new one anyway, or cancel?"**
- If user cancels, stop. Otherwise, proceed.

### 2. **Validate & Fetch**

- Parse PR number from the first argument (`$ARGUMENTS`); if missing or not a number, ask the user
- Fetch PR details, review history, and commit SHA; if any fetch fails, stop and show error
- Check user has write permissions to the repo (auth required)
- Note PR state: is it a draft, open, in review, approved, or merged?

### 3. **Fetch & Analyze Diff**

```bash
PR_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#')
mkdir -p "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state"
gh pr diff "${PR_NUM}" --patch > "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/pr_diff.patch" 2>/dev/null
git apply --stat < "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/pr_diff.patch" 2>/dev/null || echo "(diffstat unavailable)"
```

- If diff is empty, **stop and inform the user** — do not proceed with review
- If diff is extremely large (1000+ lines), focus on critical files (entry points, security-related files, database migrations, API contracts, configuration) and note which were skipped; deprioritize test fixtures, generated files, vendored dependencies, and lock files

### 4. **Determine Review Scope**

- **If focus area provided:** Review with that lens (e.g., "security", "performance")
- **If empty:** Review comprehensively (logic, bugs, error handling, architecture)
- Classify each finding using these criteria:

  **High — must fix before merge (blocks approval):**
  - Incorrect behavior in normal usage paths (bugs in happy path or common error paths)
  - Data loss, corruption, or security vulnerability (injection, auth bypass, secrets exposure)
  - Crash, panic, or unhandled error that reaches end users
  - Race condition or concurrency issue with observable impact under expected load
  - Breaking change to public API/contract without migration path

  **Medium — should fix, not strictly blocking (warrants "request changes" if multiple):**
  - Wrong result for uncommon but realistic inputs (edge case a real user could hit)
  - Missing validation at a system boundary (user input, external API, file I/O)
  - Performance issue that degrades noticeably under expected load
  - Error handling that swallows context or returns misleading messages
  - Architectural concern that will significantly complicate near-term planned work

  **Low — advisory, never blocking (informational only):**
  - Naming, readability, or clarity improvements
  - Redundant code that does not affect correctness
  - Missing handling for truly unlikely or contrived scenarios
  - Style inconsistencies not caught by linters
  - Documentation gaps in internal (non-public) code

  **Borderline test:** "Could a real user trigger this under normal or reasonably foreseeable conditions?" Yes → High or Medium. No → Low.

### 5. **Determine Outcome**

- **If outcome specified in arguments:** Use it (approve/request-changes/comment)
- **If empty:** Determine based on findings:
  - **Approve:** No blocking issues found
  - **Request Changes:** High-severity issues require fixes
  - **Comment:** Observations worth noting but not blocking
- Never auto-approve without thorough review

### 6. **Draft the Review**

- Structure review with sections: Summary, Findings (by severity), Action Items
- Include file and line references for context (`file.ext:line`)
- Provide specific suggestions for each finding
- Keep tone professional, constructive, and respectful
- Append tracking marker: `<!-- gh-claude:pr-review pr=<PR_NUMBER> commit=<HEAD_SHA> -->`

### 7. **Validate Review for Quality**

Before presenting to user, conduct a validation review:

**Check:**

| Check                    | Validation                                      | Action if Failed                                       |
| ------------------------ | ----------------------------------------------- | ------------------------------------------------------ |
| **Tone**                 | Professional, constructive, collaborative?      | Revise to remove dismissive/condescending language      |
| **Specificity**          | References exact files, lines, code context?    | Add specific locations and code references              |
| **Findings accuracy**    | Each finding cites actual code from the diff?   | Remove findings not supported by diff evidence          |
| **Severity calibration** | Each severity matches step 4 criteria and the borderline test? | Re-classify using "could a real user trigger this?" test |
| **Suggestions**          | Concrete fixes offered, not just criticism?     | Add actionable suggestions for each finding             |
| **Outcome alignment**    | Outcome matches the severity of findings?       | Approve should have no High findings; adjust if needed  |
| **Redundancy**           | Doesn't repeat points from existing reviews?    | Check review history; add new perspective only          |
| **Markdown validity**    | Renders correctly with proper code blocks?      | Fix formatting before presenting                        |
| **Tracking marker**      | Marker appended with correct PR and commit SHA? | Verify marker format and values                         |

**If any check fails:** Revise the draft before step 8. Do NOT proceed with problematic reviews.

### 8. **Present for Review**

```
---
**Draft review for PR #N: [Title]**

**PR state:** [draft/open/merged/closed]
**Outcome: {Approve | Request Changes | Comment}**

## Summary
{overview of the PR and assessment}

## Findings
[{High|Medium|Low}] {issue}
Location: `file.ext:line`
Details: {explanation}
Suggestion: {fix}

## Action Items
Required Changes:
- [ ] {blocking issue}

Advisory:
- {optional improvement}

_Submit this review, or tell me what to change?_
---
```

### 9. **Handle User Feedback**

- **If user confirms** (`"submit"`, `"yes"`, `"looks good"`, `"👍"`): Proceed to step 10
- **If user requests changes**: Revise and return to step 7 → 8
- **If user says cancel** (`"no"`, `"cancel"`, `"discard"`): Stop and don't submit
- **If outcome changes** (e.g., "change to comment"): Update and re-show
- **If no response to confirmation**: Ask once more: "Should I submit this review or discard it?"

### 10. **Save & Submit**

- Create the drafts directory: `mkdir -p "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts"`
- Use the Write tool to save the review body (with tracking marker appended) to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_review_draft.md`
- Submit based on outcome:
  ```bash
  PR_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#')
  # approve:
  gh pr review "${PR_NUM}" --approve --body-file "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_review_draft.md"
  # OR request-changes:
  gh pr review "${PR_NUM}" --request-changes --body-file "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_review_draft.md"
  # OR comment:
  gh pr review "${PR_NUM}" --comment --body-file "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/pr_review_draft.md"
  ```

### 11. **Confirm Success**

- On success: Show the submitted review URL and brief confirmation
- On failure: Display the full error and suggest next steps

---

## Rules & Guidelines

### Review Scope & Severity

- **High:** Incorrect behavior in normal paths, data loss/security, crashes, race conditions, breaking API changes — blocks approval
- **Medium:** Edge cases a real user could hit, missing boundary validation, performance degradation, misleading errors, near-term architectural risk — warrants "request changes" if multiple
- **Low:** Naming/readability, redundant code, handling for contrived scenarios, style, internal doc gaps — advisory only, never blocking
- **Skip:** Purely stylistic comments, linter-detectable issues, unrelated legacy code issues
- **Borderline test:** "Could a real user trigger this under normal or reasonably foreseeable conditions?" Yes → High or Medium. No → Low.
- **Balance:** Provide constructive feedback without being nitpicky

### Content & Structure

- **Findings format:** `[Severity] issue -> Location -> Details -> Suggestion`
- **Action items:** Separate required changes (blocking) from advisory (optional)
- **Tone:** Professional, respectful, collaborative — avoid dismissive or condescending language
- **Specificity:** Reference exact files, line numbers, and code context
- **Suggestions:** Offer concrete fixes or improvements, not just criticism

### Review State Awareness

- **Draft PRs:** Note that review may be premature; adjust tone accordingly
- **Existing reviews:** Consider prior feedback to avoid redundancy
- **Review decision state:** Be aware if PR already has approvals or change requests
- **Merged PRs:** Still allow reviews (for documentation/future reference), but note state
- **Tracking marker:** Always include; prevents duplicate AI reviews on same commit

### Safety & Permissions

- If required context is missing, **ask rather than guess**
- If diff is empty, **stop immediately** — do not proceed
- If diff is very large (1000+ lines), **focus on critical files** and state which were skipped
- If PR fetch fails, **stop immediately** and ask user to:
  - Verify the PR number (`gh pr view 123`)
  - Run `gh auth status` to check authentication
  - Confirm repo accessibility
- If `gh pr review` fails on user's own PR, suggest posting as a comment instead
- If `gh pr review` fails for auth/network reasons, show full error and suggest `gh auth status`

### Edge Cases

- **Empty diff:** Stop; inform user and don't review
- **Massive diff:** Focus on critical areas; note scope limits
- **Outcome change:** If user changes outcome mid-review, update and re-show
- **Existing AI review:** Ask before posting duplicate review
- **Sensitive code:** Flag (security, compliance, architecture changes) before submitting
- **Prior conflicting reviews:** Acknowledge if request contradicts previous feedback

---

## Error Messages & Recovery

| Scenario                            | Action                                                              |
| ----------------------------------- | ------------------------------------------------------------------- |
| PR number missing from arguments    | Ask user: "Which PR? Pass the number as the first argument, e.g. `/gh-pr-review 42 approve`" |
| `gh pr view` fails                  | Show error, suggest `gh auth status`                                |
| Diff is empty                       | Stop immediately; inform user and do not proceed                    |
| Diff is massive (1000+ lines)       | Ask: "Focus on critical files only?" and list scope                 |
| `gh pr review` fails (own PR)       | Suggest: "You can't approve or request changes on your own PR. Submit as a comment-type review instead." |
| `gh pr review` fails (auth/network) | Show error, suggest `gh auth status`                                |
| Prior AI review exists              | Ask: "Resubmit or cancel?"                                          |
| User interrupts reviewing           | Offer: save draft, discard, or resume                               |
| Outcome is ambiguous                | Ask: "Should this be approve, request-changes, or comment?"         |
| Validation detects issues           | Revise in step 7; do NOT present problematic review                 |
