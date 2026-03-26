---
layout: default
title: "rayvn/lint"
parent: API Reference
nav_order: 8
---

# rayvn/lint

Scan rayvn project source files for bash requirement violations.

## Functions

### runLint()

Scan one or more registered projects for bash requirement violations, optionally fixing them.


*Usage*

```bash
runLint [--fix | --ask] [PROJECT...]

--fix            Automatically apply all auto-fixable corrections.
--ask            Interactively prompt whether to fix each file with violations.
[PROJECT...]     Registered project names to scan. Defaults to current project.
```

