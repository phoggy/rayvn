---
layout: default
title: "rayvn/debug"
parent: API Reference
nav_order: 4
---

# rayvn/debug

## Functions

### debug

**Library:** `rayvn/debug`

Library supporting debug logging.
Intended for use via: require 'rayvn/debug'
IMPORTANT!
Each of the following public functions MUST have a corresponding NO-OP declaration
within core. If you add a new function here:
   1. add it to the list in _init_rayvn_debug below
   2. add a NO-OP function at the bottom of core.sh
   3. add it to _rayvnFunctionSources in rayvn.up
Write a message to debug output if debug mode is enabled. No-op otherwise.
Args: message [args...]
  message - text to write; additional args are appended space-separated

```bash
debug() {
```

### debugEnabled

**Library:** `rayvn/debug`

Return 0 if debug mode is currently enabled, 1 otherwise.

```bash
debugEnabled() {
```

### debugDir

**Library:** `rayvn/debug`

Write the path to the debug output directory to debug output if debug mode is enabled.

```bash
debugDir() {
```

### debugStatus

**Library:** `rayvn/debug`

Print the current debug configuration (log file path or output target) if debug is enabled.

```bash
debugStatus() {
```

### debugBinary

**Library:** `rayvn/debug`

Write a binary string as hex bytes to debug output if debug mode is enabled.
Args: prompt binary
  prompt - label printed before the hex bytes
  binary - the binary string to display as hex

```bash
debugBinary() {
```

### debugVar

**Library:** `rayvn/debug`

Write the declaration of a single variable to debug output if debug mode is enabled.
Args: varName
  varName - name of the variable to inspect

```bash
debugVar() {
```

### debugVars

**Library:** `rayvn/debug`

Write the declarations of one or more variables to debug output if debug mode is enabled.
Args: varName [varName...]
  varName - name of a variable to inspect; reports "not defined" if undefined

```bash
debugVars() {
```

### debugVarIsSet

**Library:** `rayvn/debug`

Assert and log that a variable is set; prints a stack trace to debug output if it is not.
Args: varName [prefix]
  varName - name of the variable expected to be set
  prefix  - optional label to prepend to the assertion message

```bash
debugVarIsSet() {
```

### debugVarIsNotSet

**Library:** `rayvn/debug`

Assert and log that a variable is NOT set; prints a stack trace to debug output if it is.
Args: varName [prefix]
  varName - name of the variable expected to be unset
  prefix  - optional label to prepend to the assertion message

```bash
debugVarIsNotSet() {
```

### debugFile

**Library:** `rayvn/debug`

Copy a file into the debug directory for inspection, if debug mode is enabled.
Args: sourceFile [fileName]
  sourceFile - path to the file to copy
  fileName   - optional name for the copy in the debug directory (default: basename of sourceFile)

```bash
debugFile() {
```

### debugJson

**Library:** `rayvn/debug`

Write the contents of a variable as a JSON file in the debug directory, if debug is enabled.
Args: jsonVar fileName
  jsonVar  - name of the variable holding the JSON content
  fileName - base name for the output file (written as fileName.json in the debug directory)

```bash
debugJson() {
```

### debugStack

**Library:** `rayvn/debug`

Write a stack trace to debug output if debug mode is enabled.
Args: [message [args...]]
  message - optional message to include before the stack trace

```bash
debugStack() {
```

### debugTraceOn

**Library:** `rayvn/debug`

Enable bash xtrace (set -x) with output directed to debug output.
Args: [message [args...]]
  message - optional message to log before enabling the trace

```bash
debugTraceOn() {
```

### debugTraceOff

**Library:** `rayvn/debug`

Disable bash xtrace (set +x) previously enabled by debugTraceOn.
Args: [message [args...]]
  message - optional message to log after disabling the trace

```bash
debugTraceOff() {
```

### debugEscapes

**Library:** `rayvn/debug`

Print each argument in its shell-quoted (printf %q) form to debug output if debug is enabled.
Args: value [value...]
  value - one or more values to print in quoted form

```bash
debugEscapes() {
```

### debugEnvironment

**Library:** `rayvn/debug`

Write the complete process environment (variables and functions) to a file in the debug directory.
Args: fileName
  fileName - base name for the output file (written as fileName.env in the debug directory)

```bash
debugEnvironment() {
```

### debugFileDescriptors

**Library:** `rayvn/debug`

Log the open/closed status and mode of one or more file descriptors to debug output.
Args: fdVar [fdVar...]
  fdVar - either a numeric fd number, or the name of a variable that holds an fd number

```bash
debugFileDescriptors() {
```

