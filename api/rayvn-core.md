---
layout: default
title: "rayvn/core"
parent: API Reference
nav_order: 3
---

# rayvn/core

Core utilities, assertions, and error handling

## Output & Error Functions

### show()

Enhanced echo with text colors, styles, and standard echo options.
Each FORMAT token applies to the immediately following TEXT arg only, then resets.
Multiple FORMAT tokens before a TEXT arg accumulate for that one TEXT arg.


*Usage*

```shell
show [-n] [-e|-E] [FORMAT|TEXT]...

-n                 No trailing newline.
-e                 Enable backslash escape interpretation.
-E                 Suppress backslash escape interpretation.
[FORMAT] (string)  A format token (see NOTES); applies to the next [TEXT] arg.
[TEXT] (string)    A string to print with accumulated formats applied, then reset.
```

*Notes*

```
Available formats:

  Theme:      success, error, warning, info, accent, muted
  Style:      bold, dim, italic, underline, blink, reverse, strikethrough
  Foreground: black, red, green, yellow, blue, magenta, cyan, white (and bright-* variants)
  Background: bg-black, bg-red, bg-green, bg-yellow, bg-blue, bg-magenta, bg-cyan, bg-white
              (and bg-bright-* variants)
  256-color:  IDX <0-255>
  true-color: RGB <R:G:B>
  Special:    nl (insert newline), glue (suppress space before next arg)

While most modern terminals can display 256-color or true-color (24 bit), be aware that some
may not. If this is a concern, stick to theme colors as they automatically revert to 16-color
if true-color is not available. Apparently some terminals may not support strikethrough, so
use with caution.
```

*Example*

```shell
show blue "blue text"
show bold red "bold red"
show -n yellow "no trailing newline"
show success "done"
show warning "check this"
show error "failed"
show italic underline green "italic underline green"
show bold blue "heading" "body text"                      # heading resets; body is plain
show cyan "colored" dim "dim, no color"                   # each arg gets its own format
show "Line 1" nl "Line 2"                                 # newline between args
show bg-blue white "white on blue"
show IDX 42 "256-color #42" RGB 52:208:88 "truecolor"
show "(default:" blue "${configDir}" glue ")."            # suppress space before closing paren
result="${ show bold green "ok"; }"                       # in command substitution
```

### header()

Print a styled section header with optional subtitle lines.


*Usage*

```shell
header [-u] [colorIndex] title [subtitle [FORMAT|TEXT]...]

-u                   Convert title to uppercase.
colorIndex (int)     Color index, clamped to max (0=bold, 1=accent, 2=secondary, 3=warning, 4=success, 5=muted).
title (string)       Title text printed in bold.
[subtitle] (string)  First subtitle arg, printed in the header color.
[FORMAT] (string)    A show format token; applies to the next [TEXT] arg.
[TEXT] (string)      Text to print with the preceding format applied.
```

### warn()

Print a warning message to stderr with a ⚠️ prefix.


*Usage*

```shell
warn message [FORMAT|TEXT]...

message (string)   Warning message text.
[FORMAT] (string)  A show format token; applies to the next [TEXT] arg.
[TEXT] (string)    Text to print with the preceding format applied.
```

### error()

Print an error message to stderr with a 🔺 prefix.


*Usage*

```shell
error message [FORMAT|TEXT]...

message (string)   Error message text.
[FORMAT] (string)  A show format token; applies to the next [TEXT] arg.
[TEXT] (string)    Text to print with the preceding format applied.
```

### invalidArgs()

Fail with a stack trace. Shorthand for fail --trace on invalid arguments.


*Usage*

```shell
invalidArgs message [FORMAT|TEXT]...

message (string)   Error message text.
[FORMAT] (string)  A show format token; applies to the next [TEXT] arg.
[TEXT] (string)    Text to print with the preceding format applied.
```

### fail()

Print an error and exit 1, optionally with a stack trace.


*Usage*

```shell
fail [--trace] message [FORMAT|TEXT]...

--trace            Force a stack trace regardless of debug mode.
message (string)   Error message text.
[FORMAT] (string)  A show format token; applies to the next [TEXT] arg.
[TEXT] (string)    Text to print with the preceding format applied.
```

### bye()

Print an optional exit message, show stack if in debug mode, and exit 0.


*Usage*

```shell
bye [message [FORMAT|TEXT]...]

[message] (string)   Exit message text.
[FORMAT] (string)    A show format token; applies to the next [TEXT] arg.
[TEXT] (string)      Text to print with the preceding format applied.
```

### stackTrace()

Print a formatted call stack, optionally preceded by a message.


*Usage*

