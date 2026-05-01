---
layout: default
title: CLI Reference
nav_order: 2
---

# rayvn CLI

rayvn is the command-line tool for managing shared libraries and projects. It handles project scaffolding, testing, documentation, publishing, and more.

## Usage

```
Create and manage rayvn projects, shared libraries, scripts and tests.

Usage: rayvn COMMAND [PROJECT] [PROJECT...] <options>

Commands

    new TYPE NAME    Create a new project, library script or test with the specified NAME.
    libraries        List libraries.
    functions        List functions.
    test             Run tests.
    theme            Select theme.
    lint             Scan source files for requirement violations.
    collisions       Check for namespace collisions within and across projects.
    dependencies     Scan source files and ensure dependency tracking is up to date.
    index            Generate function indexes for AI agent use.
    docs             Audit or update function documentation.
    pages            Generate and preview project gh-pages site.
    build            Run nix build.
    release          Create a new release.
    register         Stake a claim on a project name, if available.

Use COMMAND --help for additional details. PROJECT defaults to the current directory's project
if within one, otherwise to ${RAYVN_DEFAULT_PROJECT} (default: rayvn). Set to empty to require
an explicit project name. Most commands accept multiple project names.

Options

    -v               Print the version.
    --version        Print the version and release date.
    -h, --help       Print this help message.

Debug Options

    --debug          Enable debug, write output to log file and show on exit.
    --debug-new      Enable debug, clear log file, write output to log file and show on exit.
    --debug-out      Enable debug, write output to the current terminal.
    --debug-tty TTY  Enable debug, write output to the specified TTY (e.g., /dev/ttys001).
    --debug-tty .    Enable debug, write output to the TTY path read from the '~/.debug.tty' file.
```

Note: All examples below assume rayvn as the working directory so omit `PROJECT`.

## Commands

