---
layout: default
title: "rayvn/deps"
parent: API Reference
nav_order: 5
---

# rayvn/deps

## Functions

### checkProjectDeps

**Library:** `rayvn/deps`

Library for project dependency checking and brew formula generation.
Intended for use via: require 'rayvn/deps'
Check that all required project dependencies are available in PATH.
Reads flake.nix from the project root and applies overrides from rayvn.pkg.
Silently skips if flake.nix is not found (Nix/Homebrew installs manage their own deps).
Args: projectName
  projectName  - the rayvn project name (e.g. 'valt', 'wardn')

```bash
checkProjectDeps()
```

### getBrewDeps

**Library:** `rayvn/deps`

Print brew formula depends_on lines for a project.
Reads flake.nix and applies overrides from rayvn.pkg.
Args: projectName [projectRoot]
  projectName  - the rayvn project name (e.g. 'valt', 'wardn')
  projectRoot  - optional path override (defaults to `${projectName}`Home then PWD)

```bash
getBrewDeps()
```

