---
layout: default
title: "rayvn/process"
parent: API Reference
nav_order: 11
---

# rayvn/process

Process management.

## Functions

### waitForProcessExit()

Wait for a process to exit, escalating SIGTERM then SIGKILL if needed.


*args*

| | |
|---|---|
| `pid` *(int)* | Process ID to wait for. |
| `timeoutMs` *(int)* | Maximum wait time in milliseconds before returning failure. |
| `checkIntervalMs` *(int)* | Polling interval in milliseconds (default: 10). |
| `termWaitMs` *(int)* | Milliseconds after first check before sending SIGKILL (default: 1000). |
{: .args-table}

*notes*


SIGTERM is sent after the first check interval if the process is still running.
SIGKILL is sent once termWaitMs has elapsed. Polling continues until timeoutMs
is reached regardless of which signals have been sent.


*returns*

| | |
|---|---|
| `0` | process exited |
| `1` | timeout expired |
{: .args-table}

