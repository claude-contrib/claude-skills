# Claude Skills

A curated collection of Claude Code skills — slash commands and prompt templates that you invoke intentionally.

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

Then install skills:

```text
/plugin install <skill-name>@claude-skills
```

## Available Skills

| Skill                                  | Command   | Description                                                   |
| -------------------------------------- | --------- | ------------------------------------------------------------- |
| [`commit`](plugins/commit/README.md)   | `/commit` | Create a well-structured git commit with a conventional message |

## What are skills?

Skills are slash commands you invoke intentionally (e.g. `/commit`, `/review-pr`). Each skill is a prompt template that tells Claude how to perform a specific task. Skills differ from:

- **Extensions** (`claude-extensions`) — passive hooks and context rules that run automatically
- **Services** (`claude-services`) — MCP servers that provide tools Claude uses autonomously

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a new skill.

A skill plugin requires:

```
plugins/<skill-name>/
├── .claude-plugin/plugin.json   # name, version, description, author
├── skill.md                     # the prompt template (becomes /skill-name)
└── README.md                    # usage docs
```

## License

MIT
