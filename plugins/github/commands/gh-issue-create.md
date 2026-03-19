---
description: >
  Drafts a new GitHub issue with title and structured body from a description,
  detects repo issue templates, validates for quality, then creates it after
  explicit user confirmation.
argument-hint: "<description of the issue> [--label label1,label2] [--assignee username]"
disable-model-invocation: true
allowed-tools: Bash(*), Write
---

# Create GitHub Issues

## Mode: CREATE-ONLY

Your role: **parse the description → gather repo context → detect templates → detect conflicts → draft title and body → validate for quality → present for review → incorporate feedback → create the issue.**

**Creating the issue** means opening a new issue on GitHub. It does NOT mean: implementing anything, creating branches, writing code, or making any other changes to the repo.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status` to verify)
- Directories: `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}` must be writable
- Write permissions on the repository

## Context

**Repository Info:**

```
!`gh repo view --json url,defaultBranchRef,languages,description 2>/dev/null | jq -r -f "${CLAUDE_PLUGIN_ROOT}/queries/gh_repo_view.jq" || echo "Unable to fetch repo info. Check gh auth status."`
```

**Available Issue Templates:**

```
!`find .github/ISSUE_TEMPLATE -type f \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) -exec basename {} \; 2>/dev/null | sort || echo "No issue templates found."`
```

**Potential Duplicates (open issues matching description):**

```
!`if [ -n "$ARGUMENTS" ]; then gh issue list --state open --search "$ARGUMENTS" --limit 5 --json number,title --jq '.[] | "#\(.number): \(.title)"' 2>/dev/null || echo "(search unavailable)"; else echo "(no description to search against)"; fi`
```

**Session State (draft tracking):**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/issue_create_session.md" 2>/dev/null || true`
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
- Check user has write permissions to the repo
- Load session state: check if there's an existing draft from this session

### 2. **Smart Argument Parsing**

- **Parse user arguments for:**
  - Issue description/intent (the main text)
  - Labels: `--label bug,enhancement` or `label:bug` prefix
  - Template hints: `--template bug_report.md` or keywords like "bug", "feature"
  - Linked issues: references like "related to #42", "blocks #15"
  - Assignees: `--assignee username`

- **Auto-detect issue type from description:**
  - Bug indicators: "broken", "crash", "error", "fails", "regression", "doesn't work"
  - Feature indicators: "add", "new", "support", "improve", "enhance", "request"
  - Documentation indicators: "docs", "documentation", "readme", "guide"

- **Detect issue template:**
  - Check `.github/ISSUE_TEMPLATE/` for available templates
  - If templates found, match detected issue type to the best template
  - If multiple templates match or type is unclear, present choices: "Found these templates: [list]. Which fits best, or should I use a blank issue?"
  - Read the matched template content and use its structure for the body
  - If no templates found, use a sensible default structure based on issue type (see step 5)
  - If `config.yml` exists in `.github/ISSUE_TEMPLATE/`, check if blank issues are allowed; if not, a template is required

- **Resume option:**
  - If session state shows unsaved draft, ask: "You have an issue draft from [timestamp]. Resume, start fresh, or discard?"

### 3. **Clarify Intent (If Needed)**

- **If description is clear and specific:** Confirm scope ("I'll draft a bug report about login failures with a 500 error")
- **If description is vague** (e.g., "login is broken"): Ask for specifics:
  - "Can you describe the steps to reproduce?"
  - "What's the expected vs. actual behavior?"
  - "Which component or area is affected?"
- **If description is too broad** (e.g., "improve everything"): Ask to scope down
- **If contradictory** (e.g., "bug: add new feature"): Ask to clarify type

### 4. **Detect Conflicts & Contradictions**

**Before drafting, check for:**

- **Duplicate detection:** Search open issues for similar titles or descriptions; if a close match is found, flag it: "This looks similar to open issue #N: '[title]'"
- **Session conflicts:** If earlier draft in session contradicts current intent, ask: "Earlier you drafted a bug report, now requesting a feature. Start fresh?"
- **Template conflicts:** If selected template doesn't match description type, warn: "You selected the bug template but this reads like a feature request"
- **Label conflicts:** If requested labels contradict each other or don't match issue type, flag it

