---
name: issue-comment
description: >
  Drafts a GitHub issue comment based on issue context and intent, parses
  context intelligently, detects conflicts, validates for quality and
  appropriateness, then posts it after explicit user confirmation.
argument-hint: "<issue-number> [comment intent or specific text]"
disable-model-invocation: true
allowed-tools: Bash(*), Write
---

# Draft and Post GitHub Issue Comments

## Mode: COMMENT-ONLY

Your role: **read the issue → parse context → detect conflicts → draft a helpful, constructive comment → validate for quality and appropriateness → present for review → incorporate feedback → post the comment.**

**Posting the comment** means creating a new comment on the issue. It does NOT mean: implementing anything, editing the issue itself, closing/locking it, or making any other changes to the repo.

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

**Recent Comments (for redundancy & context detection):**

```
!`ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#'); gh issue view "${ISSUE_NUM}" --json comments 2>/dev/null | jq -r '.comments[-5:] | map("\(.author.login) (\(.createdAt | split("T")[0])): \(.body[:120])") | .[]' || echo "Unable to fetch comments."`
```

**Session State (comment tracking):**

```
!`cat "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/state/issue_comment_session.md" 2>/dev/null || true`
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
- Note issue state (open/closed/locked) and existing comments for context
- Load session state: check if there are recent comments from this session

### 2. **Smart Argument Parsing**

- **Parse user arguments for:**
  - Intent (e.g., "ask for reproduction", "provide solution", "confirm bug")
  - Specific references (e.g., "mention PR #99", "reference #15")
  - Tone hints (e.g., "congratulatory", "urgent", "gentle")
  - Question vs. statement vs. code example

- **Auto-detect context from:**
  - Issue labels: bug, feature request, documentation, security
  - Issue state: open vs. closed affects tone
  - Recent comment activity: what's been discussed already
  - Author patterns: new issue vs. repeat reporter

- **Resume option:**
  - If session state shows unsaved comment draft for this issue, ask: "You have a comment draft from [timestamp]. Resume, start fresh, or discard?"

### 3. **Clarify Intent (If Needed)**

- **If arguments provided:** Confirm intent ("I'll draft a comment asking for reproduction steps")
- **If empty:** Ask "What's the intent of this comment? (e.g., ask for clarity, provide a solution, confirm a bug, suggest a workaround, provide context)"
- If intent is ambiguous, ask for specifics: "Do you want to ask a question or provide information?"
- If intent might close/lock/resolve the issue, confirm explicitly: "This sounds like it resolves the issue—should the comment reflect that?"

### 4. **Detect Conflicts & Contradictions**

**Before drafting, check for:**

- **Redundancy:** If your intended comment echoes the last 2 comments, flag it: "Someone already asked this question 2 comments ago"
- **State conflicts:** If closed issue but intent is problem-solving, confirm: "Issue is closed. Still provide a solution (for reference)?"
- **Author conflicts:** If you (the AI) already commented on this issue, confirm: "You already commented [timestamp]. Add another comment?"
- **Recent activity:** If new comments in last 5 minutes, summarize: "New activity detected: [who] said [what]"
- **Dependency issues:** If related issue is blocked or closed, note it
- **Sensitive topic:** If issue touches code of conduct, security, or major decisions, confirm: "This is sensitive. Still comment?"

**If conflicts detected:**

- Show conflict summary
- Ask user to confirm: "Proceed anyway?" or "Let me know what changed"
- Do NOT proceed without confirmation

### 5. **Draft the Comment**

Based on intent and issue context:

