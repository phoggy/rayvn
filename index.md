---
layout: home
title: Home
nav_order: 1
---

# rayvn

rayvn lets you create and maintain bash 5.3+ programs the way you would in other languages:

- use shared libraries, loaded with one line: built-in, your own or from other projects
- create projects, scripts, libraries and tests from templates
- run tests and lint
- generate docs and web sites
- release to GitHub, Homebrew and Nix

bash is everywhere, stable and small, and has been maintained and improved for decades; rayvn adds what larger
programs need, and makes it easy to write polished, high-quality ones, with:

- styled output with color themes
- interactive prompts and spinners
- generated argument parsing, with usage and shell completions
- configuration files
- keychain secrets and OAuth
- secure (RAM-backed) temporary files
- error handling and debug tracing

## First Look

A simple rayvn script:

```bash
#!/usr/bin/env rayvn-bash

usage() {
    show "Usage:" bold blue "${scriptName}" italic "[NAME]"
    bye "$@"
}

main() {
    init "$@"
    show primary "Hey ${name^}!"
}

init() {
    declare -g name
    while (( $# )); do
        case "$1" in
            -h | --help) usage ;;
            -* | --*) usage "unknown option: $1" ;;
            *) name="$1" ;;
        esac
        shift
    done
    [[ -n ${name} ]] || request "What's your name?" name || bye
}

source rayvn.up 'rayvn/prompt'
main "$@"
```

- `#!/usr/bin/env rayvn-bash` ensures bash 5.3+ if available, regardless of system defaults.
- `source rayvn.up 'rayvn/prompt'` bootstraps rayvn, sets `scriptName` and loads the libraries it names: here
  [rayvn/prompt](/rayvn/api/rayvn-prompt), for `request`, which asks for the name if none was given.
  [rayvn/core](/rayvn/api/rayvn-core), with `show` for styled text output, is always loaded.
- All functions are defined before `source rayvn.up` so the file is fully parsed before `main` runs.

In a project (see [Creating a project](https://github.com/phoggy/rayvn#creating-a-project)), the same script also takes the standard options for help, version and
debug output, as scripts made with `rayvn new script` do:

```bash
#!/usr/bin/env rayvn-bash

usage() {
    show "Usage:" bold blue "${scriptName}" italic "[NAME]" "[OPTIONS]"
    showCommonOptions --header
    bye "$@"
}

main() {
    init "$@"
    show primary "Hey ${name^}!"
}

init() {
    declare -g name
    while (( $# )); do
        case "$1" in
            -h | --help) usage ;;
            -v) projectVersion greet; exit 0 ;;
            --version) projectVersion greet true; exit 0 ;;
            --debug*) setDebug "$@"; shift $? ;;
            -*) usage "unknown option: $1" ;;
            *) name="$1" ;;
        esac
        shift
    done
    [[ -n ${name} ]] || request "What's your name?" name || bye
    debug "name: '${name}'"
}

source rayvn.up 'rayvn/prompt'
main "$@"
```

`greet --help` shows:

![The help output of greet --help: usage, options, debug options and environment variables](/rayvn/assets/images/greet-help.svg)

- `showCommonOptions` prints the standard options: version, help and debug, and the environment variables of the
  libraries loaded (here `RAYVN_PROMPT_TIMEOUT`, from `rayvn/prompt`).
- `setDebug` handles the `--debug` options, and `debug` writes only when one is given: `greet alex --debug-out` shows
  `name: 'alex'` in the terminal, and `greet alex --debug` writes it to a log, shown on exit (see
  [Debugging rayvn applications](https://github.com/phoggy/rayvn#debugging-rayvn-applications)).
- `projectVersion greet` prints the version from the project's `rayvn.pkg`.

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
| [rayvn/args](/rayvn/api/rayvn-args) | Spec-driven argument parsing, usage, and shell completion generation, for scripts and CLIs alike. |

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
| [rayvn/screenshot](/rayvn/api/rayvn-screenshot) | Terminal screenshots: command output, with its colors and styles, as SVG images. |
| [rayvn/typist](/rayvn/api/rayvn-typist) | Typing jitter model (log-normal distribution approximation). |
| [rayvn/namespace](/rayvn/api/rayvn-namespace) | Detect namespace collisions across registered rayvn project libraries. |
| [rayvn/claude](/rayvn/api/rayvn-claude) | The guide for Claude Code on working with rayvn projects. |

## Related Projects

- [valt](/valt) — public key encryption for files and archives, using age and minisign, with a printable paper key for
  recovery
- [wardn](/wardn) — encrypted Bitwarden vault backup and restore, using valt's [secure archives](/valt/api/valt-archive#secure-archives)
