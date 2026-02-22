---
layout: default
title: "rayvn/terminal"
parent: API Reference
nav_order: 10
---

# rayvn/terminal

## Functions

### cursorHide

**Library:** `rayvn/terminal`

shellcheck disable=SC2120,SC2155
Library supporting terminal operations
Intended for use via: require 'rayvn/terminal'
Hide the terminal cursor.

```bash
cursorHide() {
```

### cursorShow

**Library:** `rayvn/terminal`

Show the terminal cursor.

```bash
cursorShow() {
```

### cursorPosition

**Library:** `rayvn/terminal`

Read the current cursor position via the terminal's CPR response and store it via namerefs.
Args: rowVar colVar
  rowVar - nameref variable to receive the 1-based row number
  colVar - nameref variable to receive the 1-based column number

```bash
cursorPosition() {
```

### cursorSave

**Library:** `rayvn/terminal`

Save the current cursor position. Note: save/restore does not work correctly if scrolling
occurs between the save and restore; use `reserveRows()` first to prevent scrolling.

```bash
cursorSave() {
```

### cursorRestore

**Library:** `rayvn/terminal`

Restore the cursor to the position saved by `cursorSave()`.

```bash
cursorRestore() {
```

### cursorUp

**Library:** `rayvn/terminal`

Move the cursor up by a number of rows.
Args: [rows]
  rows - number of rows to move up (default: 1)

```bash
cursorUp() {
```

### cursorUpToLineStart

**Library:** `rayvn/terminal`

Move the cursor up by a number of rows and place it at the start of the line.
Args: [rows]
  rows - number of rows to move up (default: 1)

```bash
cursorUpToLineStart() {
```

### cursorUpToColumn

**Library:** `rayvn/terminal`

Move the cursor up by a number of rows and place it at a specific column.
Args: rows col
  rows - number of rows to move up
  col  - 1-based column to move to

```bash
cursorUpToColumn() {
```

### cursorDown

**Library:** `rayvn/terminal`

Move the cursor down by a number of rows.
Args: [rows]
  rows - number of rows to move down (default: 1)

```bash
cursorDown() {
```

### cursorDownToLineStart

**Library:** `rayvn/terminal`

Move the cursor down by a number of rows and place it at the start of the line.
Args: [rows]
  rows - number of rows to move down (default: 1)

```bash
cursorDownToLineStart() {
```

### cursorDownToColumn

**Library:** `rayvn/terminal`

Move the cursor down by a number of rows and place it at a specific column.
Args: rows col
  rows - number of rows to move down
  col  - 1-based column to move to

```bash
cursorDownToColumn() {
```

### cursorTo

**Library:** `rayvn/terminal`

Move the cursor to an absolute terminal position (row, col).
Args: row [col]
  row - 1-based row to move to
  col - 1-based column to move to (default: 0)

```bash
cursorTo() {
```

### cursorToColumn

**Library:** `rayvn/terminal`

Move the cursor to an absolute column on the current row.
Args: col
  col - 1-based column to move to

```bash
cursorToColumn() {
```

### cursorToLineStart

**Library:** `rayvn/terminal`

Move the cursor to column 1 (start) of the current row.

```bash
cursorToLineStart() {
```

### cursorToColumnAndEraseToEndOfLine

**Library:** `rayvn/terminal`

Move the cursor to a column and erase from that position to the end of the line.
Args: col
  col - 1-based column to move to before erasing

```bash
cursorToColumnAndEraseToEndOfLine() {
```

### cursorUpOneAndEraseLine

**Library:** `rayvn/terminal`

Move the cursor up one row and erase the entire line.

```bash
cursorUpOneAndEraseLine() {
```

### cursorDownOneAndEraseLine

**Library:** `rayvn/terminal`

Move the cursor down one row and erase the entire line.

```bash
cursorDownOneAndEraseLine() {
```

### eraseToEndOfLine

**Library:** `rayvn/terminal`

Erase from the cursor position to the end of the current line.

```bash
eraseToEndOfLine() {
```

### eraseCurrentLine

**Library:** `rayvn/terminal`

Erase the entire current line and move the cursor to column 1.

```bash
eraseCurrentLine() {
```

### clearTerminal

**Library:** `rayvn/terminal`

Clear the entire terminal and move the cursor to the top-left.

```bash
clearTerminal() {
```

### reserveRows

**Library:** `rayvn/terminal`

Scroll the terminal if necessary to ensure a minimum number of rows are available below the cursor.
Adjusts the current cursor row to account for any scrolling that occurred.
Args: [requiredRows]
  requiredRows - number of rows needed below the current cursor position (default: 2)

```bash
reserveRows() {
```

