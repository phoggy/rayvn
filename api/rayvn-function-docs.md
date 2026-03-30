---
layout: default
title: "rayvn/function-docs"
parent: API Reference
nav_order: 6
---

# rayvn/function-docs

Audit and update function doc comments

## Functions

### auditDocs()

Audit and update function doc comments using the ◇ structured format.
Use via: require 'rayvn/function-docs'
Audit function doc comment coverage for registered projects, reporting missing or stale docs.


*Usage*

`auditDocs [--release] [PROJECT]...`
{: .usage-signature}

| | |
|---|---|
| `--release` | Exit 1 if any public functions are missing ◇ doc comments. |
| `PROJECT` *(string)* | One or more project names to audit (default: all loaded projects). |
{: .usage-table}

### updateDocs()

Generate or update doc comments for public functions using the Claude API; applies changes directly.


*Usage*

`updateDocs [--dry-run] [--regen] [--missing-only] [--stale-only] [--lib NAME] [--since DURATION] [--delay SECS] [PROJECT...]`
{: .usage-signature}

| | |
|---|---|
| `--dry-run` | Print proposed docs without writing any changes. |
| `--regen` | Regenerate docs for all public functions, not just missing/stale. |
| `--missing-only` | Only process functions missing a ◇ doc comment. |
| `--stale-only` | Only process functions with potentially stale docs. |
| `--lib NAME` *(string)* | Limit to a single library by name. |
| `--since DURATION` *(string)* | Skip functions updated within this duration (e.g. '30m', '2h', '1d'). Ignored when --regen is set. |
| `--delay SECS` *(int)* | Seconds to sleep between API calls to avoid rate limits (default: 5). |
| `PROJECT` *(string)* | One or more project names (default: all loaded projects). |
{: .usage-table}

