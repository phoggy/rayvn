---
layout: default
title: "rayvn/release"
parent: API Reference
nav_order: 13
---

# rayvn/release

GitHub release workflow.

## Functions

### release()

Perform a full release pipeline for a GitHub project: run tests, update flake.nix and flake.lock, verify the Nix build,
create the GitHub release, and sets the post-release version.


*args*

| | |
|---|---|
| `ghRepo` *(string)* | GitHub repo in 'account/repo' format. |
| `version` *(string)* | Version string to release (e.g. '1.2.3'). |
{: .args-table}

