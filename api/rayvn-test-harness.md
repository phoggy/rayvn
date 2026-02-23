---
layout: default
title: "rayvn/test-harness"
parent: API Reference
nav_order: 14
---

# rayvn/test-harness

## Functions

### executeTests

**Library:** `rayvn/test-harness`

My library.
Intended for use via: require 'rayvn/test-harness'
Execute tests for one or more rayvn projects, running test files in parallel.
Reads project list, filter args, and option flags from the caller's environment
(the 'projects', 'args', and 'flags' variables set by the rayvn command).
Supports --nix (run inside nix develop) and --all (run locally then in nix).

```bash
executeTests()
```

### executeNixBuild

**Library:** `rayvn/test-harness`

Build the Nix flake for one or more rayvn projects.
Reads the project list from the caller's 'projects' environment variable
(set by the rayvn command). Skips projects without a flake.nix.

```bash
executeNixBuild()
```

