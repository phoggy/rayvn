---
layout: default
title: "rayvn/index"
parent: API Reference
nav_order: 6
---

# rayvn/index

## Functions

### runIndex

**Library:** `rayvn/index`

Library for generating and publishing rayvn library function indexes and Jekyll docs.
Intended for use via: require 'rayvn/index'
Generate function indexes and/or Jekyll docs for rayvn project libraries.
Reads options from args passed in; discovers libraries via _rayvnProjects.
Args: [OPTIONS]
  -o, --output FILE        Verbose index output file (default: ~/.config/rayvn/rayvn-functions.md)
  -c, --compact FILE       Compact index output file (default: ~/.config/rayvn/rayvn-functions-compact.txt)
  --no-compact             Skip generating compact index
  --no-hash                Skip function hash tracking
  --hash-file FILE         Hash storage file (default: ~/.config/rayvn/rayvn-function-hashes.txt)
  --docs DIR               Generate Jekyll docs pages into DIR
  --publish                Generate and publish docs to each project's gh-pages worktree

```bash
runIndex()
```