```shell
stackTrace [message [FORMAT|TEXT]...]

[message] (string)   Message text.
[FORMAT] (string)    A show format token; applies to the next [TEXT] arg.
[TEXT] (string)      Text to print with the preceding format applied.
```

### errorStream()

Print each line of a piped stream in error color to terminalErr.


*Example*

```shell
someCommand 2> >( errorStream )
```

## Argument & Variable Functions

### parseOptionalArg()

Check if an argument matches an expected value, setting a result var via nameref.


*Args*

| | |
|---|---|
| `argMatch` | (string)         Expected argument value to match against (e.g. -n). |
| `argValue` | (string)         Actual argument value to test. |
| `argResultRef` | (stringRef)  Name of var to set to argResultValue on match, or '' if not. |
| `argResultValue` | (string)   Value to assign on match; defaults to ${argMatch}. |
{: .args-table}

*Returns*

| | |
|---|---|
| `0` | matched |
| `1` | not matched |
{: .args-table}

### varDefined()

Return 0 if a variable with the given name is defined, including empty or null-value vars.

### assertVarDefined()

Fail if a variable with the given name is not defined.

### eraseVars()

Overwrite one or more security sensitive variables with spaces then unset.


*Args*

| | |
|---|---|
| `varName` | (stringRef)  Name of a variable to erase; may be repeated, silently ignored if unset. |
{: .args-table}

### exportGlobalMaps()

Register one or more associative arrays (passed by name) for export to child processes.
Bash cannot export associative arrays directly; this serializes them into an internal
exported variable. When a child process sources rayvn.up, the map(s) will be restored.
Needed when a script spawns a child process (e.g. via bash or exec) that sources rayvn.up
and calls functions that depend on the map. Not needed for subshells (`${ }` and `$( )`),
which inherit variables automatically. Call from a library _init function.


*Args*

| | |
|---|---|
| `varName` | (stringRef)  Name of an associative array to register; may be repeated. |
{: .args-table}

*Example*

```shell
# In 'myproject/mylib' _init_myproject_mylib(),  build a lookup table, then register it so that
# child processes launched by the user's script (e.g. bash myOtherScript) see the populated map.
declare -gA myLookup=([foo]=1 [bar]=2)
exportGlobalMaps myLookup
```

## Assertion Functions

### assertIsInteractive()

Fail with an error if not running interactively.

### assertFileExists()

Fails if the given path does not exist.

### assertFile()

Fail if the given path does not exist or is not a regular file.


*Args*

| | |
|---|---|
| `file` | (string)         Path that must exist and be a regular file. |
| `description` | (string)  Label used in the error message (default: "file"). |
{: .args-table}

### assertDirectory()

Fail if the given path does not exist or is not a directory.

### assertFileDoesNotExist()

Fail if the given path already exists.

### assertPathWithinDirectory()

Fails if filePath is not located within dirPath, resolving symlinks before checking.


*Args*

| | |
|---|---|
| `filePath` | (string)    Path to verify. |
| `dirPath` | (string)     Directory that must contain filePath. |
{: .args-table}

### assertValidFileName()

Fail if name is not a valid cross-platform filename component.


*Args*

| | |
|---|---|
| `name` | (string)  Filename component to validate (not a full path). |
{: .args-table}

*Notes*

```
Rejects: empty string, . .. / control characters <>:"\|?*
```

### assertGitRepo()

Fail if the given directory (or PWD) is not within a git repository.


*Args*

| | |
|---|---|
| `dir` | (string)  Directory to check (default: ${PWD}). |
{: .args-table}

### assertCommand()

Run a command and fail if it exits non-zero, or if it produces stderr with --stderr.


*Usage*

```shell
assertCommand [--strip-brackets] [--quiet] [--stderr] [--error MSG] command...

--strip-brackets       Strip lines matching '^\[.*\]$' and trailing blank lines from stderr.
--quiet                Suppress stderr content from the failure message.
--stderr               Also fail if the command produces any stderr output.
--error MSG (string)   Custom failure message (default: stderr output or generic exit code message).
... (string)           The command and arguments to execute.
```

*Example*

```shell
assertCommand git commit -m "message"
```

*Example*

```shell
session="${ assertCommand --stderr --error "Failed to unlock" bw unlock --raw; }"
```

*Example*

```shell
# For pipelines, wrap in eval:
assertCommand --stderr --error "Failed to encrypt" \
    eval 'tar cz "${dir}" | rage "${recipients[@]}" > "${file}"'
```

### trim()

Outputs a string with leading and trailing whitespace removed.

### repeat()

Outputs a string repeated N times, without a trailing newline.


*Args*

