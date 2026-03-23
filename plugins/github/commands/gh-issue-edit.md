---
name: gh-issue-edit
description: >
  Edits a GitHub issue title and/or body according to requested changes, parses
  context intelligently, detects conflicts, validates for quality, then applies
  the edit after explicit user confirmation.
argument-hint: "<issue-number> [what to change or edit request]"
disable-model-invocation: true
allowed-tools: Bash(*), Write
---

# Edit GitHub Issues (Title & Body)

## Mode: EDIT-ONLY

Your role: **read the issue → parse context → detect conflicts → draft revised title/body → validate for quality → present for review → incorporate feedback → apply the edit.**

**Applying the edit** means updating the issue on GitHub. It does NOT mean: implementing anything, creating branches, or making any other changes to the repo.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` to verify)
- Directories: `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}` must be writable
- Write permissions on the repository

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
!`ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); gh issue view "${ISSUE_NUM}" --json comments 2>/dev/null | jq -r '.comments[-2:] | map("\(.author.login) (\(.createdAt | split("T")[0])): \(.body[:80])") | .[]' || echo "Unable to fetch comments."`
```

**Session State (edit tracking):**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/issue_edit_session.md" 2>/dev/null || true`
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

- Parse issue number from the first argument (`$ARGUMENTS`); if missing or not a number, ask the user
- Fetch issue details (number, title, body, state, labels, comments); if fetch fails, stop and show the error
- Check user has write permissions to the repo (auth required)
- Note the current issue state (open/closed); confirm edits for closed issues
- Load session state: check if there's an existing edit draft for this issue

### 2. **Smart Argument Parsing**

- **Parse user arguments for:**
  - Specific changes (e.g., "update title", "add acceptance criteria")
  - Linked issues (e.g., "add reference to #42")
  - Scope of change (title only, body only, both)

- **Resume option:**
  - If session state shows unsaved edit draft for this issue, ask: "You have an edit draft from [timestamp]. Resume, start fresh, or discard?"

### 3. **Clarify Changes (If Needed)**

- **If arguments provided:** Confirm scope (e.g., "I'll update the title to be clearer and add acceptance criteria")
- **If empty:** Ask "What would you like to change about this issue? (e.g., title, description, add a section)"
- If request is ambiguous (e.g., "improve this"), ask for specifics: "What specifically should change?"
- If request suggests removing content, confirm explicitly: "You're asking me to remove [section]—correct?"

### 4. **Detect Conflicts & Contradictions**

**Before drafting, check for:**

- **Recent activity:** If comments added in last 30 min, fetch and summarize: "Someone just commented 15min ago: '[summary]'"
- **State conflicts:** If editing closed issue, note state
- **Content contradictions:** If earlier edit in session contradicted current request, ask: "Earlier you removed [section], now adding it back?"
- **Working tree conflicts:** If local branch has edits to the issue, note them

**If conflicts detected:**

- Show conflict summary
- Ask user to confirm: "Proceed anyway?" or "Let me know what changed"
- Do NOT proceed without confirmation

### 5. **Draft the Changes**

Apply ONLY the requested modifications:

- **Preserve existing wording, structure, and formatting** unless explicitly requested to change
- **Title:** Keep under 72 characters; clear and descriptive
- **Body:** Use GitHub-flavored Markdown; maintain readability with sections, code blocks, lists
- **Don't "improve" beyond the request:** If user asks for title fix only, don't reorganize the body
- **Track all changes:** Maintain an internal list of every addition, removal, and modification made to the original. This list is shown in step 7's "Diff summary" so the user can verify without mentally comparing the full body.

Format the draft as:

```
# {new title}

{updated body in GitHub-flavored Markdown}
```

### 6. **Validate Changes for Quality**

Before presenting to user, conduct a validation review:

**Check:**

| Check                     | Validation                        | Action if Failed                                   |
| ------------------------- | --------------------------------- | -------------------------------------------------- |
| **Title length**          | Title must be < 72 characters     | Flag and ask user to shorten                       |
| **Title clarity**         | Title clearly describes issue     | Ask user: "Is this title clear enough?"            |
| **Markdown validity**     | Body Markdown renders correctly   | Show preview and ask for revision                  |
| **Content preservation**  | Only requested changes applied    | Review against original; confirm not dropping info |
| **No accidental removal** | No info deleted unless requested  | Ask user to confirm removals                       |
| **Scope adherence**       | Changes match user request        | Don't add unrequested improvements                 |
| **Link integrity**        | URLs and references still valid   | Verify links weren't broken                        |
| **Format consistency**    | Sections maintain original format | Check indentation, lists, code blocks              |