**If conflicts detected:**

- Show conflict summary
- Ask user to confirm: "Proceed anyway?" or "Let me know what changed"
- Do NOT proceed without confirmation

### 5. **Draft the Issue**

Generate a title and structured body based on issue type and template:

**Title:**

- Under 72 characters
- Clear, specific, and descriptive
- Format: `[Type prefix if appropriate]: concise description`
- Examples: "Fix login 500 error on expired sessions", "Add dark mode support to settings page"

**Body structure for bug reports** (adapt if template exists):

```markdown
## Description

[Concise description of the bug]

## Steps to Reproduce

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Expected Behavior

[What should happen]

## Actual Behavior

[What actually happens]

## Additional Context

[Environment, screenshots, logs, related issues]
```

**Body structure for feature requests** (adapt if template exists):

```markdown
## Description

[What the feature should do and why it's needed]

## Motivation

[Why this feature is valuable; what problem it solves]

## Proposed Solution

[How this could be implemented, if known]

## Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Additional Context

[Mockups, examples, related issues]
```

**Body structure for other/general issues:**

```markdown
## Description

[Clear description of what needs to be done]

## Details

[Supporting information, context, constraints]

## Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Additional Context

[Related issues, references, notes]
```

**Content generation rules:**

- Use concise, technical language appropriate to the repo
- Adapt structure for the specific issue type; don't force all sections if they don't apply
- Note missing details with `[TODO: ...]` rather than inventing information
- Include linked issues as references where relevant
- Use GitHub-flavored Markdown (code blocks, task lists, links)

### 6. **Validate for Quality**

Before presenting to user, conduct a validation review:

**Check:**

| Check                   | Validation                                   | Action if Failed                                 |
| ----------------------- | -------------------------------------------- | ------------------------------------------------ |
| **Title length**        | Title must be < 72 characters                | Shorten and ask user to confirm                  |
| **Title clarity**       | Title clearly describes the issue            | Revise to be more specific                       |
| **Markdown validity**   | Body Markdown renders correctly              | Fix formatting issues                            |
| **Completeness**        | All relevant sections populated              | Fill in or mark as `[TODO: ...]`                 |
| **No invented details** | Nothing fabricated beyond user's description | Remove speculation; mark unknowns as TODO        |
| **Template alignment**  | Body follows selected template structure     | Adjust to match template sections                |
| **Label validity**      | Requested labels exist in the repo           | Warn if labels don't exist; suggest alternatives |
| **Linked references**   | Issue/PR references are correctly formatted  | Fix reference syntax                             |
| **Actionability**       | Issue is clear enough for someone to act on  | Ask user for more details if too vague           |

**If any check fails:** Revise the draft before step 7. Do NOT proceed with flawed content.

### 7. **Present for Review**

Show the draft clearly with session context:

```
---
**Draft new issue**

**Type:** [bug/feature/general]
**Labels:** [label1, label2] (or "none")
**Template:** [template name] (or "default structure")
**Session context:** This is draft #1 in this session

# {title}

{body in GitHub-flavored Markdown}

---

_Create this issue, or tell me what to change?_
```

### 8. **Handle User Feedback**

- **If user confirms** (`"create"`, `"yes"`, `"looks good"`, `"👍"`): Proceed to step 9
- **If user requests changes**: Revise and return to step 6 → 7
- **If user says cancel** (`"no"`, `"cancel"`, `"discard"`): Stop and don't create
- **If user wants to add/change labels**: Update labels and re-present
- **If no response to confirmation**: Ask once more: "Should I create this issue or make changes?"

### 9. **Extract & Save**

