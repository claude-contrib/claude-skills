# commit

> One command to stage, analyse, and commit — with a well-formed [conventional commit](https://www.conventionalcommits.org/) message every time.

## Installation

```
/plugin install commit@claude-skills
```

## Usage

```
/commit
```

Optional — pass a hint to guide the message:

```
/commit fix the race condition in the auth middleware
```

## What it does

1. Runs `git diff --cached` and `git status` to review staged changes
2. Checks `git log` to match the repo's existing commit style
3. Picks the right conventional commit type and scope (`feat`, `fix`, `refactor`, `docs`, `chore`, …)
4. Writes a subject line under 72 characters, imperative mood, no trailing period
5. Adds a body when the "why" isn't obvious from the subject
6. Creates the commit — respects pre-commit hooks, never uses `--no-verify`

## Conventional commit format

```
<type>(<scope>): <subject>

<optional body>
```

**Example output:**

```
feat(auth): add JWT refresh token rotation

Tokens now rotate on every use to limit the blast radius of a leaked
refresh token. The old token is invalidated immediately after issuance
of the new one.
```

## Rules the skill follows

- Never auto-stages unrelated files — only commits what you've staged
- Never amends a previous commit unless explicitly asked
- If a pre-commit hook fails, it fixes the issue and retries rather than bypassing the hook

## License

MIT
