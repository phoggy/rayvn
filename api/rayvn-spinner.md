---
layout: default
title: "rayvn/spinner"
parent: API Reference
nav_order: 15
---

# rayvn/spinner

Terminal spinners

## Functions

### spinnerTypes()

Populates an array with the names of all available spinner types.


*Args*

| | |
|---|---|
| `resultArray` *(arrayRef)* | Array to populate with spinner type names. |
{: .args-table}

*Example*

```bash
local types
spinnerTypes types
echo "Available: ${types[*]}"
```

### startSpinner()

Start a spinner at the current cursor position, storing its assigned ID via nameref.


*Args*

| | |
|---|---|
| `idVarName` *(stringRef)* | Name of var holding the spinner ID (from startSpinner). |
| `label` *(string)* | Optional text displayed before the spinner. |
| `type` *(string)* | Spinner type (default: 'star'). |
| `color` *(string)* | Color name (default: 'secondary'). |
{: .args-table}

*Example*

```bash
local spinnerId
startSpinner spinnerId "Loading" dots primary
doWork
stopSpinner spinnerId "Done"
```

### stopSpinner()

Stop a spinner, optionally replacing it with the given text.


*Args*

| | |
|---|---|
| `idVarName` *(stringRef)* | Name of var holding the spinner ID (from startSpinner). |
| `replacement` *(string)* | Text to display in place of the spinner (default: space). |
{: .args-table}

*Notes*

```
The -n flag suppresses the trailing newline, as in echo -n.
```

*Example*

```bash
stopSpinner spinnerId "Done"
stopSpinner -n spinnerId
```

### addSpinner()

Add a spinner at a specific terminal position, storing its assigned id via nameref.


*Args*

| | |
|---|---|
| `idRef` *(stringRef)* | Name of var to receive the spinner id. |
| `type` *(string)* | Spinner type. |
| `row` *(int)* | Terminal row (1-based). |
| `col` *(int)* | Terminal column (1-based). |
| `color` *(string)* | Color name for the spinner (default: 'secondary'). |
{: .args-table}

### removeSpinner()

Remove a spinner by id; prefer stopSpinner for typical use.


*Args*

| | |
|---|---|
| `idVarName` *(stringRef)* | Name of var holding the spinner id (from addSpinner). |
| `replacement` *(string)* | Text to display in place of the spinner (default: space). |
| `newline` *(bool)* | Emit a newline after replacement (default: true). |
| `backup` *(int)* | Characters to back up before writing replacement (default: 0). |
{: .args-table}

### spinnerCloseInheritedFds()

Close the inherited spinner client fds in a subshell forked from the spinner owner.
Call this at the start of any ( ) & subshell that inherits these fds, to prevent
accidental writes that would corrupt the spinner FIFO protocol.

