---
layout: default
title: CLI Reference
nav_order: 2
---

# rayvn CLI

rayvn is the command-line tool for managing shared libraries and projects. It handles project scaffolding, testing, documentation, publishing, and more.

## Usage

```
Manage shared bash libraries and executables.

Usage: rayvn COMMAND [PROJECT] [PROJECT...] <options>

Commands

    test              Run tests.
    build             Run nix build.
    theme             Select theme.
    new TYPE NAME     Create a new project/script/library/test with the specified NAME.
    libraries         List libraries.
    functions         List public functions.
    register NAME     Stake a claim on the project name, if available.
    release           Create a new release.
    deps              Scan source files and ensure dependency tracking is up to date.
    index             Generate function indexes for AI agent use.
    pages             Generate and preview project gh-pages site.
    docs              Audit or update function documentation.

Use COMMAND --help for any additional details. PROJECT defaults to the current directory's project
if within one. 'test' falls back to rayvn if not in a project.

Options:

    -h, --help        Print this help message and exit.
    -v                Print the version and exit.
    --version         Print the version with release date and exit.
```

PROJECT defaults to the current directory's project when run from within a rayvn project. Most
commands accept multiple project names to operate on several at once.

Note: All examples below assume rayvn as the working directory so omit PROJECT.

## Commands

### test

Run tests for one or more projects. Test files live in each project's `tests/` directory and are
discovered automatically.


```
rayvn test [PROJECT] [PROJECT...] [TEST-NAME] [TEST-NAME...] [--nix] [--all]
```

Without arguments, tests the current directory's project (or rayvn itself if not in a project).
Pass one or more TEST-NAME values to run only matching test cases. Use `--nix` to first build the
project with Nix before running tests, which is useful for verifying a clean Nix-built environment.

Tests run in parallel:

<!-- record id="test" cmd="rayvn test" -->
{% include asciinema.html id="test" src="/assets/casts/test.cast" autoplay=true %}

When using `--nix` or `--all` the nix tests are blocked until the build completes:

<!-- record id="test-all" cmd="rayvn test --all" -->
{% include asciinema.html id="test-all" src="/assets/casts/test-all.cast" autoplay=false %}

### build

Build one or more projects using their Nix flake. Useful for verifying the flake is valid and that
all declared Nix dependencies resolve correctly.

```
rayvn build [PROJECT] [PROJECT...]
```

Each project must have a `flake.nix`. The build runs `nix build` in the project root. Failure
here typically means a missing dependency in `flake.nix` — run `rayvn deps` to sync them.

<!-- record id="build" cmd="rayvn build" -->
{% include asciinema.html id="build" src="/assets/casts/build.cast" autoplay=false %}

### theme

Interactive theme selector. Launches an arrow-key navigation prompt to choose between available themes.

<!-- record id="theme" cmd="rayvn theme" -->
{% include asciinema.html id="theme" src="/assets/casts/theme.cast" autoplay=false %}

### new

Scaffold a new project, script, library, or test file from the built-in templates.

```
rayvn new project|script|library|test NAME [--local]
```

- **project** — creates a full project directory with `bin/`, `lib/`, `tests/`, a `rayvn.pkg`,
  `flake.nix`, README, and Homebrew formula. By default also creates a GitHub repo and clones it.
  Use `--local` to skip GitHub and create only a local git repo.
- **script** — adds a new executable to the current project's `bin/` directory, pre-populated
  from the script template.
- **library** — adds a new `.sh` file to the current project's `lib/` directory, pre-populated
  from the library template.
- **test** — adds a new test file to the current project's `tests/` directory, pre-populated
  from the test template.

All generated files are automatically staged in git.

<!-- record id="new-project" 
     pre="pushd ~/dev" 
     cmd="rayvn new project foo --local && cd foo && rayvn new test example && cd .. && eza --tree foo" 
     post="rm -rf foo; popd" -->
{% include asciinema.html id="new-project" src="/assets/casts/new-project.cast" autoplay=false %}


### libraries

List the available libraries for one or more projects.

```
rayvn libraries [PROJECT] [PROJECT...]
```

Prints each library in `project/library` format, grouped by project. Useful for quickly seeing
what's available to `source rayvn.up` or `require`.

{% include asciinema.html id="libraries" src="/assets/casts/libraries.cast" cmd="rayvn libraries" autoplay=false %}


