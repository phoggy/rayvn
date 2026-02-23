---
layout: default
title: "rayvn/central"
parent: API Reference
nav_order: 1
---

# rayvn/central

## Functions

### registerProjectOnRayvnCentral

**Library:** `rayvn/central`

Manages rayvn-central project registration.
Intended for use via: require 'rayvn/central'
Register a rayvn project on rayvn-central by creating a GitHub issue in the registry repo.
Uses the current directory's git remote URL to identify the project.
Args: projectName
  projectName - the name to register (must not already be taken in the registry)

```bash
registerProjectOnRayvnCentral() {
```

### getProjectRegistryPath

**Library:** `rayvn/central`

Return the path to a project's registry file in the rayvn-central registry repo.
The file may or may not exist.
Args: projectName
  projectName - name of the project to look up

```bash
getProjectRegistryPath() {
```

