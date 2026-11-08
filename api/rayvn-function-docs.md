---
layout: default
title: "rayvn/function-docs"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 17
---

# rayvn/function-docs

Audit and update function doc comments.

## Functions

### auditDocs()

Audit and update function doc comments using the ◇ structured format.
Use via: require 'rayvn/function-docs'
Audit function doc comment coverage for registered projects, reporting missing or stale docs.


*usage*

`auditDocs [--release] [PROJECT]...`
{: .usage-signature}

| | |
|---|---|
| `--release` | Exit 1 if any public functions are missing ◇ doc comments, or any doc comment entry breaks the spec. |
| `PROJECT` *(string)* | One or more project names to audit (default: all loaded projects). |
{: .usage-table}

### updateDocs()

Generate or update doc comments for public functions using the Claude API. An existing doc is edited rather than
rewritten, given as context the change to the function's body since its doc was last in sync, the docs of the
functions it calls, and its library's description and notes. Functions whose docs are not updated (skipped,
previewed or failed) stay reported as missing or stale.


*usage*

`updateDocs [--dry-run] [--yes] [--regen] [--missing-only] [--stale-only] [--lib NAME] [--since DURATION] [--delay SECS] [PROJECT...]`
{: .usage-signature}

| | |
|---|---|
| `--dry-run` | Print each proposed change as a diff, without writing changes. |
| `--yes` | Apply proposed changes without asking. Otherwise, at a terminal, each is shown as a diff to apply, skip or edit; without a terminal, changes are applied, except those flagged as likely to have lost information. |
| `--regen` | Regenerate docs for all public functions, not just missing or stale. |
| `--missing-only` | Only process functions with no doc comment. |
| `--stale-only` | Only process functions with stale docs. |
| `--lib NAME` *(string)* | Limit processing to a single library by name. |
| `--since DURATION` *(string)* | Skip functions updated within this duration (e.g. '30m', '2h', '1d'); ignored with `--regen`. |
| `--delay SECS` *(int)* | Seconds to sleep between API calls (default: 5). |
| `[PROJECT]` *(string)* | One or more project names to limit scope (default: all loaded projects). |
{: .usage-table}

