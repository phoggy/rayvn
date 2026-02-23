---
layout: default
title: "rayvn/core"
parent: API Reference
nav_order: 3
---

# rayvn/core

## Functions

### allNewFilesUserOnly

**Library:** `rayvn/core`

shellcheck disable=SC2155
Core library.
Intended for use via: require 'rayvn/core'
Set umask to 0077 so that all new files and directories are accessible only by the current user.

```bash
allNewFilesUserOnly() {
```

### withDefaultUmask

**Library:** `rayvn/core`

Execute a command with umask 0022 (files readable by all, writable only by owner).
Args: command [args...]

```bash
withDefaultUmask() {
```

### withUmask

**Library:** `rayvn/core`

Execute a command with a temporary umask, then restore the original umask.
Args: newUmask command [args...]
  newUmask - the umask to set (e.g. 0077, 0022)
  command  - command and arguments to execute under the new umask

```bash
withUmask() {
```

### binaryPath

**Library:** `rayvn/core`

Return the path to a binary, failing with an error if not found.
Args: name [errMsg]
  name   - name of the binary to locate in PATH
  errMsg - optional custom error message (default: "'name' not found")

```bash
binaryPath() {
```

### rootDirPath

**Library:** `rayvn/core`

Return a path rooted at the rayvn project root directory.
Args: relativePath
  relativePath - path relative to the rayvn root

```bash
rootDirPath() {
```

### tempDirPath

**Library:** `rayvn/core`

Return the path to the session temp directory, optionally joined with a file name.
Args: [fileName]
  fileName - optional file name to append to the temp directory path

```bash
tempDirPath() {
```

### makeTempFile

**Library:** `rayvn/core`

Create a temp file in the session temp directory and return its path.
Args: [nameTemplate]
  nameTemplate - optional mktemp name template with X placeholders (default: XXXXXX)

```bash
makeTempFile() {
```

### makeTempFifo

**Library:** `rayvn/core`

Create a named pipe (FIFO) in the session temp directory and return its path.
Args: [nameTemplate]
  nameTemplate - optional name template with X placeholders (default: XXXXXX)

```bash
makeTempFifo() {
```

### makeTempDir

**Library:** `rayvn/core`

Create a temp directory in the session temp directory and return its path.
Args: [nameTemplate]
  nameTemplate - optional mktemp name template with X placeholders (default: XXXXXX)

```bash
makeTempDir() {
```

### configDirPath

**Library:** `rayvn/core`

Return the path to the current project's config directory, optionally joined with a file name.
Creates the config directory if it does not exist.
Args: [fileName]
  fileName - optional file name to append to the config directory path

```bash
configDirPath() {
```

### ensureDir

**Library:** `rayvn/core`

Create the directory if it does not already exist. Silently succeeds if already present.
Args: dir
  dir - path of the directory to create

```bash
ensureDir() {
```

### makeDir

**Library:** `rayvn/core`

Create a directory (and any missing parents) and return its path. Fails if creation fails.
Args: dir [subDir]
  dir    - base directory path
  subDir - optional subdirectory name to append before creating

```bash
makeDir() {
```

### assertIsInteractive

**Library:** `rayvn/core`

Fail with an error if not running interactively.

```bash
assertIsInteractive() {
```

### addExitHandler

**Library:** `rayvn/core`

Register a command to be executed at exit. Commands run in registration order.
Args: command
  command - shell command string to execute on exit

```bash
addExitHandler() {
```

### dirName

**Library:** `rayvn/core`

Return the directory component of a path (equivalent to dirname).
Args: path
  path - file or directory path

```bash
dirName() {
```

### baseName

**Library:** `rayvn/core`

Return the final component of a path (equivalent to basename).
Args: path
  path - file or directory path

```bash
baseName() {
```

### trim

**Library:** `rayvn/core`

Remove leading and trailing whitespace from a string.
Args: value
  value - the string to trim

```bash
trim() {
```

### numericPlaces

**Library:** `rayvn/core`

Return the number of decimal digits needed to represent values up to maxValue.
Useful for formatting aligned numeric output.
Args: maxValue [startValue]
  maxValue   - the largest value to be displayed (must be a positive integer)
  startValue - 0 (zero-indexed, default) or 1 (one-indexed)

