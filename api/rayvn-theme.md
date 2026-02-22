---
layout: default
title: "rayvn/theme"
parent: API Reference
nav_order: 8
---

# rayvn/theme

## Functions

### showCurrentTheme

**Library:** `rayvn/theme`

Theme functions.
Intended for use via: require 'rayvn/theme'
Display the currently active theme with its color swatches.
Args: [prefix]
  prefix - optional text to print before the theme display

```bash
showCurrentTheme() {
```

### showThemes

**Library:** `rayvn/theme`

Display all available themes with their color swatches.
Args: [position]
  position - padding position for theme names: 'after'/'left' (default), 'before'/'right', or 'center'

```bash
showThemes() {
```

### setTheme

**Library:** `rayvn/theme`

Interactively prompt the user to select and apply a new theme.

```bash
setTheme() {
```