- Create the drafts directory: `mkdir -p "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts"`
- Extract the **first line** (after `# `) as the title; everything after is the body
- Use the Write tool to save the title to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_title_draft.txt`
- Use the Write tool to save the body to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_body_draft.md`
- If labels were specified, use the Write tool to save them (one per line) to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_labels.txt`
- If an assignee was specified, use the Write tool to save the username to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_assignee.txt`
- Update session state: track drafts in this session

### 10. **Create the Issue**

```bash
SESSION_DIR="${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}"
ARGS=(
  --title "$(tr -d '\n' < "${SESSION_DIR}/drafts/issue_title_draft.txt")"
  --body-file "${SESSION_DIR}/drafts/issue_body_draft.md"
)
if [ -f "${SESSION_DIR}/drafts/issue_labels.txt" ]; then
  while IFS= read -r label; do
    ARGS+=(--label "${label}")
  done < "${SESSION_DIR}/drafts/issue_labels.txt"
fi
if [ -f "${SESSION_DIR}/drafts/issue_assignee.txt" ]; then
  ARGS+=(--assignee "$(tr -d '\n' < "${SESSION_DIR}/drafts/issue_assignee.txt")")
fi
gh issue create "${ARGS[@]}"
```

### 11. **Confirm Success**

- On success: Show the new issue URL and a brief summary of what was created (title, labels)
- On failure: Display the full error and suggest `gh auth status` or repo permission check

---

## Rules & Guidelines

### Content Generation

- **Concise technical language:** Match the tone and vocabulary of the repository
- **Structure adapts to type:** Bug reports get reproduction steps; features get acceptance criteria; don't force all sections
- **Honesty over completeness:** Mark unknown details as `[TODO: ...]` rather than inventing them
- **Template-first:** If a repo template exists and matches, follow its structure faithfully
- **Title quality:** Under 72 characters; specific and descriptive; no generic titles like "Bug" or "Feature request"
- **Body quality:** GitHub-flavored Markdown; readable sections; task lists for acceptance criteria

### Safety & Permissions

- If required context is missing, **ask rather than guess**
- If repo info fetch fails, **stop immediately** and ask user to:
  - Run `gh auth status` to check authentication
  - Confirm repo accessibility
- If `gh issue create` fails, show the full error and suggest next steps
- **Never invent technical details** the user didn't provide
- **Never create an issue without user confirmation** (step 8)

### Edge Cases

- **Vague descriptions:** Ask for specifics before drafting; don't guess the intent
- **Template conflicts:** If user's description doesn't fit any template, use blank issue format
- **Labels don't exist:** Warn the user: "Label '[name]' doesn't exist in this repo. Create it, use a different label, or skip?"
- **No write access:** If `gh issue create` fails with permission error, suggest checking repo permissions
- **Duplicate detection:** If description closely matches an existing open issue title, warn before creating
- **Very long descriptions:** Break into structured sections; suggest splitting into multiple issues if scope is too broad
- **Sensitive info:** If description contains what looks like credentials, tokens, or PII, warn before including in issue body

---

## Error Messages & Recovery

| Scenario                          | Action                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------ |
| No description provided           | Ask user: "What issue would you like to create? Describe the bug, feature, or task." |
| `gh auth status` fails            | Show error, suggest `gh auth login`                                                  |
| Repo info fetch fails             | Show error, suggest `gh auth status`                                                 |
| Description is too vague          | Ask for specifics: "Can you provide more details about [aspect]?"                    |
| Template detection fails          | Proceed with default structure; note templates couldn't be read                      |
| Labels don't exist in repo        | Warn and offer: create without label, use different label, or skip                   |
| Title exceeds 72 characters       | Flag in validation (step 6); shorten before presenting                               |
| Markdown body is malformed        | Fix in validation; show preview before presenting                                    |
| `gh issue create` fails           | Show error, suggest `gh auth status` or repo permission check                        |
| User interrupts drafting          | Ask: "Should I save the draft, discard it, or resume?"                               |
| Validation detects issues         | Revise in step 6; do NOT present flawed draft                                        |
| Possible duplicate issue detected | Warn: "This looks similar to #N. Still create a new issue?"                          |
