# Claude Skills

> Slash commands for [Claude Code](https://claude.ai/code) — install a skill, type a command, get the job done. Every time.

[![Claude](https://img.shields.io/badge/Claude-AI-black?logo=anthropic)](https://claude.ai)
[![CI](https://github.com/claude-contrib/claude-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/claude-contrib/claude-skills/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/claude-contrib/claude-skills)](https://github.com/claude-contrib/claude-skills/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Skills are intentional — you invoke them when you need them. Each skill is a focused workflow: one command, one job, done right. No more writing the same prompt over and over.

## How Skills Work

Type a command in Claude Code. Claude reads the skill's prompt template, executes the workflow, and delivers the result. That's it.

```
/gh-issue-plan 42
```
→ Fetches issue #42, drafts a TDD-style implementation plan with estimates, shows it for review, posts it as a comment after you confirm.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/setup) (`claude`)

Install `claude` separately: [Claude Code installation guide](https://docs.anthropic.com/en/docs/claude-code/setup)

## Quickstart

**1. Register the marketplace** in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claude-skills": {
      "source": {
        "source": "github",
        "repo": "claude-contrib/claude-skills"
      }
    }
  }
}
```

**2. Install a skill** inside Claude Code:

```
/plugin install github@claude-skills
```

**3. Use it:**

```
/gh-issue-plan 42
```

## Available Skills

| Skill | Commands | What it does |
|-------|----------|--------------|
| [`github`](plugins/github/README.md) | `/gh-issue-comment`, `/gh-issue-edit`, `/gh-issue-plan`, `/gh-pr-comment`, `/gh-pr-edit`, `/gh-pr-review` | Manage GitHub issues and pull requests — comment, edit, plan, and review via a draft → confirm → post workflow |

## Publish Your Own Skill

Have a workflow you run constantly? Turn it into a one-liner for the whole community:

```
plugins/your-skill/
├── .claude-plugin/plugin.json     # name, version, description
├── commands/your-command.md       # the prompt template
└── README.md                     # usage + examples
```

Command template format:

```markdown
---
description: Shown in /help output
argument-hint: [optional-arg]
---

# Your Command

Step-by-step instructions for Claude...
```

1. **Fork** this repo and drop your plugin under `plugins/`
2. **Register** it in `.claude-plugin/marketplace.json`
3. **Open a PR** — CI validates structure automatically

→ [Read the full authoring guide](docs/README.md)

## Development

The repo ships a Nix flake for a reproducible dev environment with all CI tooling:

```bash
nix develop
```

Provides: `python3` + `check-jsonschema`, `jq`, `bash`, `shellcheck`, `gh`.

## The claude-contrib Ecosystem

| Repo | What it provides |
|------|-----------------|
| [claude-extensions](https://github.com/claude-contrib/claude-extensions) | Hooks, context rules, session automation |
| [claude-features](https://github.com/claude-contrib/claude-features) | Devcontainer features for Claude Code and Anthropic tools |
| [claude-languages](https://github.com/claude-contrib/claude-languages) | LSP language servers — completions, diagnostics, hover |
| [claude-sandbox](https://github.com/claude-contrib/claude-sandbox) | Sandboxed Docker environment for Claude Code |
| [claude-services](https://github.com/claude-contrib/claude-services) | MCP servers — browser, filesystem, sequential thinking |
| **claude-skills** ← you are here | Slash commands for Claude Code |
| [claude-status](https://github.com/claude-contrib/claude-status) | Live status line — context, cost, model, branch, worktree |

## License

MIT — use it, fork it, extend it.
