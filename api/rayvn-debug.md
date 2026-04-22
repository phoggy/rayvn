---
layout: default
title: "rayvn/debug"
parent: API Reference
nav_order: 5
---

# rayvn/debug

Debug logging and tracing.

## Functions

### isDebugEnabled()

Return 0 if debug mode is enabled, non-zero otherwise.

### debug()

Log args. No-op if debug is not enabled.

### debugDir()

Log the debug output directory path to debug output. No-op if debug is not enabled.

### debugBinary()

Log a binary string as hex bytes. No-op if debug is not enabled.


*Args*

| | |
|---|---|
| `label` *(string)* | Label logged before the hex bytes. |
| `binary` *(string)* | Binary string to display as hex. |
{: .args-table}

### debugVar()

Log variable declaration(s). Convenience alias for debugVars. No-op if debug is not enabled.

### debugVars()

Log declarations of one or more variables. No-op if debug is not enabled.


*Args*

| | |
|---|---|
| `varName` *(stringRef)* | Name of a variable to inspect; outputs "not defined" if undefined. |
{: .args-table}

### debugVarIsSet()

Assert and log that a variable is set, logging a stack trace if not. No-op if debug is not enabled.


*Args*

| | |
|---|---|
| `varName` *(stringRef)* | Name of the variable expected to be set. |
| `prefix` *(string)* | Optional label prepended to the assertion message. |
{: .args-table}

### debugVarIsNotSet()

Assert and log that a variable is not set, logging a stack trace if it is. No-op if debug is not enabled.


*Args*

| | |
|---|---|
| `var` *(stringRef)* | Name of the variable expected to be unset. |
| `prefix` *(string)* | Optional label prepended to the assertion message. |
{: .args-table}

### debugFile()

Copy a file into the debug directory.


*Args*

| | |
|---|---|
| `sourceFile` *(string)* | Path to the source file. |
| `fileName` *(string)* | Optional filename (default: basename of sourceFile). |
{: .args-table}

### debugJson()

Write a variable's JSON content as a file in the debug directory. No-op if debug is not enabled.


*Args*

| | |
|---|---|
| `jsonRef` *(stringRef)* | Name of the variable holding the JSON string. |
| `fileName` *(string)* | Base name for the output file. |
{: .args-table}

### debugStack()

Log a stack trace if enabled, with an optional message to log first. No-op if debug is not enabled.

### debugTraceOn()

Enable bash xtrace (set -x), directing output to the debug stream, with an optional message to log first.

### debugTraceOff()

Disable bash xtrace (set +x) previously enabled by debugTraceOn, optionally logging a message afterward.
No-op if debug is not enabled.

### debugEscapes()

Log each argument shell-quoted via 'printf %q'. No-op if debug is not enabled.

### debugEnvironment()

Log the full process environment (variables and functions) to '<name>.env' in the debug directory.
No-op if debug is not enabled.


*Args*

| | |
|---|---|
| `name` *(string)* | Base name for the output file. |
{: .args-table}

### debugFileDescriptors()

Log the open/closed status and mode of one or more file descriptors. No-op if debug is not enabled.


*Args*

| | |
|---|---|
| `fd` | | string  Numeric fd or nameref variable holding an fd; repeatable. |
{: .args-table}

