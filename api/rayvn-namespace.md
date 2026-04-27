---
layout: default
title: "rayvn/namespace"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 21
---

# rayvn/namespace

Detect namespace collisions across registered rayvn project libraries.

## Functions

### checkNamespaces()

Check for function and global variable name collisions across all (or specified) registered
rayvn project libraries. Reports each collision with its sources and returns 1 if any found.


*usage*

`checkNamespaces [PROJECT...]`
{: .usage-signature}

| | |
|---|---|
| `[PROJECT...]` | Registered project names to check. Defaults to all registered projects. |
{: .usage-table}

*notes*


Globals detected: explicit declare -g* declarations (anywhere in the file). This is the
rayvn convention for intentional globals. Implicit globals inside functions (missing
local/declare) are caught by the lint implicit-global check.

_init_* functions are excluded: they are ephemeral init functions, not part of the namespace.

