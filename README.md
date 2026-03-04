# Claude Skills

> Slash commands for [Claude Code](https://claude.ai/code) — type `/commit`, get a perfect conventional commit. Every time.

[![Validate](https://github.com/claude-contrib/claude-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/claude-contrib/claude-skills/actions/workflows/validate.yml)
[![Release](https://img.shields.io/github/v/release/claude-contrib/claude-skills)](https://github.com/claude-contrib/claude-skills/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Skills are intentional — you invoke them when you need them. Each skill is a focused workflow: one command, one job, done right. No more writing the same prompt over and over.

## How Skills Work

Type a command in Claude Code. Claude reads the skill's prompt template, executes the workflow, and delivers the result. That's it.

```
/commit
```
→ Diffs staged changes, checks commit history, writes a conventional commit message, creates the commit.

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
/plugin install commit@claude-skills
```

**3. Use it:**

```
/commit
```

## Available Skills

| Skill | Command | What it does |
|-------|---------|--------------|
| [`commit`](plugins/commit/README.md) | `/commit` | Diffs staged changes, infers type/scope, writes and creates a [conventional commit](https://www.conventionalcommits.org/) |

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

## The claude-contrib Ecosystem

| Marketplace | Install key | What it provides |
|-------------|------------|-----------------|
| [claude-extensions](https://github.com/claude-contrib/claude-extensions) | `@claude-extensions` | Hooks, context rules, session automation |
| [claude-services](https://github.com/claude-contrib/claude-services) | `@claude-services` | MCP servers — browser, filesystem, sequential thinking |
| **claude-skills** ← you are here | `@claude-skills` | Slash commands — `/commit`, and more |

## License

MIT — use it, fork it, extend it.
