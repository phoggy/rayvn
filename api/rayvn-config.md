---
layout: default
title: "rayvn/config"
parent: API Reference
nav_order: 2
---

# rayvn/config

## Functions

### sourceConfigFile

**Library:** `rayvn/config`

Library supporting sanitizing and sourcing env style files.
Intended for use via: require 'rayvn/config'
Source only safe variable declarations from a bash config file or string, optionally filtered
by prefix. See extractSafeStaticVars.
Usage: sourceConfigFile <file_or_string> [prefix_filter]
Output: variables are defined in current env

```bash
sourceConfigFile()
```

### extractSafeStaticVars

**Library:** `rayvn/config`

Parse a bash config file or string and extract only safe variable declarations.
This function processes bash files to extract variable declarations while ensuring
no side effects can occur by filtering out:
- All function definitions
- All function calls
- All variable declarations containing command substitutions
It also filters out comments, but wraps the result with
begin/end comments.
Usage: extractSafeStaticVars <file_or_string> [prefix_filter]
Output: Safe variable declarations that can be sourced

```bash
extractSafeStaticVars()
```

