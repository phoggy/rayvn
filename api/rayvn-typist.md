---
layout: default
title: "rayvn/typist"
parent: "Project Tooling"
grand_parent: API Reference
nav_order: 20
---

# rayvn/typist

Typing jitter model (log-normal distribution approximation).

## Functions

### typist()

Type TEXT in realtime on the terminal at WPM words per minute with human-like jitter.


*args*

| | |
|---|---|
| `wpm` *(int)* | Typing speed in words per minute. |
| `text` *(string)* | The text to type. |
{: .args-table}

*example*

```bash
typist 120 "The quick brown fox jumps over the lazy dog."
```

### typistDelays()

Collect simulated typing delays, in seconds.


*args*

| | |
|---|---|
| `wpm` *(int)* | Typing speed in words per minute. |
| `text` *(string)* | The text to simulate typing for. |
| `resultArrayVar` *(arrayRef)* | The result array var name. |
{: .args-table}

