---
layout: default
title: CLI Reference
nav_order: 2
---

# rayvn CLI

rayvn is the command-line tool for managing shared libraries and projects. It handles project scaffolding, testing, documentation, publishing, and more.

## Usage

```
Manage shared libraries and executables.

Usage: rayvn COMMAND [PROJECT] [PROJECT...] <options>

Commands

    new TYPE NAME     Create a new project, script, library or test with the specified NAME.
    test              Run tests.
    theme             Select theme.
    libraries         List libraries.
    functions         List functions.
    lint              Scan source files for requirement violations.
    collisions        Check for namespace collisions within and across projects.
    dependencies      Scan source files and ensure dependency tracking is up to date.
    index             Generate function indexes for AI agent use.
    docs              Audit or update function documentation.
    pages             Generate and preview project gh-pages site.
    build             Run nix build.
    release           Create a new release.
    register          Stake a claim on a project name, if available.

Use COMMAND --help for any additional details. PROJECT defaults to the current directory's project
if within one. 'test' falls back to rayvn if not in a project.

Options:

    -h, --help        Print this help message.
    -v                Print the version.
    --version         Print the version with release date.

Debug Options:

    --debug           Enable debug, write output to log file and show on exit.
    --debug-new       Enable debug, clear log file, write output to log file and show on exit.
    --debug-out       Enable debug, write output to the current terminal.
    --debug-tty TTY   Enable debug, write output to the specified TTY (e.g., /dev/ttys001).
    --debug-tty .     Enable debug, write output to the TTY path read from the '~/.debug.tty' file.
```

PROJECT defaults to the current directory's project when run from within a rayvn project. Most
commands accept multiple project names to operate on several at once.

Note: All examples below assume rayvn as the working directory so omit PROJECT.

## Commands

### new

Scaffold a new project, script, library, or test file from built-in templates.

```
rayvn new project|script|library|test NAME [--local]
```

- **project** — creates a full project directory with `bin/`, `lib/`, `tests/`, a `rayvn.pkg`,
  `flake.nix`, README, and Homebrew formula. Asks if you want to create a GitHub repo and clones it if so.
  Use `--local` to skip GitHub and create only a local git repo.
- **script** — adds a new executable to the current project's `bin/` directory, pre-populated
  from the script template.
- **library** — adds a new `.sh` file to the current project's `lib/` directory, pre-populated
  from the library template.
- **test** — adds a new test file to the current project's `tests/` directory, pre-populated
  from the test template.

All generated files are automatically staged in git.

<!-- record id="new-project"
     prompt="[rayvn]$ "
     cmd="cd /tmp" 
     cmd="rayvn new project foo"
     cmd="eza --tree foo" 
     cmd="cd foo"
     cmd="rayvn new library bar" 
     cmd="rayvn new test bar" 
     cmd="eza --tree" 
     post="rm -rf /tmp/foo" 
-->
{% include asciinema.html id="new-project" src="/assets/casts/new-project.cast" autoplay=false %}

### test

Run tests for one or more projects. Test files live in each project's `tests/` directory and are
discovered automatically.

```
rayvn test [PROJECT] [PROJECT...] [TEST-NAME] [TEST-NAME...] [--nix] [--all]
```

Without arguments, tests the current directory's project (or rayvn itself if not in a project).
Pass one or more TEST-NAME values to run only matching test cases. Use `--nix` to run tests inside
a nix develop shell. Use `--all` to run tests locally and then again inside nix.

Tests run in parallel:

<!-- record id="test" pre="cd ~/dev/rayvn" cmd="rayvn test" -->
{% include asciinema.html id="test" src="/assets/casts/test.cast" autoplay=true %}

When using `--nix` or `--all` the nix tests are blocked until the build completes:

<!-- record id="test-all" pre="cd ~/dev/rayvn" cmd="rayvn test --all" -->
{% include asciinema.html id="test-all" src="/assets/casts/test-all.cast" autoplay=false %}


### theme

Interactive theme selector. Launches an arrow-key navigation prompt to choose between available themes.

```
rayvn theme
```

<!-- record id="theme" pre="cd ~/dev/rayvn" cmd="rayvn theme" -->
{% include asciinema.html id="theme" src="/assets/casts/theme.cast" autoplay=false %}


