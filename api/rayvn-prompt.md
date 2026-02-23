---
layout: default
title: "rayvn/prompt"
parent: API Reference
nav_order: 7
---

# rayvn/prompt

## Functions

### request

**Library:** `rayvn/prompt`

shellcheck disable=SC2155
Library of user input functions.
Intended for use via: require 'rayvn/prompt'
Read user input.
Usage: request [-n] <prompt> <resultVarName> [true/false cancel-on-empty] [timeout seconds] [true/false hidden]
The seconds counter is reset to 0 on every key press, so timeout applies only to inactivity. The -n option is
the same as in echo: no newline is appended.
Output: resultVar set to input.
Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

```bash
request() {
```

### secureRequest

**Library:** `rayvn/prompt`

Read user input without echoing it to the terminal.
Usage: requestHidden [-n] <prompt> <resultVarName> [true/false cancelOnEmpty] [timeout seconds]
The seconds counter is reset to 0 on every key press, so timeout applies only to inactivity. The -n option is
the same as in echo: no newline is appended.
Output: resultVar set to input.
Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

```bash
secureRequest() {
```

### confirm

**Library:** `rayvn/prompt`

Ask the user to confirm a side-by-side choice, e.g. 'yes' or 'no'.
Usage: confirm [-n] <prompt> <answer1> <answer2> <choiceIndexVarName> [true/false defaultAnswerTwo] [timeout seconds]
Answer 1 will be selected first by default. For an important action (e.g. deleting / creating something), consider
making it a *little* harder to select the positive choice so that two key presses (arrow and enter) are required.
There are two ways to accomplish this:
   1. Pass the negative answer first, or
   2. Pass 'true' for defaultAnswerTwo to maintain a consistent answer sequence across invocations
The seconds counter is reset to 0 on every key press, so timeout applies only to inactivity. The -n option is
the same as in echo: no newline is appended.
Output: choiceIndexVar set to 0 for answer 1 or 1 for answer 2
Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

```bash
confirm() {
```

### choose

**Library:** `rayvn/prompt`

Choose from a list of options using the arrow keys.
Usage: choose [-n] <prompt> <choicesVarName> <resultIndexVarName> [true/false addSeparator] [startIndex] [numberChoices]
              [maxVisible] [timeout seconds]
If numberChoices is > 0 choices will be numbered, and if < 0, numbers will be added only if there are non-visible choices.
If maxVisible is not passed, or is set to 0, uses all lines below the current cursor to display items; if < 0, clears and
uses entire terminal.
The seconds counter is reset to 0 on every key press, so timeout applies only to inactivity. The -n option is
the same as in echo: no newline is appended.
Output: choiceIndexVar set to index of selected choice.
Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

```bash
choose() {
```

