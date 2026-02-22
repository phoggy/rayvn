---
layout: default
title: "rayvn/test"
parent: API Reference
nav_order: 13
---

# rayvn/test

## Functions

### assertNotInFile

**Library:** `rayvn/test`

shellcheck disable=SC2155
Test case support library.
Intended for use via: require 'rayvn/test'
Fail if a pattern is found in a file.
Args: match file
  match - grep pattern that must NOT be present
  file  - path to the file to search

```bash
assertNotInFile() {
```

### assertInFile

**Library:** `rayvn/test`

Fail if a pattern is not found in a file.
Args: match file
  match - grep pattern that must be present
  file  - path to the file to search

```bash
assertInFile() {
```

### assertEqual

**Library:** `rayvn/test`

Fail if two values are not equal (string comparison).
Args: expected actual [message]
  expected - expected value
  actual   - actual value to compare
  message  - optional custom failure message

```bash
assertEqual() {
```

### assertEqualStripped

**Library:** `rayvn/test`

Fail if expected does not equal actual after stripping ANSI escape codes from actual.
Args: expected actual [message]
  expected - expected plain-text value
  actual   - actual value (may contain ANSI codes; they are stripped before comparison)
  message  - optional custom failure message

```bash
assertEqualStripped() {
```

### assertEqualEscapeCodes

**Library:** `rayvn/test`

Fail if expected does not equal actual; on failure, shows both values with cat -v escapes visible.
Args: expected actual [message]
  expected - expected value (may contain escape codes)
  actual   - actual value to compare
  message  - optional custom failure message

```bash
assertEqualEscapeCodes() {
```

### assertTrue

**Library:** `rayvn/test`

Fail with a message if a command exits non-zero.
Args: message command [args...]
  message - failure message to display
  command - command and arguments to execute

```bash
assertTrue() {
```

### assertFalse

**Library:** `rayvn/test`

Fail with a message if a command exits zero.
Args: message command [args...]
  message - failure message to display
  command - command and arguments to execute

```bash
assertFalse() {
```

### assertContains

**Library:** `rayvn/test`

Fail if actual does not contain expected as a substring.
Args: expected actual [message]
  expected - substring that must be present in actual
  actual   - value to search within
  message  - optional custom failure message

```bash
assertContains() {
```

### assertInRange

**Library:** `rayvn/test`

Fail if a numeric value is not within an inclusive range.
Args: value min max [message]
  value   - numeric value to check
  min     - minimum allowed value (inclusive)
  max     - maximum allowed value (inclusive)
  message - optional custom failure message

```bash
assertInRange() {
```

### assertEqualIgnoreCase

**Library:** `rayvn/test`

Fail if two values are not equal (case-insensitive comparison).
Args: expected actual [message]
  expected - expected value (compared case-insensitively)
  actual   - actual value to compare
  message  - optional custom failure message

```bash
assertEqualIgnoreCase() {
```

### assertNotInPath

**Library:** `rayvn/test`

Fail if an executable is found in PATH.
Args: executable
  executable - name of the command that must NOT be in PATH

```bash
assertNotInPath() {
```

### assertInPath

**Library:** `rayvn/test`

Fail if an executable is not found in PATH, or if found at an unexpected path.
Args: executable [expectedPath]
  executable   - name of the command that must be in PATH
  expectedPath - optional expected resolved path (symlinks followed)

```bash
assertInPath() {
```

### assertFunctionIsNotDefined

**Library:** `rayvn/test`

Fail if a function with the given name is currently defined.
Args: name
  name - function name that must NOT be defined

```bash
assertFunctionIsNotDefined() {
```

### assertVarIsNotDefined

**Library:** `rayvn/test`

Fail if a variable with the given name is currently defined.
Args: name
  name - variable name that must NOT be defined

```bash
assertVarIsNotDefined() {
```

### assertFunctionIsDefined

**Library:** `rayvn/test`

Fail if a function with the given name is not currently defined.
Args: name
  name - function name that must be defined

```bash
assertFunctionIsDefined() {
```

### assertVarIsDefined

**Library:** `rayvn/test`

Fail if a variable with the given name is not currently defined.
Args: name
  name - variable name that must be defined

```bash
assertVarIsDefined() {
```

### assertVarType

**Library:** `rayvn/test`

