---
layout: default
title: "rayvn/prompt"
parent: "Scripting"
grand_parent: API Reference
nav_order: 3
---

# rayvn/prompt

Interactive user prompts.

## Functions

### request()

Read user input into a variable.


*usage*

`request [-n] prompt resultVar [cancelOnEmpty] [timeout] [hide]`
{: .usage-signature}

| | |
|---|---|
| `-n` | Suppress trailing newline on completion. |
| `prompt` *(string)* | Displayed prompt text. |
| `resultVar` *(stringRef)* | Name of the variable to store the result in. |
| `cancelOnEmpty` *(bool)* | Cancel on empty input (default: true). |
| `timeout` *(int)* | Inactivity timeout in seconds (default: 30). Resets on each key press. |
| `hide` *(bool)* | Hide input (default: false). |
{: .usage-table}

*returns*

| | |
|---|---|
| `0` | success |
| `1` | empty input and cancelOnEmpty is true |
| `124` | timeout |
| `130` | user canceled (ESC) |
{: .args-table}

### secureRequest()

Read user input without echoing it to the terminal.


*usage*

`secureRequest [-n] prompt resultVar [cancelOnEmpty] [timeout]`
{: .usage-signature}

| | |
|---|---|
| `-n` | Suppress trailing newline on completion. |
| `prompt` *(string)* | Displayed prompt text. |
| `resultVar` *(stringRef)* | Name of the variable to store the input. |
| `cancelOnEmpty` *(bool)* | Whether to cancel on empty input (default: true). |
| `timeout` *(int)* | Inactivity timeout in seconds (default: 30). Resets on every key press. |
{: .usage-table}

*returns*

| | |
|---|---|
| `0` | success |
| `1` | empty input and cancelOnEmpty is true |
| `124` | timeout |
| `130` | user canceled (ESC pressed) |
{: .args-table}

### confirm()

Ask the user to confirm a side-by-side choice, e.g. 'yes' or 'no'.


*usage*

`confirm [-n] prompt answer1 answer2 resultVar [defaultAnswerTwo] [timeout]`
{: .usage-signature}

| | |
|---|---|
| `-n` | Suppress trailing newline on completion. |
| `prompt` *(string)* | Displayed prompt text. |
| `answer1` *(string)* | First choice label. |
| `answer2` *(string)* | Second choice label. |
| `resultVar` *(stringRef)* | Name of var to receive the selected choice index. |
| `defaultAnswerTwo` *(bool)* | When true, answer2 is selected initially (default: false). |
| `timeout` *(int)* | Inactivity timeout in seconds (default: 30). Resets on every key press. |
{: .usage-table}

*notes*


For destructive actions, consider defaulting to the safer choice: either put the negative answer first, or
pass true for defaultAnswerTwo.


*returns*

| | |
|---|---|
| `0` | success |
| `124` | timeout |
| `130` | user canceled (ESC pressed) |
{: .args-table}

### choose()

Choose from a list of options using the arrow keys.


*usage*

`choose [-n] prompt choicesVar resultVar [addSeparator] [startIndex] [numberChoices] [maxVisible] [timeout] [showResult]`
{: .usage-signature}

| | |
|---|---|
| `-n` | Suppress trailing newline on completion. |
| `prompt` *(string)* | Displayed prompt text. |
| `choicesVar` *(arrayRef)* | Name of the array var containing choices. |
| `resultVar` *(stringRef)* | Name of the var to store the selected choice index. |
| `addSeparator` *(bool)* | Add a blank line between items (default: false). |
| `startIndex` *(int)* | Index of the initially selected item (default: 0). |
| `numberChoices` *(int)* | When or if to number the choices: > 0 = always; < 0 = only if 1 or more items are off-screen; 0 = never (default: 0). |
| `maxVisible` *(int)* | Max items to display. 0 = fill terminal rows; < 0 = clear screen then fill (default: 0). |
| `timeout` *(int)* | Inactivity timeout in seconds (default: 30). Resets on any keypress. |
| `showResult` *(bool)* | Write the selected item after the prompt before returning (default: true). |
{: .usage-table}

*returns*

| | |
|---|---|
| `0` | success |
| `124` | timeout (inactivity) |
| `130` | user canceled (ESC pressed) |
{: .args-table}

*example*

```bash
local choices=("Apple" "Banana" "Cherry")
local chosenIndex
choose "Pick a fruit:" choices chosenIndex
echo "You picked index: ${chosenIndex}"
```