**If any check fails:** Revise the draft before step 7. Do NOT proceed with flawed edits.

### 7. **Present for Review**

Show the draft clearly with session context:

```
---
**Draft edit for issue #N: [Current Title]**

**Session context:** This is edit #1 in this session

**Changes:**
- Title: updated to be clearer
- Body: added new "Acceptance Criteria" section

**Diff summary:**
- Added: [list sections/content added]
- Removed: [list sections/content removed, if any]
- Modified: [list sections where wording changed]

# {new title}

{updated body}

---

_Apply this edit, or tell me what to change?_
```

### 8. **Handle User Feedback**

- **If user confirms** (`"apply"`, `"yes"`, `"looks good"`, `"👍"`): Proceed to step 9
- **If user requests changes**: Revise and return to step 6 → 7
- **If user says cancel** (`"no"`, `"cancel"`, `"discard"`): Stop and don't apply
- **If no response to confirmation**: Ask once more: "Should I apply this edit or make changes?"

### 9. **Extract & Save**

- Create the drafts directory: `mkdir -p "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts"`
- Extract the **first line** (after `# `) as the title; everything after is the body
- Write the title to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_title_draft.txt`
- Write the body to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_body_draft.md`
- Update session state: track edits in this session

### 10. **Apply the Edit**

```bash
ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#')
gh issue edit "${ISSUE_NUM}" \
  --title "$(tr -d '\n' < "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_title_draft.txt")" \
  --body-file "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_body_draft.md"
```

### 11. **Confirm Success**

- On success: Show the updated issue URL and confirm what was changed
- On failure: Display the full error and suggest `gh auth status` or repo permission check

---

## Rules & Guidelines

### Content Changes

- **Scope:** Apply only the requested changes; don't "improve" beyond the request
- **Preservation:** Keep existing wording, links, formatting, and structure unless explicitly asked to change
- **Title:** Must be under 72 characters; clear and descriptive
- **Body:** Use GitHub-flavored Markdown; maintain readability with sections, code blocks, lists, tables
- **Clarity:** If a request is ambiguous, ask "What specifically should change?" rather than guessing
- **Completeness:** Show before/after or highlight what changed so user can verify

### Safety & Permissions

- If required context is missing, **ask rather than guess**
- If issue fetch fails, **stop immediately** and ask user to:
  - Verify the issue number (`gh issue view #123`)
  - Run `gh auth status` to check authentication
  - Confirm repo accessibility
- If `gh issue edit` fails, show the full error and suggest next steps
- **Never silently drop information** unless explicitly confirmed
- If editing a closed issue, note the state and confirm user intends to edit

### Edge Cases

- **Large rewrites:** Ask if user wants full rewrite vs. incremental edits
- **Title too long:** Flag (≥72 chars) and ask for shortening before presenting
- **Removing content:** Confirm explicitly ("You requested I remove the 'Acceptance Criteria' section—is this correct?")
- **Markdown corruption:** Show preview and ask for revision before presenting
- **Closed issues:** Note state and confirm before applying edits
- **Multiple edits in one session:** Treat each as a new workflow (fetch fresh each time)
- **Sensitive info:** If user asks to expose sensitive data, clarify intent first

---

## Error Messages & Recovery

| Scenario                            | Action                                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------------------- |
| Issue number missing from arguments | Ask user: "Which issue? Pass the number as the first argument, e.g. `/gh-issue-edit 42 ...`" |
| `gh issue view` fails               | Show error, suggest `gh auth status`                                                         |
| Title ≥72 characters                | Flag in validation (step 6); ask user to shorten before presenting                           |
| Markdown body is malformed          | Show preview in validation; ask for revision before presenting                               |
| Request is ambiguous                | Ask: "Did you mean [option A] or [option B]?"                                                |
| Content removal requested           | Confirm: "Remove [section]—is this correct?"                                                 |
| Closed issue being edited           | Warn: "This issue is closed. Edits will still apply. Continue?"                              |
| `gh issue edit` fails               | Show error, suggest `gh auth status` or repo permission check                                |
| User interrupts editing             | Ask: "Should I apply the current draft, save it, or discard it?"                             |
| Validation fails                    | Revise and return to step 6; do NOT present flawed edit                                      |
| Conflict detected                   | Show conflict, ask user to confirm before proceeding                                         |
