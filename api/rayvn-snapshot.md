---
layout: default
title: "rayvn/snapshot"
parent: API Reference
nav_order: 15
---

# rayvn/snapshot

depth = hops from current PID up to (but not including) the root bash

## Functions

### snapshot()

Take a snapshot.


*Args*

| | |
|---|---|
| `label` *(string)* | Optional snapshot label. |
| `resultVar` *(stringRef)* | Optional var name to receive the snapshot path. |
{: .args-table}

### snapshotInstallHandler()

Install (or reinstall) a trap handler that will take a snapshot.


*Args*

| | |
|---|---|
| `signal` *(string)* | Optional signal to install (default: USR1) |
{: .args-table}

### snapshotRemoveHandler()

Remove the snapshot trap (restore to default signal disposition).


*Args*

| | |
|---|---|
| `signal` *(string)* | Optional signal to remove (default: USR1) |
{: .args-table}

