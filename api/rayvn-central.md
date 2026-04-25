---
layout: default
title: "rayvn/central"
parent: API Reference
nav_order: 14
---

# rayvn/central

Project registry.

## Functions

### registerProjectOnRayvnCentral()

Request registration of a rayvn project name on rayvn-central.


*Args*

| | |
|---|---|
| `projectName` *(string)* | Name to register; fails if already taken in the central registry. |
{: .args-table}

*Side effects*

Creates a GitHub issue in the rayvn-central/registry repo with project name, description,
remote URL, and earliest commit date (or current timestamp if no commits exist).

*Notes*


Assumes PWD is within the repo for the given rayvn project..

### getProjectRegistryPath()

Returns the path to a project's registry file in the rayvn-central registry repo (may not exist).

