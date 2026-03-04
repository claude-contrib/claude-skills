---
description: Create a well-structured git commit following conventional commit conventions
argument-hint: [message-hint]
---

# Commit

Create a git commit for the staged changes following conventional commit conventions.

## Steps

1. Run `git diff --cached` to review all staged changes.
2. Run `git status` to see staged vs. unstaged files and any untracked files.
3. Run `git log --oneline -10` to understand this repo's commit message style.
4. Analyze the staged diff and draft a commit message:
   - Use the conventional commit format: `<type>(<scope>): <subject>`
   - Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`, `ci`
   - Keep the subject under 72 characters, imperative mood, no trailing period
   - Add a body only when the "why" isn't obvious from the subject
   - If `$ARGUMENTS` is provided, use it as a hint for the message
5. Create the commit using a HEREDOC so special characters are preserved:
   ```
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <subject>

   <optional body>
   EOF
   )"
   ```
6. Confirm the commit was created with `git log --oneline -1`.

## Rules

- Stage only the files relevant to this logical change. Do not auto-stage unrelated files.
- Never use `--no-verify` unless the user explicitly asks.
- If a pre-commit hook fails, fix the underlying issue and retry — do not bypass the hook.
- Do not amend a previous commit unless the user explicitly requests it.
