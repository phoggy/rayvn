# Rayvn

## Overview

rayvn is a system for bash 5.3+ programs to use shared libraries, provided by rayvn itself or by other rayvn based
projects. rayvn is also a command (`rayvn`) for creating, testing, linting, documenting and releasing those projects,
and contains `rayvn.up`, the bootstrap for shared libraries. For example, a script in the valt project contains:

```bash
source rayvn.up 'rayvn/core' 'valt/keys'
```

This performs the bootstrap, then loads the `core.sh` library from `rayvn/lib/core.sh` and the `keys.sh` library from
`valt/lib/keys.sh`. `rayvn.up` detects rayvn projects via PATH, so no explicit `--add` is needed when project bin
directories are in PATH.

All rayvn scripts use the following pattern:

```bash
usage() {...}
main() {...} # calls init first then any other app logic
init() {...}

# functions

source rayvn.up ...
main "$@" # always last to ensure all file contents have been parsed
```

## Projects

The rayvn projects on this system (development checkouts with bin directories on PATH):

${rayvnGuideProjects}

Each is a separate git repo. rayvn itself is at `${rayvnHome}`.

## Project Structure

```
project/
├── bin/        # scripts, e.g. valt
├── lib/        # shared libraries
├── test/       # tests
├── rayvn.pkg   # project metadata
└── ...
```

## GitHub Pages

A project's GitHub Pages site (Jekyll) is managed in a separate git worktree on its `gh-pages` branch, listed in the
table above. Work directly in the worktree rather than checking out `gh-pages` in the main repo.

`rayvn pages PROJECT` generates the API docs from library doc comments, and the API index from the Libraries table in
the site's `index.md` (edit library descriptions there). Styles, includes and plugins shared by all sites live in
`${rayvnHome}/etc/pages/` and are copied into each site by `rayvn pages`: edit them there, never in a site's copy.

## Debugging rayvn Applications

All rayvn applications support debug options via the `rayvn/debug` library (automatically included with `rayvn/core`).

### Debug Command-Line Options

Every rayvn app supports these standard debug options:
- `--debug` - Enable debug logging, show output on exit
- `--debug-new` - Enable debug logging with cleared log file, show output on exit
- `--debug-out` - Send debug output to current terminal (uses `tty`)
- `--debug-tty /dev/ttys001` - Send debug output to specific terminal device
- `--debug-tty .` - Read tty path from `${HOME}/.debug.tty` file (convenient shortcut)

### Using Debug Functions

Use the `debug()` function to generate diagnostic output:
```bash
debug "variable value: ${myVar}"
debug "processing item ${i} of ${total}"
```

Debug output is only generated when debug mode is enabled via command-line options.

### Example: Debugging to Separate Terminal

Method 1 - Direct TTY path:
```bash
# Terminal 1: Find your TTY
$ tty
/dev/ttys001

# Terminal 2: Run your script with debug output to Terminal 1
$ my-rayvn-app --debug-tty /dev/ttys001
```

Method 2 - Using .debug.tty file (convenient):
```bash
# Terminal 1: Set up debug terminal
$ tty > ~/.debug.tty

# Terminal 2: Run your script with debug output to debug terminal
$ my-rayvn-app --debug-tty .
```

### Implementation Notes

- The script template (templates/script-template.sh) includes debug option handlers by default
- `setDebug()` is called to configure the debug system based on command-line options
- Debug is a no-op when not enabled (zero performance impact)

## Bash Requirements

- **Variable expansion**: Always use ${} for named variables; use bare $1, $2 etc. for positional parameters
  - Named variables: ${varName}; single-character names may omit braces: `$i`, `$n`, `$k`
  - Function arguments: $1, $2, etc. (no braces needed)
    - Quote when a string arg may contain spaces: `local file="$1"`
    - No quotes needed for nameref targets, integers, or booleans: `local -n resultsRef=$1`, `local count=$2`, `local flag=$3`
    - Nameref variable names must end in `Ref`: `local -n findingsRef=$1`, `local -n totalRef=$2`
  - Special parameters (no braces): $#, $@, $?, $!, $$, $*, $-
    - Always quote $@ and $* to preserve arguments: `"$@"` and `"$*"`
    - Correct: `main "$@"`, `function "$@"`
    - Incorrect: `main ${@}`, `main $@` (unquoted breaks args with spaces)
  - Always use explicit ${} even where bare names work (removes ambiguity):
    - Array slices: `${arr[@]:${offset}}` not `${arr[@]:offset}`
    - Arithmetic for loops: `for (( i=0; i < ${max}; i++ ))` not `i < max`