Fail if a variable's declare flags do not match the expected set (order-independent).
Args: varName expectedFlags
  varName       - name of the variable to inspect
  expectedFlags - expected declare flags as a string (e.g. "ir", "r", "arx", "A")

```bash
assertVarType() {
```

### assertVarEquals

**Library:** `rayvn/test`

Fail if a variable's value does not equal the expected string.
Args: varName expected
  varName  - name of the variable to check
  expected - expected string value

```bash
assertVarEquals() {
```

### assertVarContains

**Library:** `rayvn/test`

Fail if a variable's value does not contain the expected substring.
Args: varName expected
  varName  - name of the variable to check
  expected - substring that must be present in the variable's value

```bash
assertVarContains() {
```

### assertArrayEquals

**Library:** `rayvn/test`

Fail if an indexed array's elements do not exactly match the expected values.
Args: varName [element...]
  varName  - name of the indexed array variable to check
  element  - zero or more expected element values in order

```bash
assertArrayEquals() {
```

### assertHashTableIsDefined

**Library:** `rayvn/test`

Fail if a variable is not defined as an associative array (hash table).
Args: varName
  varName - name of the variable that must be a defined associative array

```bash
assertHashTableIsDefined() {
```

### assertHashTableIsNotDefined

**Library:** `rayvn/test`

Fail if an associative array variable is currently defined.
Args: varName
  varName - name of the variable that must NOT be defined

```bash
assertHashTableIsNotDefined() {
```

### assertHashKeyIsDefined

**Library:** `rayvn/test`

Fail if a key is not present in an associative array.
Args: varName keyName
  varName - name of the associative array variable
  keyName - key that must be defined in the array

```bash
assertHashKeyIsDefined() {
```

### assertHashKeyIsNotDefined

**Library:** `rayvn/test`

Fail if a key is present in an associative array.
Args: varName keyName
  varName - name of the associative array variable
  keyName - key that must NOT be defined in the array

```bash
assertHashKeyIsNotDefined() {
```

### assertHashValue

**Library:** `rayvn/test`

Fail if the value at a key in an associative array does not equal the expected value.
Args: varName keyName expectedValue
  varName       - name of the associative array variable
  keyName       - key to look up
  expectedValue - expected value for that key

```bash
assertHashValue() {
```

### printPath

**Library:** `rayvn/test`

Prepend a directory to a PATH-style variable, removing any existing occurrence first.
Args: path [pathVariable]
  path         - directory to prepend
  pathVariable - name of the colon-separated path variable (default: PATH)
Append a directory to a PATH-style variable, removing any existing occurrence first.
Args: path [pathVariable]
  path         - directory to append
  pathVariable - name of the colon-separated path variable (default: PATH)
Remove all occurrences of a directory from a PATH-style variable.
Args: path [pathVariable]
  path         - directory to remove
  pathVariable - name of the colon-separated path variable (default: PATH)
Print a PATH-style variable with each directory on its own numbered line.
Args: [pathVariable]
  pathVariable - name of the colon-separated path variable to display (default: PATH)

```bash
printPath() {
```

### addRayvnProject

**Library:** `rayvn/test`

Register a rayvn project root for use in tests, resolving symlinks and verifying the directory.
Returns 1 if the project is already registered with the same root; fails if registered with a different root.
Args: projectName projectRoot
  projectName - short name for the project (e.g. 'valt')
  projectRoot - absolute or relative path to the project's root directory

```bash
addRayvnProject() {
```

### removeRayvnProject

**Library:** `rayvn/test`

Unregister a previously added rayvn project, removing its project and library root entries.
Args: projectName
  projectName - short name of the project to remove (e.g. 'valt')

```bash
removeRayvnProject() {
```

### requireAndAssertFailureContains

**Library:** `rayvn/test`

Require a library and assert that the require failure message contains an expected substring.
Useful for testing libraries that are expected to fail on load.
Args: library expected
  library  - library path to require (e.g. 'rayvn/core')
  expected - substring that must appear in the captured failure message

```bash
requireAndAssertFailureContains() {
```

### benchmark

**Library:** `rayvn/test`

Run a function a given number of times and print timing results including ops/sec.
Args: functionName iterations testCase [args...]
  functionName - name of the function to benchmark
  iterations   - number of times to call the function
  testCase     - label printed in the results line
  args         - optional arguments passed to the function on each invocation

```bash
benchmark() {
```