- **Seed from arguments:** Use provided text as starting point
- **Or infer helpful comment** from:
  - Issue body and description (what's being asked for?)
  - Existing comments (avoid repeating points; add new perspective)
  - Labels (bug/feature/documentation context)
  - Issue state (open vs. closed affects tone)
- **Tone:** Constructive, professional, respectful, helpful
- **Format:** Use GitHub Markdown (code blocks, lists, links, mentions)
- **Avoid:**
  - Excessive emoji (one or two if naturally appropriate)
  - Speculation about causes (ask questions instead)
  - Commands to close/lock (that's not a comment's job)
  - Repeating points already made
  - Dismissive or sarcastic language

### 6. **Validate Comment for Quality**

Before presenting to user, conduct a validation review:

**Check:**

| Check                   | Validation                                     | Action if Failed                                                   |
| ----------------------- | ---------------------------------------------- | ------------------------------------------------------------------ |
| **Tone**                | Professional, constructive, respectful?        | Revise to remove sarcasm/dismissal                                 |
| **Specificity**         | References issue details (not generic)?        | Add specific details or context                                    |
| **Redundancy**          | Doesn't repeat existing comments?              | Check against existing comments; add new perspective or remove     |
| **Speculation**         | No unsupported claims? Asks questions instead? | Replace speculation with "Have you tried..." or specific questions |
| **Markdown validity**   | Renders correctly?                             | Check code blocks, links, formatting                               |
| **Issue state aware**   | Tone matches open/closed status?               | Adjust if posting on closed issue                                  |
| **Length**              | 1–3 paragraphs; readable?                      | Break up long text with bullets or sections                        |
| **Proportional**        | Comment length is proportional to thread context? | If comment is longer than all existing comments combined, trim to key points; suggest a follow-up if more detail is needed |
| **Accidental commands** | No unintended close/lock/resolve?              | Verify comment body doesn't trigger unintended actions             |
| **Helpful**             | Moves issue forward or adds value?             | Ensure comment is constructive, not just acknowledgment            |

**If any check fails:** Revise the draft before step 7. Do NOT proceed with problematic comments.

### 7. **Present for Review**

Show the draft clearly with session and issue context:

```
---
**Draft comment for issue #N: [Title]**

**Issue state:** [open/closed/locked]
**Recent activity:** [brief summary of last 2-3 comments]
**Session context:** This is comment #1 in this session

{comment body in GitHub-flavored Markdown}

---

_Post this comment, or tell me what to change?_
```

### 8. **Handle User Feedback**

- **If user confirms** (`"post"`, `"yes"`, `"looks good"`, `"👍"`): Proceed to step 9
- **If user requests changes**: Revise and return to step 6 → 7
- **If user says cancel** (`"no"`, `"cancel"`, `"discard"`): Stop and don't post
- **If no response to confirmation**: Ask once more: "Should I post this comment or make changes?"

### 9. **Save & Track Session State**

- Create the drafts directory: `mkdir -p "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts"`
- Use the Write tool to save the comment body to `${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_comment_draft.md`
- Update session state: track comments posted in this session

### 10. **Post the Comment**

```bash
ISSUE_NUM=$(echo "$ARGUMENTS" | awk '{print $1}' | tr -d '#')
gh issue comment "${ISSUE_NUM}" \
  --body-file "${HOME}/.local/state/gh/claude/sessions/${CLAUDE_SESSION_ID}/drafts/issue_comment_draft.md"
```

### 11. **Confirm Success**

- On success: Show the posted comment URL and a brief confirmation
- On failure: Display the full error and suggest `gh auth status` or repo permission check

---

## Rules & Guidelines

### Comment Content & Tone

- **Tone:** Constructive, professional, respectful; avoid sarcasm, dismissiveness, or condescension
- **Specificity:** Reference issue number, labels, user names, or code details when relevant
- **Length:** Generally 1–3 paragraphs; use bullet points or code blocks for readability
- **Avoid:**
  - Excessive emoji (one or two if naturally appropriate)
  - Speculation ("I bet it's because..."); ask questions instead
  - Multiple separate comments (consolidate into one)
  - Closing/locking issues (that's not a comment function)
  - Repeating points already in the thread
  - Unhelpful acknowledgments ("I agree!"); add value instead

### Issue Context Awareness

- **State matters:** Tone differs for open ("let's fix this") vs. closed ("for future reference")
- **Labels inform tone:** Security issues vs. bugs vs. feature requests require different framing
- **Recent activity:** Check what's been discussed; don't repeat
- **Thread patterns:** Add new information, not repetition
- **First responder:** If first comment on issue, set a helpful, welcoming tone
- **Sensitive topics:** Flag before posting if touching code of conduct, security, or major decisions
- **Author context:** If same person has reported multiple issues, acknowledge familiarity
- **Stale issues:** Acknowledge age; ask if context still applies before posting

### Safety & Permissions

- If required context is missing, **ask rather than guess**
- If issue fetch fails, **stop immediately** and ask user to:
  - Verify the issue number (`gh issue view #123`)
  - Run `gh auth status` to check authentication
  - Confirm repo accessibility
- If `gh issue comment` fails, show the full error and suggest next steps
- **Never post a comment you haven't validated** against the checklist in step 6

### Edge Cases

- **Closed issues:** Note state in presentation; adjust tone for "for reference" comments
- **Locked issues:** Note state; confirm user wants to comment anyway
- **Very stale issues:** Acknowledge age and ask if context still applies before posting
- **Sensitive topics:** Flag (security, code of conduct, architecture) and confirm before posting
- **Duplicate comments:** Warn if your comment echoes recent discussion; offer to revise
- **First responder:** Set a helpful, welcoming tone if this is the first comment
- **Off-topic tangent:** If comment drifts from issue scope, ask user to confirm intent
- **Thread too long:** If issue has 50+ comments, offer to summarize context

---

## Error Messages & Recovery

| Scenario                    | Action                                                             |
| --------------------------- | ------------------------------------------------------------------ |
| Issue number missing from arguments | Ask user: "Which issue? Pass the number as the first argument, e.g. `/gh:issue-comment 42 ...`" |
| `gh issue view` fails       | Show error, suggest `gh auth status`                               |
| Intent is ambiguous         | Ask: "Do you want to [option A] or [option B]?"                    |
| Comment tone is dismissive  | Revise in step 6; make it constructive                             |
| Comment is pure speculation | Flag in step 6; ask to rewrite as questions                        |
| Comment would be redundant  | Check against existing comments; offer to revise before presenting |
| Issue is closed or locked   | Note state in step 7 presentation; confirm before posting          |
| Markdown is broken          | Fix in step 6; show preview before presenting                      |
| `gh issue comment` fails    | Show error, suggest `gh auth status` or repo permission check      |
| User interrupts drafting    | Ask: "Should I save the draft, discard it, or resume?"             |
| Validation detects issues   | Revise in step 6; do NOT present problematic comment               |
| Conflict detected           | Show conflict, ask user to confirm before proceeding               |
