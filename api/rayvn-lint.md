---
layout: default
title: "rayvn/lint"
parent: API Reference
nav_order: 18
---

# rayvn/lint

Bash requirement linting.

## Functions

### runLint()

Scan one or more registered projects for bash requirement violations, optionally fixing them.


*Usage*

`runLint [--fix | --ask] [PROJECT...]`
{: .usage-signature}

| | |
|---|---|
| `--fix` | Automatically apply all auto-fixable corrections. |
| `--ask` | Interactively prompt whether to fix each file with violations. |
| `[PROJECT...]` | Registered project names to scan. Defaults to current project. |
{: .usage-table}

