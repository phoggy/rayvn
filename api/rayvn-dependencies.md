---
layout: default
title: "rayvn/dependencies"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 16
---

# rayvn/dependencies

Dependency checking and Homebrew formula generation.

## Functions

### checkProjectDependencies()

Check that all required dependencies for a project are available in PATH, printing install hints and failing if
any are missing. Silently skips if the project root or flake.nix is not accessible.


*args*

| | |
|---|---|
| `projectName` *(string)* | Name of the rayvn project to check. |
{: .args-table}

*env vars (from rayvn.pkg)*

nixBinaryMap       Map of nix pkg name → binary name overrides. [R/W]
nixBrewMap         Map of nix pkg name → brew formula overrides. [R/W]
nixBrewExclude     Array of nix pkg names to skip brew checks for. [R/W]
nixSkipBinaryCheck Array of nix pkg names with no on-PATH binary to check (e.g. a sourced
                   shell library like bash-completion); still included in the brew formula. [R/W]
gemDeps            Map of gem name → binary name for Ruby gem dependencies. [R/W]

### checkGemDependencies()

Check that all Ruby gem dependencies for a project are available in PATH, printing install hints and failing
if any are missing. Reads gemDeps from rayvn.pkg. Silently succeeds if no gemDeps are declared.


*args*

| | |
|---|---|
| `projectName` *(string)* | Name of the rayvn project to check. |
| `projectRoot` *(string)* | Root path of the project; defaults to ${projectName}Home or PWD. |
{: .args-table}

*env vars (from rayvn.pkg)*

gemDeps  Map of gem package name → binary name (e.g. [bundler]='bundle'). [R/W]

### getBrewDependencies()

Outputs 'depends_on' formula lines for a project's brew dependencies. Reads flake.nix deps and applies name
mappings and exclusions from rayvn.pkg.


*args*

| | |
|---|---|
| `projectName` *(string)* | Name of the rayvn project (e.g. "valt", "wardn"). |
| `projectRoot` *(string)* | Root path of the project; defaults to ${projectName}Home or PWD. |
{: .args-table}