```bash
numericPlaces() {
```

### printNumber

**Library:** `rayvn/core`

Print a number right-aligned within a fixed-width field.
Args: number places
  number - the number to print
  places - minimum field width (right-aligned with spaces)

```bash
printNumber() {
```

### projectVersion

**Library:** `rayvn/core`

Return the version string for a rayvn project (reads its rayvn.pkg file).
Args: projectName [verbose]
  projectName - name of the project (e.g. 'rayvn', 'valt')
  verbose     - if non-empty, include release date or "(development)" in the output

```bash
projectVersion() {
```

### parseOptionalArg

**Library:** `rayvn/core`

Check if an argument matches an expected value and set a result variable via nameref.
Returns 0 if matched, 1 if not. Used for parsing optional flag-style arguments.
Args: argMatch argValue resultVar [resultValue]
  argMatch    - the expected argument value to match against (e.g. '-n')
  argValue    - the actual argument value to test
  resultVar   - nameref variable to set to resultValue if matched, or '' if not
  resultValue - value to assign on match (default: argMatch)

```bash
parseOptionalArg() {
```

### varIsDefined

**Library:** `rayvn/core`

Return 0 if a variable with the given name is defined (including empty or null-value vars).
Args: varName
  varName - name of the variable to check

```bash
varIsDefined() {
```

### assertVarDefined

**Library:** `rayvn/core`

Fail if a variable with the given name is not defined.
Args: varName
  varName - name of the variable that must be defined

```bash
assertVarDefined() {
```

### assertFileExists

**Library:** `rayvn/core`

Fail if the given path does not exist (as any filesystem entry type).
Args: path
  path - path to check for existence

```bash
assertFileExists() {
```

### assertFile

**Library:** `rayvn/core`

Fail if the given path does not exist or is not a regular file.
Args: file [description]
  file        - path that must exist and be a regular file
  description - optional label for the error message (default: 'file')

```bash
assertFile() {
```

### assertDirectory

**Library:** `rayvn/core`

Fail if the given path does not exist or is not a directory.
Args: dir
  dir - path that must exist and be a directory

```bash
assertDirectory() {
```

### assertFileDoesNotExist

**Library:** `rayvn/core`

Fail if the given path already exists.
Args: path
  path - path that must not exist

```bash
assertFileDoesNotExist() {
```

### assertPathWithinDirectory

**Library:** `rayvn/core`

Fail if filePath is not located within dirPath (resolves symlinks before checking).
Args: filePath dirPath
  filePath - the path to verify
  dirPath  - the directory that must contain filePath

```bash
assertPathWithinDirectory() {
```

### assertValidFileName

**Library:** `rayvn/core`

Fail if the given name is not a valid cross-platform filename component.
Rejects empty strings, ".", "..", paths with slashes, control characters, and reserved characters.
Args: name
  name - the filename component to validate (not a full path)

```bash
assertValidFileName() {
```

### assertCommand

**Library:** `rayvn/core`

Run a command and fail if it fails (or produces stderr with --stderr).
Stdout passes through, so this works with command substitution.
Usage:
  assertCommand [options] command [args...]
  result="`${ assertCommand some-command; }`"
Options:
  --error "msg"     Custom error message (default: generic failure message)
  --quiet           Don't include stderr in failure message
  --stderr          Also fail if command produces stderr output
  --strip-brackets  Filter out lines matching [text] and trailing blank lines
Examples:
  assertCommand git commit -m "message"
  session="`${ assertCommand --stderr --error "Failed to unlock" bw unlock --raw; }`"
  # For pipelines, use eval with a quoted string:
  assertCommand --stderr --error "Failed to encrypt" \
      eval 'tar cz "`${dir}`" | rage "`${recipients[@]}`" > "`${file}`"'

```bash
assertCommand() {
```

### appendVar

**Library:** `rayvn/core`

Append a value to an exported variable, space-separated.
Args: varName value
  varName - name of the variable to append to
  value   - value to append (prepended with a space if variable is non-empty)

```bash
appendVar() {
```

