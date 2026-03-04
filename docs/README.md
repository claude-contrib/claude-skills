# Contributor Guide — Claude Skills

Everything you need to build and publish a slash command skill.

## What is a Skill?

A skill is a Claude Code plugin that provides one or more **slash commands** — focused workflows you invoke intentionally (e.g. `/commit`, `/review-pr`). Each command is a markdown prompt template that tells Claude exactly how to execute the task.

## Plugin Structure

```
plugins/<your-skill>/
├── .claude-plugin/
│   └── plugin.json              # required — plugin manifest
├── commands/
│   └── <command-name>.md        # required — one file per command
└── README.md                    # required — usage docs
```

A plugin can provide multiple commands. Each `.md` file in `commands/` becomes a separate slash command, prefixed with the plugin name: `/<plugin>:<command>` or `/<command>` if the plugin and command share the same name.

## `plugin.json` — Plugin Manifest

```json
{
  "name": "your-skill",
  "version": "1.0.0",
  "description": "What this skill does",
  "author": {
    "name": "your-name",
    "email": "you@example.com",
    "url": "https://github.com/your-name"
  },
  "homepage": "https://github.com/claude-contrib/claude-skills",
  "repository": "https://github.com/claude-contrib/claude-skills",
  "license": "MIT",
  "keywords": ["relevant", "tags"]
}
```

## Command Files — `commands/<name>.md`

Each command file must start with a YAML frontmatter block:

```markdown
---
description: Shown in /help output — keep it under 80 characters
argument-hint: [optional-arg]
---

# Command Title

Instructions for Claude on how to execute this command.

## Steps

1. First step
2. Second step
3. Third step
```

**Frontmatter fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `description` | Yes | One-line description shown in `/help` |
| `argument-hint` | No | Hint shown in autocomplete, e.g. `[name]` or `<file>` |

**Using arguments:**

When the user types `/your-command some text here`, the text after the command name is available as `$ARGUMENTS` in your prompt:

```markdown
If the user provided `$ARGUMENTS`, use it as a hint for the output.
```

## Registering in `marketplace.json`

```json
{
  "name": "your-skill",
  "description": "One-line description",
  "version": "1.0.0",
  "author": { "name": "your-name" },
  "source": "./plugins/your-skill",
  "category": "developer-tools",
  "tags": ["relevant", "tags"],
  "keywords": ["relevant", "keywords"]
}
```

## Testing Locally

```bash
# 1. Clone the repo and navigate to it
cd claude-skills

# 2. Open Claude Code
claude

# 3. Add the local marketplace
/plugin marketplace add .

# 4. Install your skill
/plugin install your-skill@claude-skills

# 5. Run your command
/your-command
```

To iterate: edit the command file, then reinstall:

```
/plugin uninstall your-skill@claude-skills
/plugin install your-skill@claude-skills
```

## CI Validation

Every pull request runs `.github/workflows/validate.yml` which checks:

- `marketplace.json` is valid JSON with required fields (`name`, `owner`, `plugins`)
- Each plugin entry has `name` and `source`
- Each plugin directory exists
- `plugin.json` is valid JSON with a `name` field
- Command files have frontmatter (starts with `---`)
- No duplicate plugin names

Run the same checks locally with `jq`:

```bash
jq empty .claude-plugin/marketplace.json
jq empty plugins/your-skill/.claude-plugin/plugin.json
head -1 plugins/your-skill/commands/your-command.md  # should print ---
```

## Official References

- [Plugins overview](https://code.claude.com/docs/en/plugins) — Plugin system, component types, installation
- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) — Marketplace creation and team distribution
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) — Full schema specifications
- [Slash commands](https://code.claude.com/docs/en/slash-commands) — Command development, frontmatter format, argument handling
