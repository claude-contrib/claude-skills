# Documentation

## Plugin Development

- [Plugins overview](https://code.claude.com/docs/en/plugins) — How plugins work, component types, installation
- [Plugin marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) — Creating and distributing marketplaces
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) — Schema specifications for plugin.json and marketplace.json
- [Slash commands](https://code.claude.com/docs/en/slash-commands) — Command development, frontmatter format, argument handling

## Skills Structure

Each skill is a plugin with one or more command files:

```
plugins/<skill-name>/
├── .claude-plugin/plugin.json
├── commands/
│   └── <command-name>.md    # frontmatter + instructions
└── README.md
```

Command frontmatter:

```yaml
---
description: Shown in /help output
argument-hint: [optional-arg]
---
```

## Template

This marketplace was created from [ivan-magda/claude-code-plugin-template](https://github.com/ivan-magda/claude-code-plugin-template), which includes a full local copy of these docs plus a `plugin-development` toolkit for scaffolding and validation.
