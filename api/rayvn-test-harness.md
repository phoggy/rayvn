---
layout: default
title: "rayvn/test-harness"
parent: API Reference
nav_order: 12
---

# rayvn/test-harness

Test runner.

## Functions

### executeTests()

Execute tests for one or more rayvn projects, running test files in parallel.


*notes*


Reads project list, filter args, and option flags from the caller's environment
(the 'projects', 'args', and 'flags' variables set by the rayvn command).
Supports --nix (run inside nix develop) and --all (run locally then in nix).

### executeNixBuild()

Build the Nix flake for one or more rayvn projects, skipping any without a flake.nix.