### setFileVar

**Library:** `rayvn/core`

Set a nameref variable to the realpath of a file, failing if the path is not a regular file.
Args: resultVar filePath description
  resultVar   - nameref variable to receive the resolved file path
  filePath    - path to the file (must exist and be a regular file)
  description - label used in error messages

```bash
setFileVar() {
```

### setDirVar

**Library:** `rayvn/core`

Set a nameref variable to the realpath of a directory, failing if the path is not a directory.
Args: resultVar dirPath description
  resultVar   - nameref variable to receive the resolved directory path
  dirPath     - path to the directory (must exist and be a directory)
  description - label used in error messages

```bash
setDirVar() {
```

### timeStamp

**Library:** `rayvn/core`

Return the current timestamp as a sortable string: YYYY-MM-DD_HH.MM.SS_TZ

```bash
timeStamp() {
```

### epochSeconds

**Library:** `rayvn/core`

Return the current epoch time with microsecond precision (from EPOCHREALTIME).

```bash
epochSeconds() {
```

### elapsedEpochSeconds

**Library:** `rayvn/core`

Return the elapsed seconds since a previously captured epoch time (6 decimal places).
Args: startTime
  startTime - start time value captured from `${EPOCHREALTIME}`

```bash
elapsedEpochSeconds() {
```

### secureEraseVars

**Library:** `rayvn/core`

Overwrite and unset one or more variables containing sensitive data.
Each variable's contents are overwritten with spaces before being unset.
Args: varName [varName...]
  varName - name of a variable to securely erase; silently ignored if not defined

```bash
secureEraseVars() {
```

### openUrl

**Library:** `rayvn/core`

Open a URL in the default browser (macOS: open; Linux: xdg-open).
Args: url
  url - the URL to open

```bash
openUrl() {
```

### executeWithCleanVars

**Library:** `rayvn/core`

Execute a command with all rayvn-internal variables unset, simulating a clean environment.
Args: command [args...]
  command - command and arguments to execute in the clean environment

```bash
executeWithCleanVars() {
```

### show

**Library:** `rayvn/core`

Enhanced echo function supporting text color and styles in addition to standard echo
options (-n, -e, -E). Formats can appear at any argument position and affect the subsequent
arguments until another format occurs. Styles accumulate and persist (e.g., bold remains
bold across subsequent arguments), while colors replace previous colors. Use 'plain' to
reset all formatting. IMPORTANT: When transitioning from colored text to style-only text,
use 'plain' first to reset the color, then apply the style. See examples below.
Automatically resets formatting to plain after text to prevent color bleed.
USAGE:
  show [-neE] [[FORMAT [FORMAT]...] [TEXT]...]
Options:
  -n do not append a newline
  -e enable interpretation of backslash escapes (see help echo for list)
  -E explicitly suppress interpretation of backslash escapes
EXAMPLES:
  show blue "This is blue text"
  show bold red "Bold red text"
  show -n yellow "Yellow text with no newline"
  show success "Operation completed"
  show italic underline green "Italic underline green text"
  show "Plain text" italic bold blue "italic bold blue text" red "italic bold red" plain blue "blue text" # style continuation
  show italic IDX 62 "italic 256 color #62 text" plain red "plain red text" # style continuation
  show IDX 42 "Display 256 color #42"
  show RGB 52:208:88 "rgb 52 208 88 colored text"
  show "The answer is" bold 42 "not a color code" # numeric values display normally
  show "Line 1" nl "Line 2" # insert newline between text
  # IMPORTANT: Use 'plain' to reset colors BEFORE applying styles-only
  show cyan "colored text" plain dim "dim text (no color)"
  # Reset after combining color+style before continuing
  show bold green "Note" plain "Regular text continues here"
  # Transitioning between different color+style combinations
  show bold blue "heading" plain "text" italic "emphasis"
  # In command substitution (bash 5.3+)
  prompt "`${ show bold green "Proceed?" ;}`" yes no reply
