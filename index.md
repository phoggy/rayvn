---
layout: home
title: Home
nav_order: 1
---

# rayvn

A shared library framework for bash 5.3+.

rayvn lets bash programs use shared libraries — both built-in and from third-party projects — using a simple `require` system. It also provides the `rayvn` CLI for generating and testing projects, etc.

## Getting Started

See the [README](https://github.com/phoggy/rayvn#readme) for a quick introduction, installation instructions and development setup.

## Libraries

| Library | Description                                                            |
|---|------------------------------------------------------------------------|
| [rayvn/core](/rayvn/api/rayvn-core) | Core utilities, assertions, and error handling.                        |
| [rayvn/debug](/rayvn/api/rayvn-debug) | Debug logging and tracing.                                             |
| [rayvn/terminal](/rayvn/api/rayvn-terminal) | Cursor control and terminal output.                                    |
| [rayvn/prompt](/rayvn/api/rayvn-prompt) | Interactive user prompts.                                              |
| [rayvn/secrets](/rayvn/api/rayvn-secrets) | System keychain credential storage.                                    |
| [rayvn/oauth](/rayvn/api/rayvn-oauth) | OAuth authorization code flow.                                         |
| [rayvn/spinner](/rayvn/api/rayvn-spinner) | Terminal spinners.                                                     |
| [rayvn/theme](/rayvn/api/rayvn-theme) | Color themes.                                                          |
| [rayvn/config](/rayvn/api/rayvn-config) | Configuration file support.                                            |
| [rayvn/process](/rayvn/api/rayvn-process) | Process management.                                                    |
| [rayvn/release](/rayvn/api/rayvn-release) | GitHub release workflow.                                               |
| [rayvn/test](/rayvn/api/rayvn-test) | Test assertions.                                                       |
| [rayvn/test-harness](/rayvn/api/rayvn-test-harness) | Test runner.                                                           |
| [rayvn/central](/rayvn/api/rayvn-central) | Project registry.                                                      |
| [rayvn/dependencies](/rayvn/api/rayvn-dependencies) | Dependency checking and Homebrew formula generation.                   |
| [rayvn/function-docs](/rayvn/api/rayvn-function-docs) | Audit and update function doc comments.                                |
| [rayvn/index](/rayvn/api/rayvn-index) | Generate function indexes for AI agent use.                            |
| [rayvn/node](/rayvn/api/rayvn-node) | Node.js / npm utilities.                                               |
| [rayvn/lint](/rayvn/api/rayvn-lint) | Bash requirement linting.                                              |
| [rayvn/asciinema](/rayvn/api/rayvn-asciinema) | Asciinema cast recording and post-processing.                          |
| [rayvn/typist](/rayvn/api/rayvn-typist) | Typing jitter model (log-normal distribution approximation).           |
| [rayvn/namespace](/rayvn/api/rayvn-namespace) | Detect namespace collisions across registered rayvn project libraries. |

## Related Projects

- [valt](/valt) — encrypted file archives using age
- [wardn](/wardn) — encrypted Bitwarden vault backups
