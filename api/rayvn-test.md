---
layout: default
title: "rayvn/test"
parent: API Reference
nav_order: 19
---

# rayvn/test

Test assertions

## Assert Functions

### assertNotInFile()

Fail if a pattern is found in a file.


*Args*

| | |
|---|---|
| `match` *(string)* | Pattern to search for. |
| `file` *(string)* | Path to the file to search. |
{: .args-table}

### assertInFile()

Fail if a grep pattern is not found in a file.


*Args*

| | |
|---|---|
| `match` *(string)* | Pattern to search for. |
| `file` *(string)* | Path to the file to search. |
{: .args-table}

### assertEqual()

Fails with a message if two strings are not equal.


*Args*

| | |
|---|---|
| `expected` *(string)* | Expected value. |
| `actual` *(string)* | Actual value. |
| `message` *(string)* | Optional custom failure message. |
{: .args-table}

### assertEqualStripped()

Fail if expected does not equal actual after stripping ANSI escape codes from actual.


*Args*

| | |
|---|---|
| `expected` *(string)* | Expected plain-text value. |
| `actual` *(string)* | Value to compare; ANSI codes are stripped before comparison. |
| `msg` *(string)* | Optional failure message. |
{: .args-table}

### assertEqualEscapeCodes()

Assert two strings are equal, printing both with cat -v (escape codes visible) on failure.


*Args*

| | |
|---|---|
| `expected` *(string)* | Expected value (may contain escape codes). |
| `actual` *(string)* | Actual value to compare. |
| `msg` *(string)* | Failure message; defaults to "assertEqualEscapeCodes failed". |
{: .args-table}

### assertTrue()

Fail with msg if a command exits non-zero.


*Args*

| | |
|---|---|
| `msg` *(string)* | Failure message to display. |
| `@` | Command and arguments to execute. |
{: .args-table}

### assertFalse()

Fail with msg if a command exits zero.


*Args*

| | |
|---|---|
| `msg` *(string)* | Message to display on failure. |
| `cmd` *(string)* | Command and arguments to execute. |
{: .args-table}

### assertContains()

Fail if actual does not contain expected as a substring.


*Args*

| | |
|---|---|
| `expected` *(string)* | Substring that must be present in actual. |
| `actual` *(string)* | Value to search within. |
| `msg` *(string)* | Optional custom failure message. |
{: .args-table}

### assertInRange()

Fail if a numeric value is not within the inclusive range [min, max].


*Args*

| | |
|---|---|
| `value` *(int)* | Value to check. |
| `min` *(int)* | Minimum allowed value (inclusive). |
| `max` *(int)* | Maximum allowed value (inclusive). |
| `msg` *(string)* | Custom failure message. |
{: .args-table}

### assertEqualIgnoreCase()

Fail if two strings are not equal, ignoring case.

### assertNotInPath()

Fails if an executable is found in PATH.

### assertInPath()

Fail if an executable is not found in PATH, or optionally at an unexpected path.


*Args*

| | |
|---|---|
| `executable` *(string)* | Name of the command that must be in PATH. |
| `expectedPath` *(string)* | Expected path; checked against both the found path and its |
{: .args-table}

### assertFunctionIsNotDefined()

Fail if a function with the given name is currently defined.


*Args*

| | |
|---|---|
| `name` *(string)* | Name of the function that must not be defined. |
{: .args-table}

### assertVarIsNotDefined()

Fail if a variable with the given name is currently defined.


*Args*

| | |
|---|---|
| `name` *(string)* | Variable name that must not be defined. |
{: .args-table}

### assertFunctionIsDefined()

Fail if a function with the given name is not currently defined.


*Args*

| | |
|---|---|
| `name` *(string)* | Name of the function that must be defined. |
{: .args-table}

### assertVarIsDefined()

Fail if a variable with the given name is not currently defined.


*Args*

| | |
|---|---|
| `name` *(string)* | Name of the variable to check. |
{: .args-table}

### assertVarType()

Fail if a variable's declare flags do not match the expected set (order-independent).


*Args*

| | |
|---|---|
| `varName` *(stringRef)* | Name of the variable to inspect. |
| `expectedFlags` *(string)* | Expected declare flags as a string (e.g. "ir", "r", "arx", "A"). |
{: .args-table}

### assertVarEquals()

Fail if a named variable's value does not equal the expected string.


*Args*

| | |
|---|---|
| `varName` *(stringRef)* | The name of the variable to check. |
| `expected` *(string)* | The expected string value. |
{: .args-table}

### assertVarContains()

Fail if the variable named varName does not contain expected as a substring.


*Args*

| | |
|---|---|
| `varName` *(stringRef)* | Name of the variable to check. |
| `expected` *(string)* | Substring that must be present in the variable's value. |
{: .args-table}

### assertArrayEquals()

Fail if an indexed array's contents do not exactly match the expected values.


*Args*

| | |
|---|---|
| `varName` *(arrayRef)* | Name of the indexed array variable to check. |
| `expected` *(string)* | Remaining args are the expected element values in order. |
{: .args-table}

### assertHashTableIsDefined()

Fail if a variable is not defined as an associative array (hash table).


*Args*

| | |
|---|---|
| `varName` | (mapRef)  Name of the variable that must be a defined associative array. |
{: .args-table}