| |                                                             |
|---|-------------------------------------------------------------|
| [**new**](#new) | Create a project, script, library, or test from a template. |
| [**libraries**](#libraries) | List available libraries.                                   |
| [**functions**](#functions) | List public functions.                                      |
| [**test**](#test) | Run tests.                                                  |
| [**theme**](#theme) | Select a color theme.                                       |
| [**lint**](#lint) | Scan source files for requirement violations.               |
| [**collisions**](#collisions) | Check for namespace collisions.                             |
| [**dependencies**](#dependencies) | Verify external command dependencies are declared.          |
| [**index**](#index) | Generate function indexes for AI agent use.                 |
| [**docs**](#docs) | Audit or update function documentation.                     |
| [**pages**](#pages) | Generate, preview, and publish the GitHub Pages site.       |
| [**build**](#build) | Run nix build.                                              |
| [**release**](#release) | Create a versioned GitHub release.                          |
| [**register**](#register) | Stake a claim on a project name.                            |
{: .list-table}

### new

Create a new project, script, library, or test file from a template.

```
rayvn new project|script|library|test NAME [--local]
```

`project`
: Creates a full project directory with `bin/`, `lib/`, `tests/`, a `rayvn.pkg`, `flake.nix`,
  README, and Homebrew formula. Asks if you want to create a GitHub repo and clones it if so.

`script`
: Adds a new executable to the current project's `bin/` directory, pre-populated from the script template.

`library`
: Adds a new `.sh` file to the current project's `lib/` directory, pre-populated from the library template.

`test`
: Adds a new test file to the current project's `tests/` directory, pre-populated from the test template.

`--local`
: Skip GitHub repo creation; initialize a local git repo only.

All generated files are automatically staged in git.

<!-- record id="new"
     prompt="[rayvn]$ "
     pre="rm -rf /tmp/foo 2> /dev/null"
     cmd="cd /tmp" 
     cmd="rayvn new project foo"
     cmd="eza --tree foo" 
     cmd="cd foo"
     cmd="rayvn new library bar" 
     cmd="rayvn new test bar" 
     cmd="eza --tree" 
     post="rm -rf /tmp/foo" 
-->
{% include asciinema.html id="new" src="/assets/casts/new.cast" autoplay=false %} <!-- scrollable="500px" -->

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

<!-- record id="functions" pre="cd ~/dev/rayvn" cmd="rayvn functions prompt terminal" -->
{% include asciinema.html id="functions" src="/assets/casts/functions.cast" autoplay=false %}

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
{% include asciinema.html id="test" src="/assets/casts/test.cast" autoplay=false %}

When using `--nix` or `--all` the nix tests are blocked until the build completes:

<!-- record id="test-all" pre="cd ~/dev/rayvn" cmd="rayvn test --all" -->
{% include asciinema.html id="test-all" src="/assets/casts/test-all.cast" autoplay=false %}


### theme

Interactive prompt to choose between available themes. Use `--show` to see the current theme.

```
rayvn theme [--show]
```

**note**: *colors in the asciinema cast below render differently here than in a terminal.*

<!-- record id="theme" pre="cd ~/dev/rayvn" cmd="rayvn theme" -->
{% include asciinema.html id="theme" src="/assets/casts/theme.cast" autoplay=false %}


### lint

Scan project source files for violations of rayvn's bash requirements.

```
rayvn lint [PROJECT...] [--fix] [--ask]
```

`--fix`
: Auto-fix all violations that can be corrected automatically.

`--ask`
: Interactively prompt whether to fix each file with violations.

Note: The old `$( cmd )` command substitution syntax is detected but not auto-fixed.
The current `${ cmd; }` syntax is significantly more efficient.

<!-- record id="lint" pre="cd ~/dev/rayvn" cmd="rayvn lint" -->
{% include asciinema.html id="lint" src="/assets/casts/lint.cast" autoplay=false %}


### collisions

Check for namespace collisions within and across projects.

```
rayvn collisions [PROJECT...]
```

<!-- record id="collisions" pre="cd ~/dev/rayvn" cmd="rayvn collisions" -->
{% include asciinema.html id="collisions" src="/assets/casts/collisions.cast" autoplay=false %}

### dependencies

Scan source files for external command dependencies and verify they are declared in `flake.nix` runtimeDeps.

```
rayvn dependencies [--fix] [PROJECT...]
```

rayvn finds commands used in `bin/` and `lib/` files, confirms each is an actual external binary
(not a shell function), maps it to a Nix package name via `rayvn.pkg`, and verifies all are
declared in `flake.nix` runtimeDeps. Run this after adding new external tool usage to keep the Nix
build reproducible. Also updates npm dependencies if the project uses Node.

`--fix`
: Auto-replace `awk` with `gawk` and `sed` with `gsed` in source files for portability.

<!-- record id="dependencies" pre="cd ~/dev/rayvn" cmd="rayvn dependencies" -->
{% include asciinema.html id="dependencies" src="/assets/casts/dependencies.cast" autoplay=false %}

### index

Generate verbose and compact function indexes used by AI agents (e.g. Claude Code).

```
rayvn index [-o FILE] [-c FILE] [--no-compact] [--no-hash] [--hash-file FILE]
```

Produces two outputs:

**verbose index** (`~/.config/rayvn/rayvn-functions.md`)
: full documentation for every public function across all detected rayvn projects, including
  signatures, descriptions, and argument docs.

**compact index** (`~/.config/rayvn/rayvn-functions-compact.txt`)
: one-liner per function, used as quick-reference context in AI sessions.

Run after adding or modifying library functions to keep the indexes current. The `--no-hash` flag
skips change tracking; `--hash-file` overrides the default hash storage path.

<!-- record id="index" pre="cd ~/dev/rayvn" cmd="rayvn index" -->
{% include asciinema.html id="index" src="/assets/casts/index.cast" autoplay=false %}

### docs

Audit or update function documentation comments using the Claude API.

```
rayvn docs audit | update [PROJECT...] [OPTIONS]
```

**`audit`** reports missing/stale doc comments:

```
rayvn docs audit [PROJECT...] [--release]
```

`--release`
: exit 1 if any public functions are missing doc comments. Suitable for use in CI.

<!-- record id="docs-audit" pre="cd ~/dev/rayvn" cmd="rayvn docs audit" -->
{% include asciinema.html id="docs-audit" src="/assets/casts/docs-audit.cast" autoplay=false %}


**`update`** generates or fixes doc comments via the Claude API:

```
rayvn docs update [PROJECT...] [--dry-run] [--regen] [--missing-only|--stale-only]
                  [--lib NAME] [--since DUR] [--delay N]
```

`--dry-run`
: print proposed docs without writing any changes.

`--regen`
: regenerate docs for all public functions, not just missing/stale.

`--missing-only`
: only process functions missing a doc comment.

`--stale-only`
: only process functions with potentially stale docs.

`--lib NAME`
: limit to a single library by name.

`--since DURATION`
: skip functions updated within this duration (e.g. `30m`, `2h`, `1d`).

`--delay SECS`
: seconds to sleep between API calls to avoid rate limits (default: 5).


### pages

Generate, preview, and publish the project's GitHub Pages documentation site. Like this one.

```
rayvn pages [PROJECT] [--dir DIR] [--setup | --record [ID...] | --publish | --view]
```

PROJECT defaults to the current directory's project; only one may be specified.

`--setup`
: first-time setup: create `gh-pages` branch, worktree, and workflow. After setup, enable
  GitHub Pages in the repo settings (Source: GitHub Actions).

`--record [ID...]`
: re-record asciinema casts. Optionally filter by cast ID(s).

`--publish`
: generate pages, then commit and push to `gh-pages`. The GitHub Actions workflow deploys
  automatically on push.

`--view`
: generate pages, then serve locally with Jekyll at `http://localhost:4000` for live preview
  before publishing.

`--dir DIR`
: output directory (default: project's configured worktree).

*(no flag)*
: generate pages in the worktree without committing or serving.

Record markup — a `<!-- record -->` comment paired with an include tag in any pages markdown file:

{% raw %}
```
<!-- record id="NAME" cmd="COMMAND" [cmd="COMMAND" ...] [pre="CMD"] [post="CMD"] [prompt="PS1"] -->
{% include asciinema.html id="NAME" src="..." %}
```
{% endraw %}

`cmd=` is repeatable; commands are recorded sequentially. `pre=`/`post=` run before/after
recording but are not captured. `prompt=` sets the shell prompt (PS1) shown during recording.

<!-- record id="pages" pre="cd ~/dev/rayvn" cmd="rayvn pages" -->
{% include asciinema.html id="pages" src="/assets/casts/pages.cast" autoplay=false %}


### build

Run nix build for one or more projects.

```
rayvn build [PROJECT...]
```

Each project must have a `flake.nix`. Failure here typically means a missing dependency in
`flake.nix` — run `rayvn dependencies --fix` to sync them.

<!-- record id="build" pre="cd ~/dev/rayvn" cmd="rayvn build" -->
{% include asciinema.html id="build" src="/assets/casts/build.cast" autoplay=false %}

### release

Create a versioned GitHub release for a project.

```
rayvn release [PROJECT | --repo 'my-account/my-repo'] VERSION
```

VERSION should follow semver (e.g. `1.2.3`). For the core projects (rayvn, valt, wardn) the GitHub
repo is inferred from the project name. Requires `gh` (GitHub CLI) to be authenticated.

`--repo ACCOUNT/REPO`
: specify the GitHub repository explicitly.

### register

Stake a claim on a project name on rayvn central.

```
rayvn register PROJECT [--remove]
```

Must be run from within the project's git repo (the remote URL is read from `git remote`). The
project name must match the GitHub repo name.

`--remove`
: release the registered name.
