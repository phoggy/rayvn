---
layout: default
title: "rayvn/config"
parent: "Scripting"
grand_parent: API Reference
nav_order: 9
---

# rayvn/config

Configuration file support.

## Functions

### sourceConfigFile()

Source only safe, static variable declarations from a config file or string into the current env.


*args*

| | |
|---|---|
| `input` *(string)* | Path to a config file or a raw bash string to parse. |
| `prefixFilter` *(string)* | Optional variable name prefix to restrict which vars are sourced. |
{: .args-table}

### extractSafeStaticVars()

Parse a bash config file or string, extracting only safe static variable declarations.
Filters out function definitions, function calls, command substitutions, and comments.


*args*

| | |
|---|---|
| `input` *(string)* | String or file path containing bash variable declarations to parse. |
| `prefixFilter` *(string)* | Only include variables matching this prefix (optional). |
{: .args-table}

