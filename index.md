---
layout: home
title: Home
nav_order: 1
---

# rayvn

A shared library framework for bash 5.3+.

## First Look

A minimal rayvn script:

```bash
#!/usr/bin/env rayvn-bash

usage() {
    show "Usage:" bold "greet" italic "NAME"
    bye "$@"
}

main() {
    init "$@"
    show primary "Hey ${name}!"
}

init() {
    declare -g name
    while (( $# )); do
        case "$1" in
            -h | --help) usage ;;
            -* | --*) usage "unknown option: $1" ;;
            *) name="${1^}" ;;
        esac
        shift
    done
    [[ -n ${name} ]] || usage "NAME is required"
}

source rayvn.up
main "$@"
```

- `#!/usr/bin/env rayvn-bash` ensures bash 5.3+ if available, regardless of system defaults.
- `source rayvn.up` bootstraps rayvn and loads the [rayvn/core](/rayvn/api/rayvn-core) library automatically.
- The `show` function is in [rayvn/core](/rayvn/api/rayvn-core) and supports colored/styled text output.
- All functions are defined before `source rayvn.up` so the file is fully parsed before `main` runs.
- Pass library names to load additional libraries: `source rayvn.up 'rayvn/spinner' 'rayvn/prompt'`.

For installation, IDE setup, and development guidance, see the [README](https://github.com/phoggy/rayvn#readme).

## Libraries

### Scripting

| Library | Description |
|---|---|
| [rayvn/core](/rayvn/api/rayvn-core) | Core utilities, assertions and error handling. |
| [rayvn/debug](/rayvn/api/rayvn-debug) | Debug logging and tracing. |
| [rayvn/prompt](/rayvn/api/rayvn-prompt) | Interactive user prompts. |
| [rayvn/terminal](/rayvn/api/rayvn-terminal) | Cursor control and terminal output. |
| [rayvn/spinner](/rayvn/api/rayvn-spinner) | Terminal spinners. |
| [rayvn/secrets](/rayvn/api/rayvn-secrets) | System keychain credential storage. |
| [rayvn/oauth](/rayvn/api/rayvn-oauth) | OAuth authorization code flow. |
| [rayvn/theme](/rayvn/api/rayvn-theme) | Color themes. |
| [rayvn/config](/rayvn/api/rayvn-config) | Configuration file support. |
| [rayvn/process](/rayvn/api/rayvn-process) | Process management. |

### Testing

| Library | Description |
|---|---|
| [rayvn/test](/rayvn/api/rayvn-test) | Test assertions. |
| [rayvn/test-harness](/rayvn/api/rayvn-test-harness) | Test runner. |

### Project Tooling

| Library | Description |
|---|---|
| [rayvn/release](/rayvn/api/rayvn-release) | GitHub release workflow. |
| [rayvn/central](/rayvn/api/rayvn-central) | Project registry. |
| [rayvn/dependencies](/rayvn/api/rayvn-dependencies) | Dependency checking and Homebrew formula generation. |
| [rayvn/function-docs](/rayvn/api/rayvn-function-docs) | Audit and update function doc comments. |
| [rayvn/index](/rayvn/api/rayvn-index) | Generate function indexes for AI agent use. |
| [rayvn/lint](/rayvn/api/rayvn-lint) | Bash requirement linting. |
| [rayvn/asciinema](/rayvn/api/rayvn-asciinema) | Asciinema cast recording and post-processing. |
| [rayvn/typist](/rayvn/api/rayvn-typist) | Typing jitter model (log-normal distribution approximation). |
| [rayvn/namespace](/rayvn/api/rayvn-namespace) | Detect namespace collisions across registered rayvn project libraries. |

## Related Projects

- valt — encrypted file archives using age *(renovating, coming soon)*
- wardn — encrypted Bitwarden vault backups *(renovating, coming soon)*
