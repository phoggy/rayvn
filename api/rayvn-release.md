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
current directory's git 'origin' remote, whose repo name must match the project. The release commit sets the
version and release date in rayvn.pkg (and the version in flake.nix), so that the tagged release reports itself as
that release; afterwards rayvn.pkg is marked as the post-release version (VERSION+, no date). Flake inputs that
are the same owner's GitHub projects (e.g. rayvn, for valt) are locked to their latest releases first, before the
tests. Rerunning
the release of a version that rayvn.pkg already holds (an interrupted release) continues it.


*usage*

`release [--yes] project version`
{: .usage-signature}

| | |
|---|---|
| `--yes` | Answer yes to the questions (release, push), e.g. to run without a terminal; an existing GitHub release of the version is then not deleted, but stops the release. |
| `project` *(string)* | The project name; must match the current repo's name. |
| `version` *(string)* | Version string to release (e.g. '1.2.3'). |
{: .usage-table}

