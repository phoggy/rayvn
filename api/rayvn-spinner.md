---
layout: default
title: "rayvn/spinner"
parent: API Reference
nav_order: 12
---

# rayvn/spinner

## Functions

### spinnerTypes

**Library:** `rayvn/spinner`

My library.
Use via: require 'rayvn/spinner'
IMPORTANT: While there are active spinners, the cursor is hidden globally. Before any
foreground terminal interaction (prompts, user input, or other tput commands), you MUST
stop all spinners. Otherwise, the user will be typing with an invisible cursor or
terminal state may become inconsistent.
spinnerTypes resultArrayVar
Populates resultArrayVar with the names of all available spinner types.
Available types: star, dots, line, circle, arrow, box, bounce, pulse, grow
Example:
  local types
  spinnerTypes types
  echo "Available: `${types[*]}`"

```bash
spinnerTypes()
```

### startSpinner

**Library:** `rayvn/spinner`

startSpinner idVar [label] [type] [color]
Starts a spinner at the current cursor position, storing its id in idVar.
Pass idVar to stopSpinner to stop and replace it.
  idVar   - variable name to receive the spinner id
  label   - optional text printed immediately before the spinner (default: none)
  type    - spinner animation style (default: 'star'); see spinnerTypes
  color   - color name for the spinner (default: 'secondary')
Example:
  local spinnerId
  startSpinner spinnerId "Loading " dots primary
  doWork
  stopSpinner spinnerId "Done"

```bash
startSpinner()
```

### stopSpinner

**Library:** `rayvn/spinner`

stopSpinner [-n] idVar [replacement]
Stops the spinner identified by idVar, replacing it with replacement text.
  -n          - suppress the trailing newline after replacement
  idVar       - variable name holding the spinner id (from startSpinner)
  replacement - text to display in place of the spinner (default: space)
Example:
  stopSpinner spinnerId "Done"
  stopSpinner -n spinnerId   # stop without newline

```bash
stopSpinner()
```

### addSpinner

**Library:** `rayvn/spinner`

addSpinner idVar type row col [color]
Adds a spinner at the specified terminal position, storing its id in idVar.
Prefer startSpinner for typical use; use this when you need explicit positioning.
  idVar  - variable name to receive the spinner id
  type   - spinner type; see spinnerTypes
  row    - terminal row (1-based)
  col    - terminal column (1-based)
  color  - color name for the spinner (default: 'secondary')

```bash
addSpinner()
```

### removeSpinner

**Library:** `rayvn/spinner`

removeSpinner idVar [replacement] [newline] [backup]
Removes the spinner identified by idVar. Prefer stopSpinner for typical use.
  idVar       - variable name holding the spinner id (from addSpinner)
  replacement - text to display in place of the spinner (default: space)
  newline     - true to emit a newline after replacement, false to suppress (default: true)
  backup      - number of characters to back up before writing replacement (default: 0)

```bash
removeSpinner()
```