| | |
|---|---|
| `str` | (string)  String to repeat. |
| `count` | (int)   Number of repetitions. |
{: .args-table}

### padString()

Outputs a string padded to a given width, measuring visible length by stripping ANSI codes.


*Args*

| | |
|---|---|
| `string` | (string)    Target string. |
| `width` | (int)        Minimum visible character width. |
| `position` | (string)  Padding side: 'after'/'left' (default), 'before'/'right', or 'center'. |
{: .args-table}

### stripAnsi()

Outputs a string with any ANSI escape sequences removed.

### containsAnsi()

Return 0 if a string contains ANSI escape sequences, 1 otherwise.

### indexOf()

Find the index of a matching element in an array, storing the result in resultRef (-1 if not found).


*Args*

| | |
|---|---|
| `match` | (string)         Match value; prefix with -p for prefix match, -s for suffix match, -r for regex. |
| `arrayRef` | (arrayRef)    Name of the indexed array to search. |
| `resultRef` | (stringRef)  Name of the variable to store the found index. |
{: .args-table}

*Returns*

| | |
|---|---|
| `0` | match found |
| `1` | no match found |
{: .args-table}

### memberOf()

Return 0 if item is a member of an array, 1 otherwise.


*Args*

| | |
|---|---|
| `item` | (string)        Value to search for. |
| `arrayRef` | (arrayRef)  Name of the indexed array to search. |
{: .args-table}

### maxArrayElementLength()

Outputs the length of the longest element in an array.


*Args*

| | |
|---|---|
| `arrayRef` | (arrayRef)  Name of the indexed array to measure. |
{: .args-table}

### copyMap()

Copy all key-value pairs from one associative array to another.


*Args*

| | |
|---|---|
| `src` | (mapRef)   Name of the source map. |
| `dest` | (mapRef)  Name of the destination map (must already be declared with -A). |
{: .args-table}

## Number & Random Value Functions

### numericPlaces()

Outputs the number of decimal digits needed to represent integers up to maxValue.


*Args*

| | |
|---|---|
| `maxValue` | (int)  Largest value to represent; must be a positive integer. |
| `startValue` | (int)  Index base: 0 (zero-indexed, default) or 1 (one-indexed). |
{: .args-table}

### printNumber()

Outputs a number right-aligned within a fixed-width field.


*Args*

| | |
|---|---|
| `number` | (int)  Number to output. |
| `places` | (int)  Minimum field width; defaults to 1. |
{: .args-table}

### randomInteger()

Set a variable to a random integer, optionally capped at maxValue (inclusive).


*Args*

| | |
|---|---|
| `intResult` | (stringRef)  Variable to receive the result. |
| `maxValue` | (int)  Optional inclusive upper bound; omits for full SRANDOM range. |
{: .args-table}

### randomHexChar()

Set a random hex character (0–9, a–f) via nameref.


*Args*

| | |
|---|---|
| `_hexResultRef` | (stringRef)  Name of the variable to receive the result. |
{: .args-table}

### randomHexString()

Generate a random hex string of count characters, stored via name-ref.


*Args*

| | |
|---|---|
| `count` | (int)  Number of hex characters to generate. |
| `_resultRef` | (stringRef)  Name of the variable to receive the result. |
{: .args-table}

### replaceRandomHex()

Replace every occurrence of a placeholder character in a string with random hex chars, in-place.


*Args*

| | |
|---|---|
| `replaceChar` | (string)    The placeholder character to replace. |
| `replaceRef` | (stringRef)  Name of the variable to modify in-place. |
{: .args-table}

*Example*

```shell
myStr="XXXX-XXXX"
replaceRandomHex "X" myStr  # myStr becomes e.g. "3a7f-c209"
```

## Time Functions

### timeStamp()

Outputs the current timestamp as a sortable string: YYYY-MM-DD_HH.MM.SS_TZ

### epochSeconds()

Outputs the current epoch time with microsecond precision via EPOCHREALTIME.

### elapsedEpochSeconds()

Outputs elapsed seconds since a previously captured EPOCHREALTIME value (6 decimal places).


*Args*

| | |
|---|---|
| `startTime` | (string)  Value previously captured from EPOCHREALTIME. |
{: .args-table}

## File System Functions

### withDefaultUmask()

Execute a command with umask 0022 (files readable by all, writable only by owner).

### withUmask()

Execute a command with a temporary umask, restoring the original afterward.


*Args*

| | |
|---|---|
| `newUmask` | (string)  Umask to set for the duration (e.g. 0022, 0077). |
| `command` | (string)   Command and arguments to execute. |
{: .args-table}

### binaryPath()

Outputs the path to a binary, or fails with an optional custom error message if not found.


*Args*

