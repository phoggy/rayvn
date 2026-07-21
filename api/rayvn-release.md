---
layout: default
title: "rayvn/release"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 14
---

# rayvn/release

GitHub release workflow.

## Functions

### release()

Perform a full release pipeline for a GitHub project: run tests, update flake.nix and flake.lock, verify the Nix build,
create the GitHub release, and sets the post-release version. The GitHub 'account/repo' is derived from the
current directory's git 'origin' remote, whose repo name must match the project.


*args*

| | |
|---|---|
| `project` *(string)* | The project name; must match the current repo's name. |
| `version` *(string)* | Version string to release (e.g. '1.2.3'). |
{: .args-table}