### libraries

List the available libraries for one or more projects.

```
rayvn libraries [PROJECT] [PROJECT...]
```

Prints each library in `project/library` format, grouped by project. Useful for quickly seeing
what's available to `source rayvn.up` or `require`.

<!-- record id="libraries" pre="cd ~/dev/rayvn" cmd="rayvn libraries" -->
{% include asciinema.html id="libraries" src="/assets/casts/libraries.cast" autoplay=false %}


### functions

List the public functions defined in each library of one or more projects.

```
rayvn functions [PROJECT/LIBRARY | PROJECT... [LIBRARY]] [--all]
```

By default shows only public functions (those not prefixed with `_`). Pass `--all` to also show
private `_functions`. Specify a qualified library name (e.g. `rayvn/core`) to list functions for
a single library. For full documentation including signatures and descriptions, see the
[API Reference]({{ site.baseurl }}/api) or use `rayvn index` to generate machine-readable indexes.

<!-- record id="functions" pre="cd ~/dev/rayvn" cmd="rayvn functions" -->
{% include asciinema.html id="functions" src="/assets/casts/functions.cast" autoplay=false %}

### lint

Scan project source files for violations of rayvn's bash requirements.

```
rayvn lint [PROJECT...] [--fix] [--ask]
```

- `--fix`  Auto-fix all violations that can be corrected automatically.
- `--ask`  Interactively prompt whether to fix each file with violations.

*Note* old-style command substitution $() is detected but not auto-fixed.

<!-- record id="lint" pre="cd ~/dev/rayvn" cmd="rayvn lint" -->
{% include asciinema.html id="lint" src="/assets/casts/lint.cast" autoplay=false %}


### collisions

Check for function and global variable name collisions across project libraries.

```
rayvn collisions [PROJECT...]
```

<!-- record id="collisions" pre="cd ~/dev/rayvn" cmd="rayvn collisions" -->
{% include asciinema.html id="collisions" src="/assets/casts/collisions.cast" autoplay=false %}

### dependencies

Scan a project's source files for external command dependencies and sync any missing entries into
`flake.nix`'s `runtimeDeps`.

```
rayvn dependencies [--fix] [PROJECT...]
```

rayvn finds commands used in `bin/` and `lib/` files, confirms each is an actual external binary
(not a shell function), maps it to a Nix package name via `rayvn.pkg`, and verifies all are
declared in `flake.nix` runtimeDeps. Run this after adding new external tool usage to keep the Nix
build reproducible. Also updates npm dependencies if the project uses Node.

- `--fix` — auto-replace `awk` with `gawk` and `sed` with `gsed` in source files.

<!-- record id="dependencies" pre="cd ~/dev/rayvn" cmd="rayvn dependencies" -->
{% include asciinema.html id="dependencies" src="/assets/casts/dependencies.cast" autoplay=false %}

### index

Generate the function indexes used by AI coding agents (e.g. Claude Code) to discover available
library functions without loading the libraries at runtime.

```
rayvn index [-o FILE] [-c FILE] [--no-compact] [--no-hash] [--hash-file FILE]
```

Produces two outputs:

- **verbose index** (`~/.config/rayvn/rayvn-functions.md`) — full documentation for every public
  function across all detected rayvn projects, including signatures, descriptions, and argument docs.
- **compact index** (`~/.config/rayvn/rayvn-functions-compact.txt`) — one-liner per function, used
  as quick-reference context in AI sessions.

Run `rayvn index` after adding or modifying library functions to keep the indexes current. The
`--no-hash` flag skips change tracking; `--hash-file` overrides the default hash storage path.

<!-- record id="index" pre="cd ~/dev/rayvn" cmd="rayvn index" -->
{% include asciinema.html id="index" src="/assets/casts/index.cast" autoplay=false %}

### docs

Audit or update function documentation comments using the Claude API.

```
rayvn docs audit | update [PROJECT...] [OPTIONS]
```

**`audit`** reports on the state of documentation without making changes:

```
rayvn docs audit [PROJECT...] [--release]
```

