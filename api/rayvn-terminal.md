---
layout: default
title: "rayvn/terminal"
parent: API Reference
nav_order: 17
---

# rayvn/terminal

Cursor control and terminal output

## Functions

### cursorHide()

Hide the terminal cursor.

### cursorShow()

Show the terminal cursor.

### cursorPosition()

Read the current cursor position.


*Args*

| | |
|---|---|
| `rowVarRef` *(stringRef)* | Receives the 1-based row number. |
| `colVarRef` *(stringRef)* | Receives the 1-based column number. |
{: .args-table}

*Example*

```bash
cursorPosition row col
echo "Cursor is at row $row, col $col"
```

### cursorSave()

Save the current cursor position. Note: save/restore does not work correctly if scrolling
occurs between the save and restore; use `reserveRows()` first to prevent scrolling.

### cursorRestore()

Restore the cursor to the position saved by `cursorSave()`.

### cursorUp()

Move the cursor up N rows (default: 1).

### cursorUpToLineStart()

Move cursor up N rows and back to line start (default: 1).

### cursorUpToColumn()

Move the cursor up N rows and place it at a 1-based column.


*Args*

| | |
|---|---|
| `rows` *(int)* | Number of rows to move up. |
| `col` *(int)* | 1-based column to move to. |
{: .args-table}

### cursorDown()

Move the cursor down by the given number of rows (default: 1).

### cursorDownToLineStart()

Move the cursor down N rows and to the start of the line (default: 1).

### cursorDownToColumn()

Move the cursor down N rows then to a 1-based column position.


*Args*

| | |
|---|---|
| `rows` *(int)* | Number of rows to move down. |
| `col` *(int)* | 1-based column to place the cursor at. |
{: .args-table}

### cursorTo()

Move the cursor to an absolute terminal position.


*Args*

| | |
|---|---|
| `row` *(int)* | 1-based row to move to. |
| `col` *(int)* | 1-based column to move to (default: 0). |
{: .args-table}

### cursorToColumn()

Move the cursor to an absolute 1-based column on the current row.

### cursorToLineStart()

Move the cursor to column 1 of the current row.

### cursorToColumnAndEraseToEndOfLine()

Move cursor to column N (1-based) and erase to end of line.

### cursorUpOneAndEraseLine()

Move the cursor up one row and erase the entire line.

### cursorDownOneAndEraseLine()

Move the cursor down one row and erase the entire line.

### eraseToEndOfLine()

Erase from the cursor position to the end of the current line.

### eraseCurrentLine()

Erase the entire current line and move the cursor to column 1.

### clearTerminal()

Clear the entire terminal and move the cursor to the top-left.

### reserveRows()

Scroll the terminal to ensure requiredRows are available below the cursor,
adjusting the cursor position to account for any scrolling that occurred.


*Args*

| | |
|---|---|
| `requiredRows` *(int)* | Rows needed below the cursor (default: 2). |
{: .args-table}

