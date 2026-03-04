# commit

Create a well-structured git commit with a conventional commit message.

## Usage

```text
/commit
```

Analyzes staged changes, determines the appropriate conventional commit type and scope, and creates a commit with a well-formed message.

## What it does

1. Reviews `git diff --cached` and `git status`
2. Checks recent commit history to match the repo's style
3. Drafts a [conventional commit](https://www.conventionalcommits.org/) message
4. Creates the commit (respects pre-commit hooks)

## Installation

```text
/plugin install commit@claude-skills
```

## Example output

```
feat(auth): add JWT refresh token rotation

Tokens now rotate on every use to limit the blast radius of a leaked
refresh token. The old token is invalidated immediately after issuance
of the new one.
```
