---
layout: default
title: "rayvn/claude"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 23
---

# rayvn/claude

The guide for Claude Code on working with rayvn projects.

## Functions

### updateClaudeGuide()

Render the rayvn guide for Claude Code into the rayvn config directory, from etc/claude/rayvn.md with a table of
the rayvn projects on this system (development checkouts whose bin directory is on PATH). The file is only written
when its content changes. Run via 'rayvn index' or 'rayvn index --claude' after adding a project to PATH or
upgrading rayvn. A project's CLAUDE.md loads the guide with an import: @~/.config/rayvn/claude-rayvn.md


*usage*

`updateClaudeGuide [-q]`
{: .usage-signature}

| | |
|---|---|
| `-q, --quiet` | Do not report whether the guide was updated. |
{: .usage-table}

### claudeGuideFile()

Output the path of the rendered rayvn guide for Claude Code.

