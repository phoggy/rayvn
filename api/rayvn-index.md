---
layout: default
title: "rayvn/index"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 18
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
| `--record [ID...]` | Re-record asciinema casts with cmd= attributes in markdown files; optional IDs filter to specific casts. |
| `--publish` | Commit and push changes to gh-pages after generating. |
| `--view` | Serve pages locally with Jekyll after generating (mutually exclusive with `--publish`). |
| `The` | project's pagesHook, if its rayvn.pkg sets one, is run after the docs are generated (see _runPagesHook). |
| `Libraries` | named in its pagesExclude array, e.g. pagesExclude=('security-kit'), are left out of its pages (see |
| `_excludePagesLibraries),` | e.g. until they work. |
{: .usage-table}

### findDependencies()

Scan a project's source files for external command dependencies and check that they are declared in flake.nix.
Confirms external binaries via command -v and maps them to nix package names via rayvn.pkg (commands from
packages such as coreutils map to that package). Reports missing entries and portability issues, and runs project deps plugins
(plugins/*-plugin.sh). Files are only changed in fix mode. Returns non-zero if any problem is left unfixed.


*args*

| | |
|---|---|
| `projectName` *(string)* | Name of the rayvn project to scan (e.g. 'valt', 'rayvn'). |
| `fixMode` *(string)* | Optional. Pass 'fix' to add missing entries to flake.nix, replace awk→gawk and sed→gsed in source, and let plugins apply their fixes. |
{: .args-table}

