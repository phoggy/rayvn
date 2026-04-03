---
layout: default
title: "rayvn/typist"
parent: API Reference
nav_order: 21
---

# rayvn/typist

Jitter model (log-normal distribution approximation):
  - Most keystrokes cluster near the base interval
  - Occasional slower keystrokes (hesitation, harder keys)
  - Rare fast bursts (familiar words/patterns)

## Functions

### typist()

Type TEXT in realtime on the terminal at WPM words per minute with human-like jitter.


*Args*

| | |
|---|---|
| `wpm` *(int)* | Typing speed in words per minute. |
| `text` *(string)* | The text to type. |
{: .args-table}

*Example*

```bash
typist 120 "The quick brown fox jumps over the lazy dog."
```

### typistDelays()

Collect simulated typing delays, in seconds.


*Args*

| | |
|---|---|
| `wpm` *(int)* | Typing speed in words per minute. |
| `text` *(string)* | The text to simulate typing for. |
| `resultArrayVar` *(arrayRef)* | The result array var name. |
{: .args-table}

