---
layout: default
title: "rayvn/snapshot"
parent: API Reference
nav_order: 15
---

# rayvn/snapshot

  depth = hops from current PID up to (but not including) the root bash
  label = user defined label
  Fields separated by __ allow lexical sort by time, then tree traversal
  Parent linkage in filename enables upward/downward tree walk without dirs

## Functions

### snapshot()

Take a snapshot.


*Args*

| | |
|---|---|
| `label` *(string)* | Optional snapshot label |
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

