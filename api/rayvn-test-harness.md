---
layout: default
title: "rayvn/test-harness"
parent: "Testing"
grand_parent: API Reference
nav_order: 13
---

# rayvn/test-harness

Test runner.

## Functions

### executeTests()

Execute tests for one or more rayvn projects, running test files in parallel.


*args*

| | |
|---|---|
| `projectsRef` *(arrayRef)* | Project names to test. |
| `matchArgsRef` *(arrayRef)* | Test name include patterns; prefix with '-' to exclude. |
| `nix` *(bool)* | Run tests inside nix develop (default: 0). |
| `all` *(bool)* | Run tests locally and then again inside nix (default: 0). |
{: .args-table}

### executeNixBuild()

Build the Nix flake for one or more rayvn projects, skipping any without a flake.nix.


*args*

| | |
|---|---|
| `projectsRef` *(arrayRef)* | Project names to build. |
{: .args-table}

