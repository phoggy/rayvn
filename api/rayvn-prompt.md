---
layout: default
title: "rayvn/prompt"
parent: API Reference
nav_order: 3
---

# rayvn/prompt

Interactive user prompts.

## Functions

### request()

Read user input into a variable.


*Args*

| | |
|---|---|
| `prompt` *(string)* | Displayed prompt text. |
| `resultVarName` *(stringRef)* | Name of the variable to store the result in. |
| `cancelOnEmpty` *(bool)* | Cancel on empty input (default: true). |
| `timeout` *(int)* | Inactivity timeout in seconds (default: 30). Resets on each key press. |
| `hide` *(bool)* | Hide input (default: false). |
{: .args-table}

*Notes*


The -n flag suppresses the trailing newline on completion (same semantics as echo -n).


*Returns*

| | |
|---|---|
| `0` | success |
| `1` | empty input and cancelOnEmpty is true |
| `124` | timeout |
| `130` | user canceled (ESC) |
{: .args-table}

### secureRequest()

Read user input without echoing it to the terminal.


*Args*

| | |
|---|---|
| `prompt` *(string)* | Displayed prompt text. |
| `resultVarName` *(stringRef)* | Name of the variable to store the input. |
| `cancelOnEmpty` *(bool)* | Whether to cancel on empty input (default: true). |
| `timeout` *(int)* | Inactivity timeout in seconds (default: 30). Resets on every key press. |
{: .args-table}

*Notes*


The -n flag suppresses the trailing newline on completion (same semantics as echo -n).


*Returns*

| | |
|---|---|
| `0` | success |
| `1` | empty input and cancelOnEmpty is true |
| `124` | timeout |
| `130` | user canceled (ESC pressed) |
{: .args-table}

### confirm()

Ask the user to confirm a side-by-side choice, e.g. 'yes' or 'no'.


*Args*

| | |
|---|---|
| `prompt` *(string)* | Displayed prompt text. |
| `answer1` *(string)* | First choice label. |
| `answer2` *(string)* | Second choice label. |
| `resultVarName` *(stringRef)* | Name of var to receive the selected choice label. |
| `defaultAnswerTwo` *(bool)* | When true, answer2 is selected initially (default: false). |
| `timeout` *(int)* | Inactivity timeout in seconds (default: 30). Resets on every key press. |
{: .args-table}

*Notes*


The -n flag suppresses the trailing newline, as in echo -n.

For destructive actions, consider defaulting to the safer choice: either put the negative answer first, or
pass true for defaultAnswerTwo.


*Returns*

| | |
|---|---|
| `0` | success |
| `124` | timeout |
| `130` | user canceled (ESC pressed) |
{: .args-table}

### choose()

Choose from a list of options using the arrow keys.


*Args*

| | |
|---|---|
| `prompt` *(string)* | Displayed prompt text. |
| `choicesVarName` *(arrayRef)* | Name of the array var containing choices. |
| `resultVarName` *(stringRef)* | Name of the var to store the selected choice index. |
| `addSeparator` *(bool)* | Add a blank line between items (default: false). |
| `startIndex` *(int)* | Index of the initially selected item (default: 0). |
| `numberChoices` *(int)* | When or if to number the choices: > 0 = always; < 0 = only if 1 or more items are off-screen; |
| `maxVisibleItems` *(int)* | Max items to display. 0 = fill available terminal rows; < 0 = clear screen then fill (default: 0). |
| `timeout` *(int)* | Inactivity timeout in seconds (default: 30). Resets on any keypress. |
| `showResult` *(bool)* | Write the selected item after the prompt before returning (default: true). |
{: .args-table}

*Notes*


The -n flag suppresses the trailing newline on completion (same semantics as echo -n).


*Returns*

| | |
|---|---|
| `0` | success |
| `124` | timeout (inactivity) |
| `130` | user canceled (ESC pressed) |
{: .args-table}

*Example*

```bash
choices=("Apple" "Banana" "Cherry")
choose "Pick a fruit:" choices selectedIndex
echo "You picked index: ${selectedIndex}"
```

