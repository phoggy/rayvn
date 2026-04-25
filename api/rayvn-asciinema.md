---
layout: default
title: "rayvn/asciinema"
parent: API Reference
nav_order: 19
---

# rayvn/asciinema

Asciinema cast recording and post-processing.

## Functions

### asciinemaRecord()

Record one or more commands with asciinema and post-process the cast in-place.
Deletes any existing cast file, records each command separately with a simulated
typing prelude, concatenates them into a single cast, and trims the terminal
dimensions to fit the content.

The recording PTY is sized to the host terminal so interactive widgets render
correctly. Falls back to 220x24 if the terminal size cannot be detected.


*Args*

| | |
|---|---|
| `castFile` *(string)* | Output path for the cast file. |
{: .args-table}

*Options*

--cmd CMD       Command to record (repeatable; required; each recorded as a
                separate segment with its own typing prelude, concatenated in order).
--pre CMD       Shell command to run before recording (optional; runs in current shell).
--post CMD      Shell command to run after recording (optional; runs in current shell).
--wpm N         Typing speed in words per minute (default: 120).
--prompt TEXT   Shell prompt text (default: '[COMMAND]$ ').
--no-trim       Skip trimming terminal dimensions to content.

*Notes*


Requires asciinema in PATH. The cast file is overwritten if it exists.
--pre and --post run once, wrapping all --cmd recordings as a group.

### typistAsciinemaEvents()

Output asciinema event lines simulating TEXT typed at WPM words per minute.
Uses typistDelays for timing, then formats each character as a JSON event.
Includes a final Enter key event.


*Args*

| | |
|---|---|
| `wpm` *(int)* | Typing speed in words per minute. |
| `text` *(string)* | The text to simulate typing. |
{: .args-table}

*Output*

Asciinema event JSON lines, one per character, followed by an Enter event.

*Example*

```bash
typistAsciinemaEvents 120 "rayvn test" >> typing.cast
```

### asciinemaTypingFile()

Generate a typing events file for use as a cast prelude.
Writes a prompt event followed by per-character events for COMMAND.


*Args*

| | |
|---|---|
| `wpm` *(int)* | Typing speed in words per minute. |
| `prompt` *(string)* | Shell prompt text (e.g. '[rayvn]$ '). |
| `command` *(string)* | Command text to simulate typing. |
| `outputFile` *(string)* | Path to write the events file. |
{: .args-table}

*Example*

```bash
local typingFile; typingFile=${ makeTempFile; }
asciinemaTypingFile 120 '[rayvn]$ ' 'rayvn test' "${typingFile}"
```

### asciinemaPostProcess()

Post-process an asciinema cast file in-place: prepend typing events and optionally
trim the terminal dimensions in the header to fit the actual content.


*Args*

| | |
|---|---|
| `castFile` *(string)* | Path to the cast file (modified in-place). |
| `typingFile` *(string)* | Path to a file of asciinema event lines to prepend. |
| `trim` *(int)* | 1 to trim header dimensions to content (default: 1), 0 to skip. |
{: .args-table}

*Notes*


Supports both v2 (absolute timestamps) and v3 (relative/delta timestamps).
For v2, original event timestamps are shifted by the total typing duration.
For v3, typing events are simply prepended (already in delta format).
Trimmed cols are at least 106 to ensure comfortable display in web players.

### asciinemaApplyTransform()

Apply a single named post-processing transform to a cast file in-place.
Run transforms one at a time to inspect the cast between steps.


*Args*

| | |
|---|---|
| `transform` *(string)* | Which transform to apply (name or step number 1–9). |
| `castFile` *(string)* | Cast file to transform in-place. |
{: .args-table}

*Options*

--cmd TEXT    Command text shown in typing prelude (required for prepend-typing).
--prompt TEXT Shell prompt text (default: '[rayvn]$ ').
--wpm N       Typing speed in words per minute (default: 120).

*Steps*

1  filter-input        Strip "i" events; fold their delta into the next event.
2  prepend-typing      Insert simulated typing prelude (requires --cmd).
3  strip-cleanup       Remove widget dropdown-close sequences before cursor-restore.
4  inject-clear        Insert \u001b[J] (clear screen) after selection result.
5  append-prompt       Append trailing shell prompt event.
6  patch-header        Strip recorder fields; compute and update dimensions.
7  insert-cursor-hide  Add \u001b[?25l] before exit event.
8  fix-positions       Shift widget absolute rows by (1 - record_row).
9  shift-typing-rows   Shift widget rows down by the number of pre-CPR newlines.

### asciinemaMarkup()

Print a Jekyll asciinema include tag for a cast file.
Walks up from the cast file's directory to find a Jekyll root (_config.yml)
and computes the web-relative src path automatically.


*Args*

| | |
|---|---|
| `castFile` *(string)* | Path to the cast file. |
{: .args-table}

*Output*

A `<!-- record id="..." cmd="..." -->` comment and
`{% raw %}{% include asciinema.html ... %}{% endraw %}` tag ready to paste into a markdown file.

*Example*

```bash
asciinemaMarkup /path/to/assets/casts/test.cast
```