### assertHashTableIsNotDefined()

Fail if an associative array variable is currently defined.


*Args*

| | |
|---|---|
| `varName` | (mapRef)  Name of the variable that must not be defined. |
{: .args-table}

### assertHashKeyIsDefined()

Fail if a key is not present in an associative array.


*Args*

| | |
|---|---|
| `varName` | (mapRef)  Name of the associative array variable. |
| `keyName` *(string)* | Key that must be defined in the array. |
{: .args-table}

### assertHashKeyIsNotDefined()

Fail if a key is present in an associative array.


*Args*

| | |
|---|---|
| `varName` | (mapRef)  Name of the associative array variable. |
| `keyName` *(string)* | Key that must NOT be defined in the array. |
{: .args-table}

### assertHashValue()

Fail if the value at a key in an associative array does not equal the expected value.


*Args*

| | |
|---|---|
| `varName` | (mapRef)        Name of the associative array variable. |
| `keyName` *(string)* | Key to look up. |
| `expectedValue` *(string)* | Expected value at that key. |
{: .args-table}

## Path Functions

### printPath()

Prepend a directory to a PATH-style variable, removing any existing occurrence first.

Append a directory to a PATH-style variable, removing any existing occurrence first.

*Args*

| | |
|---|---|
| `path` *(string)* | Name of the directory to prepend. |
| `pathVariable` *(string)* | Name of the colon-separated path variable (default: PATH). |
{: .args-table}
Remove all occurrences of a directory from a colon-separated path variable.

*Args*

| | |
|---|---|
| `path` *(string)* | Name of directory to append. |
| `pathVariable` *(string)* | Name of the colon-separated path variable (default: PATH). |
{: .args-table}
Print a PATH-style variable with each directory on its own numbered line.

*Args*

| | |
|---|---|
| `removePath` *(string)* | Directory path to remove. |
| `pathVariable` *(string)* | Name of the path variable to modify (default: PATH). [R/W] |
{: .args-table}

*Args*

| | |
|---|---|
| `pathVariable` *(string)* | Name of the colon-separated path variable to display (default: PATH). |
{: .args-table}

### addRayvnProject()

Register a rayvn project by name and root directory, resolving symlinks via realpath.


*Args*

| | |
|---|---|
| `projectName` *(string)* | Name to register the project under. |
| `projectRoot` *(string)* | Path to the project root directory (resolved to real path). |
{: .args-table}

*Returns*

| | |
|---|---|
| `0` | project successfully registered |
| `1` | project already registered with the same root (no-op) |
{: .args-table}

### removeRayvnProject()

Unregister a project previously added with `addRayvnProject()`.


*Args*

| | |
|---|---|
| `projectName` *(string)* | Name of the project to remove. |
{: .args-table}

### requireAndAssertFailureContains()

Require a library and assert the failure message contains an expected substring.


*Args*

| | |
|---|---|
| `library` *(string)* | Path to require (e.g. 'rayvn/core'). |
| `expected` *(string)* | Substring that must appear in the captured failure message. |
{: .args-table}

### benchmark()

Run a function N times and print timing results including ops/sec.


*Args*

| | |
|---|---|
| `functionName` *(string)* | Name of the function to benchmark. |
| `iterations` *(int)* | Number of times to call the function. |
| `testCase` *(string)* | Label printed in the results line. |
| `[...]` *(string)* | Optional arguments passed to the function on each invocation. |
{: .args-table}

## Tty Capture Functions

### startTtyCapture()

Begin capturing terminal UI output to a temp file. Access captured output via
`getTtyOutput()` or `getTtyText()`. Pair with `stopTtyCapture()` to restore.

### stopTtyCapture()

Stop capturing and restore terminal UI output to the original terminal device.

### clearTtyCapture()

Clear the tty capture file content without stopping capture.

### getTtyOutput()

Return raw tty capture content including all ANSI escape sequences.

### getTtyText()

Return tty capture content with all ANSI escape sequences stripped.

### assertTtyRawContains()

Fail if raw (ANSI-encoded) tty capture content does not contain expected as a substring.
Use this to assert on escape sequences directly. Use assertTtyContains for visible text.


*Args*

| | |
|---|---|
| `expected` *(string)* | Substring that must be present in raw tty output (e.g. $'\e[?25l'). |
| `msg` *(string)* | Optional failure message. |
{: .args-table}

### assertTtyContains()

Fail if captured tty text does not contain expected as a substring.


*Args*

| | |
|---|---|
| `expected` *(string)* | Substring that must be present in tty output. |
| `msg` *(string)* | Optional failure message. |
{: .args-table}

### assertTtyNotContains()

Fail if captured tty text contains expected as a substring.


*Args*

| | |
|---|---|
| `expected` *(string)* | Substring that must NOT be present in tty output. |
| `msg` *(string)* | Optional failure message. |
{: .args-table}

## Input Simulation Functions

### startInputSimulation()

Begin simulating user input from a string. Redirects stdinFd to a temp file
containing the given input so prompt functions read from it instead of the
terminal. Pair with `stopInputSimulation()` to restore.


*Args*

| | |
|---|---|
| `input` *(string)* | The simulated input (e.g. "y" for a confirm, "2" for a choice). |
{: .args-table}

### stopInputSimulation()

Stop simulating user input and restore stdinFd to the real stdin.