COMMON PATTERNS:
  Applying color only:
    show blue "text"
  Applying style only:
    show bold "text"
  Combining color and style:
    show bold blue "text"
  Resetting after color/style combination:
    show bold green "styled" plain "back to normal"
  Transitioning from color to style-only (IMPORTANT):
    show cyan "colored" plain dim "dimmed, not colored"
    # NOT: show cyan "colored" dim "dimmed" - dim inherits cyan!
  Style continuation (styles persist):
    show italic "starts italic" blue "still italic, now blue"
  Color replacement (colors don't persist):
    show blue "blue" red "red (replaces blue)"
  In command substitution:
    message="`${ show bold "text" ;}`"
    stopSpinner spinnerId ": `${ show green "success" ;}`"
AVAILABLE FORMATS:
  Theme Colors (semantic):
    success, error, warning, info, accent, muted
  Text Styles:
    bold, dim, italic, underline, blink, reverse, strikethrough
  Basic Colors:
    black, red, green, yellow, blue, magenta, cyan, white
    bright-black, bright-red, bright-green, bright-yellow,
    bright-blue, bright-magenta, bright-cyan, bright-white
  256 Colors ('indexed' colors):
    IDX 0-255
  RGB Colors ('truecolor'):
    RGB 0-255:0-255:0-255
  Special:
    nl - inserts a newline character
  Reset:
    plain

```bash
show() {
```

### header

**Library:** `rayvn/core`

Print a styled section header with optional sub-text. An optional numeric index selects the color.
Args: [index] title [subtitle...]
  index    - optional 1-based color index from the header color list (default: 1)
  title    - header text (printed in uppercase bold)
  subtitle - optional additional lines printed below the header

```bash
header() {
```

### randomInteger

**Library:** `rayvn/core`

Set a variable to a random non-negative integer via nameref.
Args: resultVar [maxValue]
  resultVar - nameref variable to receive the result; accepts scalars, 'array[i]', or 'map[key]'
  maxValue  - optional upper bound (inclusive); if omitted, returns full 32-bit range 0..4294967295

```bash
randomInteger() {
```

### randomHexChar

**Library:** `rayvn/core`

Set a variable to a random hex character (0-9, a-f) via nameref.
Args: resultVar
  resultVar - nameref variable to receive a single hex character

```bash
randomHexChar() {
```

### replaceRandomHex

**Library:** `rayvn/core`

Replace every occurrence of a placeholder character in a string with random hex characters.
Args: replaceChar stringVar
  replaceChar - the character to replace (e.g. 'X')
  stringVar   - nameref variable containing the string to modify in-place

```bash
replaceRandomHex() {
```

### copyMap

**Library:** `rayvn/core`

Copy all key-value pairs from one associative array to another.
Args: srcVar destVar
  srcVar  - name of the source associative array
  destVar - name of the destination associative array (must already be declared as -A)

```bash
copyMap() {
```

### stripAnsi

**Library:** `rayvn/core`

Remove all ANSI escape sequences from a string and print the result.
Args: string
  string - the string to strip

```bash
stripAnsi() {
```

### containsAnsi

**Library:** `rayvn/core`

Return 0 if a string contains ANSI escape sequences, 1 otherwise.
Args: string
  string - the string to test

```bash
containsAnsi() {
```

### repeat

**Library:** `rayvn/core`

Repeat a string a given number of times and print the result (no trailing newline).
Args: str count
  str   - string to repeat
  count - number of times to repeat the string

```bash
repeat() {
```

### indexOf

**Library:** `rayvn/core`

Return the 0-based index of an item in an array, or -1 if not found.
Exits 0 if found, 1 if not found.
Args: item arrayVar
  item     - the value to search for
  arrayVar - name of the indexed array to search

```bash
indexOf() {
```

### isMemberOf

**Library:** `rayvn/core`

Return 0 if an item is a member of an array, 1 otherwise.
Args: item arrayVar
  item     - the value to search for
  arrayVar - name of the indexed array to search

```bash
isMemberOf() {
```

### maxArrayElementLength

**Library:** `rayvn/core`

Return the length of the longest string in an array (ANSI escape codes not stripped).
Args: arrayVar
  arrayVar - name of the indexed array to measure

```bash
maxArrayElementLength() {
```

### padString

**Library:** `rayvn/core`

Pad a string to a minimum width, stripping ANSI codes when measuring the visible length.
Args: string width [position]
  string   - the string to pad
  width    - minimum total visible character width
  position - where to add padding: 'after'/'left' (default), 'before'/'right', or 'center'

```bash
padString() {
```

### warn

**Library:** `rayvn/core`

Print a warning message to the terminal error stream with a warning prefix.
Args: message [args...]
  message - warning text; additional args are passed as extra `show()` arguments

```bash
warn() {
```

### error

**Library:** `rayvn/core`

Print an error message to the terminal error stream with an error prefix.
Args: message [args...]
  message - error text; additional args are passed as extra `show()` arguments

```bash
error() {
```

### invalidArgs

**Library:** `rayvn/core`

Fail with a stack trace. Shorthand for fail --trace when invalid arguments are passed.
Args: message [args...]
  message - error message describing the invalid arguments

```bash
invalidArgs() {
```

### fail

**Library:** `rayvn/core`

Print an error message (or stack trace in debug mode) and exit with status 1.
Args: [--trace] message [args...]
  --trace - force a stack trace even outside debug mode
  message - error message to display

```bash
fail() {
```

### redStream

**Library:** `rayvn/core`

Read lines from stdin and print each one in red to the terminal error stream.
Intended for use as a pipe consumer, e.g.: someCmd 2>&1 | redStream

```bash
redStream() {
```

### bye

**Library:** `rayvn/core`

Print an optional red message and exit with status 0. Used for clean but early exits.
Args: [message [args...]]
  message - optional message to display in red before exiting

```bash
bye() {
```

### stackTrace

**Library:** `rayvn/core`

Print a formatted call stack, optionally preceded by an error message.
Args: [message [args...]]
  message - optional error message to display before the stack trace

```bash
stackTrace() {
```

### setDebug

**Library:** `rayvn/core`

Enable debug mode, loading the rayvn/debug library and configuring debug output.
See rayvn/debug for full usage documentation.
Args: [tty path] [showOnExit] [clearLog] [noStatus]
  tty path   - 'tty <path>' sends debug output to a terminal device; '.' reads ~/.debug.tty
  showOnExit - 'showOnExit' dumps the debug log to the terminal on exit
  clearLog   - 'clearLog' clears the log file before writing
  noStatus   - 'noStatus' suppresses the initial debug status message

```bash
setDebug() {
```

### debug

**Library:** `rayvn/core`

Placeholder debug functions, replaced in `setDebug()`

```bash
debug() { :; }
```

### debugEnabled

**Library:** `rayvn/core`

```bash
debugEnabled() { return 0; }
```

### debugDir

**Library:** `rayvn/core`

```bash
debugDir() { :; }
```

### debugStatus

**Library:** `rayvn/core`

```bash
debugStatus() { echo 'debug disabled'; }
```

### debugBinary

**Library:** `rayvn/core`

```bash
debugBinary() { :; }
```

### debugVar

**Library:** `rayvn/core`

```bash
debugVar() { :; }
```

### debugVars

**Library:** `rayvn/core`

```bash
debugVars() { :; }
```

### debugVarIsSet

**Library:** `rayvn/core`

```bash
debugVarIsSet() { :; }
```

### debugVarIsNotSet

**Library:** `rayvn/core`

```bash
debugVarIsNotSet() { :; }
```

### debugFile

**Library:** `rayvn/core`

```bash
debugFile() { :; }
```

### debugJson

**Library:** `rayvn/core`

```bash
debugJson() { :; }
```

### debugStack

**Library:** `rayvn/core`

```bash
debugStack() { :; }
```

### debugTraceOn

**Library:** `rayvn/core`

```bash
debugTraceOn() { :; }
```

### debugTraceOff

**Library:** `rayvn/core`

```bash
debugTraceOff() { :; }
```

### debugEscapes

**Library:** `rayvn/core`

```bash
debugEscapes() { :; }
```

### debugEnvironment

**Library:** `rayvn/core`

```bash
debugEnvironment() { :; }
```

### debugFileDescriptors

**Library:** `rayvn/core`

```bash
debugFileDescriptors() { :; }
```

