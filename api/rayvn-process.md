---
layout: default
title: "rayvn/process"
parent: API Reference
nav_order: 6
---

# rayvn/process

## Functions

### waitForProcessExit

**Library:** `rayvn/process`

Wait for a process to exit, sending TERM then KILL signals if needed. Returns 0 on success.
Args: pid timeoutMs [checkIntervalMs] [termWaitMs]
  pid             - process ID to wait for
  timeoutMs       - maximum wait time in milliseconds before returning failure (1)
  checkIntervalMs - polling interval in milliseconds (default: 10)
  termWaitMs      - milliseconds after first check before sending SIGTERM (default: 1000)
If process has not exited on its own after waiting one check interval, a TERM signal is
sent if timeout has not expired. After termWaitMs, a KILL signal is sent if timeout has
not expired. Waiting will then continue until timeout expires.

```bash
waitForProcessExit() {
```

