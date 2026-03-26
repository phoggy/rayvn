---
layout: default
title: "rayvn/theme"
parent: API Reference
nav_order: 19
---

# rayvn/theme

Color themes

## Functions

### showCurrentTheme()

Display the currently active theme, optionally preceded by a prefix string.

### showThemes()

Display all available themes with color swatches at the given position, defaulting to 'after'.

### setTheme()

Interactively prompt the user to select and apply a new theme.


*Args*

| | |
|---|---|
| `maxVisible` *(int)* | Max themes to display. 0 = fill available terminal rows; < 0 = clear screen then fill (default: 0). |
{: .args-table}