### functions

List the public functions defined in each library of one or more projects.

```
rayvn functions [PROJECT/LIBRARY | PROJECT... [LIBRARY]] [--all]
```

By default shows only public functions (those not prefixed with `_`). Pass `--all` to also show
private `_functions`. Specify a qualified library name (e.g. `rayvn/core`) to list functions for
a single library. For full documentation including signatures and descriptions, see the
[API Reference]({{ site.baseurl }}/api) or use `rayvn index` to generate machine-readable indexes.

{% include asciinema.html id="functions" src="/assets/casts/functions.cast" cmd="rayvn functions" autoplay=false %}

### register

Stake a claim on a project name in the rayvn-central registry, making it discoverable by other
rayvn users and tools.

```
rayvn register PROJECT [--remove]
```

Must be run from within the project's git repo (the remote URL is read from `git remote`). The
project name must match the GitHub repo name. Use `--remove` to unregister.

### release

Create a new GitHub release for a project, tagging the current commit and publishing release notes.

```
rayvn release [PROJECT | --repo 'my-account/my-repo'] VERSION
```

VERSION should follow semver (e.g. `1.2.3`). For the core projects (rayvn, valt, wardn) the GitHub
repo is inferred from the project name. For other projects, supply `--repo 'account/repo'`
explicitly. Requires `gh` (GitHub CLI) to be authenticated.

### deps

Scan a project's source files for external command dependencies and sync any missing entries into
`flake.nix`'s `runtimeDeps`.

```
rayvn deps [PROJECT...]
```

rayvn finds commands used in `bin/` and `lib/` files, confirms each is an actual external binary
(not a shell function), maps it to a Nix package name via `rayvn.pkg`, and adds any missing
entries to `flake.nix`. Run this after adding new external tool usage to keep the Nix build
reproducible. Also updates npm dependencies if the project uses Node.

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

### pages

Generate, preview, and publish the project's GitHub Pages documentation site.

```
rayvn pages [PROJECT] [--dir DIR] [--setup | --record | --publish | --view]
```

Only one project at a time is supported. Subcommands:

- **`--setup`** — first-time setup: creates a `gh-pages` branch and worktree, generates scaffolding
  files (`_config.yml`, `Gemfile`, `index.md`, CI workflow), and pushes to GitHub. After setup,
  enable GitHub Pages in the repo settings (Source: GitHub Actions).
- **`--record`** — scan all markdown files in the pages worktree for asciinema includes with a
  `cmd=` attribute and re-record each cast using `rayvn-rec`. Casts are written to the path given
  by the `src=` attribute. Add `cmd="COMMAND"` to any include tag to make it recordable.
- **`--publish`** — regenerate all docs, then commit and push the gh-pages branch. The GitHub
  Actions workflow deploys automatically on push.
- **`--view`** — regenerate docs and serve the site locally with Jekyll at `http://localhost:4000`
  for live preview before publishing.
- *(no flag)* — regenerate docs in the worktree without committing or serving.

The `--dir DIR` option overrides the default worktree location.

### docs

Audit or update function documentation comments using the Claude API.

```
rayvn docs update | audit [PROJECT...] [OPTIONS]
```

**`audit`** reports on the state of documentation without making changes:

```
rayvn docs audit [PROJECT...] [--release]
```

Prints a summary of public functions that are missing doc comments or have stale ones (body changed
since the doc was written). `--release` exits non-zero if any issues are found, suitable for use
in CI.

**`update`** calls the Claude API to generate or fix doc comments for public functions:

```
rayvn docs update [PROJECT...] [--dry-run] [--regen] [--missing-only|--stale-only]
                  [--lib NAME] [--since DUR] [--delay N]
```

- `--dry-run` — print proposed changes without writing them
- `--regen` — regenerate all docs, even ones that appear current
- `--missing-only` / `--stale-only` — limit to functions that are missing docs or have stale docs
- `--lib NAME` — process only the named library (e.g. `rayvn/core`)
- `--since DUR` — only process functions changed within the given duration (e.g. `7d`, `2h`)
- `--delay N` — wait N milliseconds between API calls to avoid rate limits
### lint

```
rayvn lint [PROJECT...]

Scan project source files for violations of rayvn's bash requirements.
```