| | |
|---|---|
| `name` | (string)    Name of the binary to locate in PATH. |
| `errMsg` | (string)  Error message if not found; defaults to "'${name}' not found". |
{: .args-table}

### tempDirPath()

Outputs the session temp directory path, optionally appended with a file name. Does not create the file or dir.


*Usage*

```shell
tempDirPath [-r] [fileName]

-r                   Replace 'X' chars in fileName with random hex chars, or generate an 8-char hex name if
                     fileName is omitted. Ensures that no name collisions occur, regenerating name up to 16
                     times if required.
fileName (string)    Optional file name to append to the temp dir path.
```

### makeTempFile()

Creates a unique temp file in the session temp dir, outputting its path.


*Args*

| | |
|---|---|
| `fileName` | (string)  Optional; see tempDirPath -r. |
{: .args-table}

### makeTempFifo()

Creates a unique named pipe (FIFO) in the session temp dir, outputting its path.


*Args*

| | |
|---|---|
| `fileName` | (string)  Optional; see tempDirPath -r. |
{: .args-table}

### makeTempDir()

Create a unique temp directory in the session temp directory, outputting its path.


*Args*

| | |
|---|---|
| `dirName` | (string)  Optional; see tempDirPath -r. |
{: .args-table}

### configDirPath()

Outputs the config directory path for the current project, creating it if needed,
optionally joined with fileName.


*Args*

| | |
|---|---|
| `fileName` | (string)    Optional name of a file to append to the config dir path. |
{: .args-table}

### ensureDir()

Create directory if it does not already exist.

### makeDir()

Create a directory (and any missing parents), outputting the final path.


*Args*

| | |
|---|---|
| `dir` | (string)     Base directory path. |
| `subDir` | (string)  Optional subdirectory to append before creating. |
{: .args-table}

### dirName()

Outputs the directory component of a path, equivalent to dirname.

### baseName()

Outputs the final component of a path, equivalent to basename.

### readFile()

Read the entire contents of a file into a variable, without forking a subprocess.
Trailing newlines are stripped, matching command substitution behavior.


*Usage*

```shell
readFile [-p] file resultVar

-p                     Preserve trailing newlines instead of stripping them.
file (string)          Path to the file to read.
resultVar (stringRef)  Name of variable to receive the file contents.
```

### setFileVar()

Set a nameref variable to the realpath of a file, failing if the path is not a regular file.


*Args*

| | |
|---|---|
| `resultVar` | (stringRef)  Name of variable to receive the resolved file path. |
| `filePath` | (string)      Path to the file (must exist and be a regular file). |
| `description` | (string)   Label used in error messages. |
{: .args-table}

### setDirVar()

Set a nameref variable to the realpath of a directory, failing if the path is not a directory.


*Args*

| | |
|---|---|
| `resultVar` | (stringRef)  Name of variable to receive the resolved directory path. |
| `dirPath` | (string)       Path to the directory (must exist and be a directory). |
| `description` | (string)   Label used in error messages. |
{: .args-table}

## Process & Environment Functions

### pushIFS()

Push a new value onto the IFS stack and set IFS to that value.
Use popIFS to restore the previous value.


*Args*

| | |
|---|---|
| `newIFS` | (string)  The new IFS value. |
{: .args-table}

*Example*

```shell
pushIFS $'\n'
for item in ${list}; do ...
popIFS
```

### popIFS()

Pop a previously pushed IFS value, restoring IFS to its prior state.


*Example*

```shell
pushIFS $'\n'
popIFS
```

### addExitHandler()

Register a shell command to be executed at exit, in registration order.

### projectVersion()

Outputs the version string for a rayvn project, reading its rayvn.pkg file.


*Args*

| | |
|---|---|
| `projectName` | (string)  Name of the project (e.g. 'rayvn', 'valt'). |
| `verbose` | (string)      If non-empty, appends release date or "(development)" to output. |
{: .args-table}

### openUrl()

Open a URL in the default browser (macOS: open, Linux: xdg-open).


*Args*

| | |
|---|---|
| `url` | (string)  The URL to open. |
{: .args-table}

### executeClean()

Execute a command with rayvn internal variables unset, simulating a clean environment.

### setDebug()

Enable debug mode.


*Usage*

```shell
setDebug [--tty TTY|.] [--noStatus] [--clearLog] [--showLogOnExit]

--tty TTY (string)    Log debug messages to the TTY instead of the log file.
--tty .               Log debug messages to the TTY read from "${HOME}/.debug.tty".
--noStatus            Suppress debug status line display.
--clearLog            Clear the log file if not tty mode.
--showLogOnExit       Show the log file on exit if not tty mode.
```