- **Command substitution**: Always use ${ cmd; } syntax (bash 5.3+ with trailing semicolon)
- **Reading files into variables**: Use `readFile file varName` instead of command substitution
  - Correct: `local html; readFile "${templateFile}" html`
  - Incorrect: `local html; html=${ cat "${templateFile}"; }`
  - Use `-p` flag to preserve trailing newlines when needed: `readFile -p "${file}" var`
- **Naming conventions**: Always use camelCase for function and variable names
- **DRY principle**: Follow Don't Repeat Yourself where practical
  - Extract repeated code into functions
  - Use variables for repeated values
  - Prefer library functions over duplicating logic (check the function index first)
- **Variable declarations**: Always declare local variables with `local` before use
  - Prefer separate declaration and assignment to avoid shellcheck glob warnings and allow `|| fail`:
    - Correct: `local workDir; workDir=${ makeTempDir; }`
    - Correct: `local file; file=${ makeTempFile; } || fail`
  - Combined form is acceptable for simple literal assignments: `local name='foo'`, `local count=0`
  - Incorrect: `myVar=${ cmd; }` (missing local declaration in function scope)
- **Conditionals**: Use [[ ]] for test expressions (not [ ])
  - Prefer `[[ condition ]] && { cmd1; cmd2; }` over `if/then` for simple cases to reduce clutter
    - Correct: `[[ $1 == -p ]] && { preserve=1; shift; }`
    - Use `if/then` when there is an else branch or the body is complex
- **Boolean flags**: Use `(( flag ))` to test boolean/numeric flags, not `[[ ${flag} ]]`
  - Correct: `(( myFlag ))` or `(( ! myFlag ))`
  - Incorrect: `[[ ${myFlag} ]]` or `[[ -n ${myFlag} ]]`
- **String emptiness tests**: Always use `-n` or `-z` in `[[ ]]` — never use bare `[[ ${var} ]]` or `[[ ! ${var} ]]`
  - Correct: `[[ -n ${var} ]]` and `[[ -z ${var} ]]`
  - Incorrect: `[[ ${var} ]]` and `[[ ! ${var} ]]`
- **Spacing**: Always include spaces inside double brackets and double parentheses
  - Correct: `[[ -f "${file}" ]]` and `(( count > 0 ))`
  - Incorrect: `[[-f "${file}"]]` and `((count > 0))`
  - Exception: POSIX character classes `[[:alpha:]]`, `[[:space:]]`, etc. are not `[[` operators — no extra space needed or expected
- **Redirects**: Always include a space before the file when redirecting
  - Correct: `<cmd> > /dev/null`, `<cmd> 2>&1`, `<cmd> &> /dev/null`
  - Incorrect: `<cmd> >/dev/null`, `<cmd>>/dev/null`
- **Subcommand help text**: When printing usage for a command with subcommands, use spaces around `|` and align descriptions to a common column
  - Correct:
    ```bash
    echo "rayvn docs update | audit [PROJECT...] [OPTIONS]"
    echo "  update  [--dry-run] [--regen] [--opt]  Generate/fix docs via Claude API"
    echo "  audit   [--release]                    Report missing/stale docs"
    ```
  - Incorrect: `audit|update`, misaligned descriptions
- **Case statements**: Prefer compact single-line form for each pattern where reasonable
  - Correct:
    ```bash
    case ${var} in
        opt1) cmd1; cmd2 ;;
        opt2) cmd3 ;;
    esac
    ```
  - Multi-line form acceptable for complex commands (can mix styles):
    ```bash
    case ${var} in
        opt1)
            longCommand1
            longCommand2
            ;;
        opt2) shortCommand ;;
    esac
    ```
- **Readonly functions**: rayvn.up marks all loaded functions as readonly by default
  - To prevent this (e.g. in tests that need to mock library functions), set `rayvnTest_ModifiableFunctions=1` before `source rayvn.up`
  - Example: `rayvnTest_ModifiableFunctions=1` then `source rayvn.up 'rayvn/test' 'rayvn/oauth'`
  - See "Test Behavior Flags" section below for all available test flags
