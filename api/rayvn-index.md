---
layout: default
title: "rayvn/index"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 17
---

# rayvn/index

Generate function indexes for AI agent use.

## Functions

### runIndex()

Generate verbose and optional compact function indexes for rayvn libraries.


*usage*

`runIndex [-o FILE] [-c FILE] [--no-compact] [--no-hash] [--hash-file FILE]`
{: .usage-signature}

| | |
|---|---|
| `-o, --output FILE` *(string)* | Verbose index output file (default: ~/.config/rayvn/rayvn-functions.md). |
| `-c, --compact FILE` *(string)* | Compact index output file (default: ~/.config/rayvn/rayvn-functions-compact.txt). |
| `--no-compact` | Skip generating the compact index. |
| `--no-hash` | Skip function hash tracking. |
| `--hash-file FILE` *(string)* | Hash storage file (default: ~/.config/rayvn/rayvn-function-hashes.txt). |
{: .usage-table}

### runPages()

Generate Jekyll pages for a single project's gh-pages site.


*usage*

`runPages PROJECT [--dir DIR] [--setup | --record | --publish | --view]`
{: .usage-signature}

| | |
|---|---|
| `PROJECT` *(string)* | The project to generate pages for (e.g. rayvn, valt, wardn). |
| `--dir DIR` *(string)* | Output directory (default: project's configured worktree). |
| `--setup` | First-time setup: create gh-pages branch, worktree, and workflow. |
| `--record` | [ID...]       Re-record asciinema casts with cmd= attributes in markdown files; optional IDs filter to specific casts. |
| `--publish` | Commit and push changes to gh-pages after generating. |
| `--view` | Serve pages locally with Jekyll after generating (mutually exclusive with --publish). |
{: .usage-table}

### findDependencies()

Scan a project's source files for external command dependencies and sync them to flake.nix.
Confirms external binaries via command -v, maps them to nix package names via rayvn.pkg,
and adds any missing entries to flake.nix. Also delegates npm dependency updates.


*args*

| | |
|---|---|
| `projectName` *(string)* | Name of the rayvn project to scan (e.g. 'valt', 'rayvn'). |
| `fixMode` *(string)* | Optional. Pass 'fix' to auto-replace awk→gawk and sed→gsed in source. |
{: .args-table}