Prints a summary of public functions that are missing doc comments or have stale ones (body changed
since the doc was written). `--release` exits non-zero if any issues are found, suitable for use
in CI.

<!-- record id="docs-audit" pre="cd ~/dev/rayvn" cmd="rayvn docs audit" -->
{% include asciinema.html id="docs-audit" src="/assets/casts/docs-audit.cast" autoplay=false %}


**`update`** calls the Claude API to generate or fix doc comments for public functions:

```
rayvn docs update [PROJECT...] [--dry-run] [--regen] [--missing-only|--stale-only]
                  [--lib NAME] [--since DUR] [--delay N]
```

- `--dry-run` — print proposed changes without writing them
- `--regen` — regenerate all docs, even ones that appear current
- `--missing-only` / `--stale-only` — limit to functions that are missing docs or have stale docs
- `--lib NAME` — process only the named library (e.g. `rayvn/core`)
- `--since DURATION` — skip functions updated within this duration (e.g. `30m`, `2h`, `1d`); ignored when `--regen` is set
- `--delay SECS` — seconds to sleep between API calls to avoid rate limits (default: 5)


### pages

Generate, preview, and publish the project's GitHub Pages documentation site. Like this one.

```
rayvn pages [PROJECT] [--dir DIR] [--setup | --record [ID...] | --publish | --view]
```

Only one project at a time is supported. Subcommands:

- **`--setup`** — first-time setup: creates a `gh-pages` branch and worktree, generates scaffolding
  files (`_config.yml`, `Gemfile`, `index.md`, CI workflow), and pushes to GitHub. After setup,
  enable GitHub Pages in the repo settings (Source: GitHub Actions).
- **`--record [ID...]`** — scan all markdown files in the pages worktree for `<!-- record -->`
  comments and re-record each cast. Pass one or more IDs to record only matching casts. Casts are
  written to the path given by the paired `{% include asciinema.html %}` tag's `src=` attribute.

  Record markup format:
  ```
  <!-- record id="NAME" cmd="COMMAND" [cmd="COMMAND" ...] [pre="CMD"] [post="CMD"] [prompt="PS1"] -->
  {% include asciinema.html id="NAME" src="..." %}
  ```
  `cmd=` is repeatable; commands are recorded sequentially. `pre=`/`post=` run before/after
  recording but are not captured. `prompt=` sets the shell prompt (PS1) shown during recording.
- **`--publish`** — regenerate all docs, then commit and push the gh-pages branch. The GitHub
  Actions workflow deploys automatically on push.
- **`--view`** — regenerate docs and serve the site locally with Jekyll at `http://localhost:4000`
  for live preview before publishing.
- *(no flag)* — regenerate docs in the worktree without committing or serving.

The `--dir DIR` option overrides the default worktree location.


<!-- record id="pages-view" pre="cd ~/dev/rayvn" cmd="rayvn pages --view" -->
{% include asciinema.html id="pages" src="/assets/casts/pages-view.cast" autoplay=false %}


### build

Build one or more projects using their Nix flake. Useful for verifying the flake is valid and that
all declared Nix dependencies resolve correctly.

```
rayvn build [PROJECT] [PROJECT...]
```

Each project must have a `flake.nix`. The build runs `nix build` in the project root. Failure
here typically means a missing dependency in `flake.nix` — run `rayvn deps` to sync them.

<!-- record id="build" pre="cd ~/dev/rayvn" cmd="rayvn build" -->
{% include asciinema.html id="build" src="/assets/casts/build.cast" autoplay=false %}

### release

Create a new GitHub release for a project, tagging the current commit and publishing release notes.

```
rayvn release [PROJECT | --repo 'my-account/my-repo'] VERSION
```

VERSION should follow semver (e.g. `1.2.3`). For the core projects (rayvn, valt, wardn) the GitHub
repo is inferred from the project name. For other projects, supply `--repo 'account/repo'`
explicitly. Requires `gh` (GitHub CLI) to be authenticated.

### register

Stake a claim on a project name in the rayvn-central registry, making it discoverable by other
rayvn users and tools.

```
rayvn register PROJECT [--remove]
```

Must be run from within the project's git repo (the remote URL is read from `git remote`). The
project name must match the GitHub repo name. Use `--remove` to unregister.