- **No strict mode**: Do NOT use `set -euo pipefail` in rayvn scripts (rayvn.up disables these options)
  - Instead of errexit, use explicit error handling: `<cmd> || fail "error message"`
  - Use rayvn/core assert functions where appropriate:
    - `assertFileExists "${file}"` - verify file exists
    - `assertFile "${file}"` - verify is a file
    - `assertDirectory "${dir}"` - verify is a directory
    - `assertFileDoesNotExist "${file}"` - verify file doesn't exist
    - `assertValidFileName "${name}"` - validate filename is safe
  - Examples:
    - `mkdir "${dir}" || fail "could not create directory ${dir}"`
    - `assertFile "${configFile}"` (instead of `[[ -f "${file}" ]] || fail`)
    - `accessToken=${ getAccessToken; } || fail "failed to get access token"`
  - **Using `|| true`**: Only use `|| true` when you want to suppress a command's failure and ensure it returns success
    - Use it when the command is the last one that determines a function's exit code
    - Do NOT use it for commands followed by other commands (their exit code doesn't matter)
    - Example where `|| true` is needed: `rm -f "${file}" 2> /dev/null || true` (last command in function, want to ignore failure)
    - Example where `|| true` is NOT needed: `rm -f "${file}" 2> /dev/null || true; touch "${file}"` (the touch determines exit code)
  - **Arithmetic increment**: `(( count++ ))` and `(( count-- ))` are preferred for standalone increment/decrement
    - Only use `(( count += 1 ))` / `(( count -= 1 ))` when the expression is used as a boolean test (i.e. the exit code matters for flow control)
- **Argument parsing**: Most scripts parse arguments by hand in `init()`, as `script-template.sh` does. A script with
  many options or with subcommands (e.g. `rayvn`, `valt`) can instead use a parser generated by `rayvn/args` from a spec
  (`# rayvn:args specVar` for a single command, `# rayvn:cli cliSpec` for subcommands); results land in `_opts` and
  `_args`
  - After changing a spec or its doc comments, regenerate with `rayvn args SCRIPT` (also updates shell completions)
  - Never edit the generated code between `ARGS_PARSER_BEGIN` and `ARGS_PARSER_END`; `rayvn lint` reports drift
  - `parseArgsWithSpec` parses with a spec without a generation step, for one-off cases
- **Doc comments**: Public library functions use the `◇` doc comment format in `${rayvnHome}/etc/function-doc-spec.md`
  - `rayvn docs audit PROJECT` reports missing or stale docs and entries that break the spec (unknown types,
    bracketed option entries, long option forms in signatures); `rayvn docs update` regenerates docs
- **Checking work**: Run `rayvn test PROJECT [NAME]` and `rayvn lint PROJECT` after changes
- **Using rayvn**: Use rayvn for new scripts in rayvn projects
  - **Creating new code**: Use `rayvn new` commands instead of manual creation
    - New project: `rayvn new project <name>`
    - New script in a project: `rayvn new script <name>`
    - New library in a project: `rayvn new library <name>`
    - New test in a project: `rayvn new test <name>`
    - These commands use the correct templates and structure, and stage the new files in git
  - Use rayvn shared libraries where appropriate (from rayvn or any of the projects above)
  - Call `source rayvn.up` before `main "$@"`
  - `rayvn.up` detects rayvn projects via PATH — no `--add` is needed when project bin directories are in PATH:
    - `source rayvn.up 'rayvn/core' 'valt/keys'` — works if valt is in PATH
    - `--add` is only needed for projects not in PATH: `source rayvn.up --add myproject=/path/to/root 'myproject/lib'`
  - **Function index**: Use `${rayvnConfigDir}/rayvn-functions-compact.txt` to find available library functions
    - Load the compact index into context when writing bash scripts
    - Scan it before writing code to check if library functions exist for what you're about to do
    - Prefer library functions over reinventing functionality (e.g., `ensureDir` instead of `mkdir -p`)
    - The verbose index at `${rayvnConfigDir}/rayvn-functions.md` has full documentation if needed
    - `rayvn index PROJECT...` updates both indexes (and this guide); run it when libraries change or when asked
  - **Running scripts**: Project bin directories are on PATH, so run scripts by name (e.g. `rayvn new script`), not
    by path or after cd'ing to a project directory
- **Git**: When creating or generating a new file in a git project, run `git add <file>` to stage it
  - Check if the directory is a git repo first
  - Stage the file immediately after creation
  - **Exception**: Files created via `rayvn new` commands are already staged
- **Compatibility**: All rayvn based projects must work on both macOS and Linux
  - Always use `gawk` instead of `awk` and `gsed` instead of `sed` — macOS ships BSD versions that lack GNU features; the
    linter flags these as portability issues

## Test Behavior Flags

All test flags that modify default rayvn behavior use the `rayvnTest_` prefix:

- `rayvnTest_ModifiableFunctions` - prevents functions from being marked readonly, allowing test mocking
- `rayvnTest_DeferCore` - defers automatic loading of `rayvn/core` in rayvn.up
- `rayvnTest_Force24BitColor` - forces 24-bit color support even without TTY detection
- `rayvnTest_NoEchoOnExit` - suppresses the newline normally added on exit (only added when stdout is a terminal)
- `rayvnTest_NonInteractive` - for tests without TTY; sets `terminal="/dev/fd/3"` instead of `/dev/tty`

Projects may add their own `rayvnTest_` hooks; see their CLAUDE.md.
