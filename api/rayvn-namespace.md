---
layout: default
title: "rayvn/namespace"
parent: API Reference
nav_order: 10
---

# rayvn/namespace

Detect namespace collisions across registered rayvn project libraries.
Use via: require 'rayvn/namespace'

## Functions

### checkNamespaces()

Check for function and global variable name collisions across all (or specified) registered
rayvn project libraries. Reports each collision with its sources and returns 1 if any found.


*Usage*

`checkNamespaces [PROJECT...]`
{: .usage-signature}

| | |
|---|---|
| `[PROJECT...]` | Registered project names to check. Defaults to all registered projects. |
{: .usage-table}

*Notes*


Globals detected: explicit declare -g* declarations (anywhere in the file). This is the
rayvn convention for intentional globals. Implicit globals inside functions (missing
local/declare) are caught by the lint implicit-global check.

_init_* functions are excluded: they are ephemeral init functions, not part of the namespace.

