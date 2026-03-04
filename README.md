# Claude Skills

A curated collection of Claude Code skills — slash commands and prompt templates you invoke intentionally.

[![Plugins](https://github.com/claude-contrib/claude-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/claude-contrib/claude-skills/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What are Skills?

Skills are slash commands (e.g. `/commit`, `/review-pr`) that you invoke intentionally to trigger a specific workflow. They differ from:

- **Extensions** ([claude-extensions](https://github.com/claude-contrib/claude-extensions)) — hooks and context rules that run passively
- **Services** ([claude-services](https://github.com/claude-contrib/claude-services)) — MCP servers providing tools to Claude

## Installation

Add the marketplace to your Claude Code settings (`~/.claude/settings.json`):

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

Then install a skill:

```text
/plugin install <plugin-name>@claude-skills
```

## Available Skills

| Plugin | Command | Description |
| --- | --- | --- |
| [`commit`](plugins/commit/README.md) | `/commit` | Create a well-structured git commit with a conventional message |

## Contributing

1. Fork this repository
2. Create a plugin directory under `plugins/<your-plugin>/`
3. Add `.claude-plugin/plugin.json`, a `commands/<name>.md` with frontmatter, and a `README.md`
4. Register your plugin in `.claude-plugin/marketplace.json`
5. Open a pull request — CI validates the structure automatically

### Command frontmatter format

```markdown
---
description: Brief description shown in /help
argument-hint: [optional-arg]
---

# Command Name

Instructions for Claude...
```

See [docs/](docs/) for plugin development guides.

## License

MIT
