#compdef rayvn

# Generated zsh completion for the rayvn CLI — DO NOT EDIT.
# Regenerate via 'rayvn args bin/rayvn'.

# Scan PATH for rayvn project roots (dev layout: <root>/bin/, Nix layout:
# <prefix>/bin/ with rayvn.pkg under share/) and output their project names, one per line.
__rayvnCompletionProjects() {
    local dir pkg IFS=:
    for dir in $PATH; do
        [[ -d "${dir}" ]] || continue
        for pkg in "${dir}/../rayvn.pkg" "${dir}/../share/"*/rayvn.pkg; do
            [[ -f "${pkg}" ]] && gawk -F"'" '/^projectName=/{print $2; exit}' "${pkg}" 2> /dev/null
        done
    done | sort -u
}

_rayvn_projects() {
    local -a projects; projects=(${(f)"$(__rayvnCompletionProjects)"})
    _describe 'project' projects
}

_rayvn() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '1: :->command' \
        '*::arg:->args'

    case $state in
        command)
            local -a commands=(
                'args:Regenerate the parser block in SCRIPT from its spec, or with --check report'
                'build:Run nix build for one or more projects.'
                'collisions:Check for function and global variable name collisions across project libraries.'
                'deps:Scan source files for external command dependencies and verify they are declared in flake.nix runtimeDeps.'
                'dependencies:Scan source files for external command dependencies and verify they are declared in flake.nix runtimeDeps.'
                'functions:List public functions for project libraries.'
                'index:Generate verbose and compact function indexes used by AI agents (e.g. Claude Code), and the rayvn guide for Claude Code.'
                'libraries:List all libraries for one or more projects.'
                'lint:Scan project source files for violations of rayvn'\''s bash requirements.'
                'new:Create a new project, library, script or test from a template.'
                'create:Create a new project, library, script or test from a template.'
                'pages:Generate and preview the project'\''s gh-pages site.'
                'projects:Show info for one or more projects.'
                'register:Stake a claim on a project name on rayvn central.'
                'release:Create a versioned GitHub release for the current directory'\''s project. The GitHub repository is derived from'
                'test:Run tests for one or more projects.'
                'theme:Interactively select a color theme for rayvn output or show the current theme.'
                'docs:'
            )
            _describe 'command' commands
            ;;
        args)
            case $words[1] in
                docs)
                    _arguments -C \
                        '1: :->subcommand' \
                        '*::arg:->args'
                    case $state in
                        subcommand)
                            local -a subcommands=(
                                'audit:Report missing/stale ◇ doc comments.'
                                'update:Generate or fix ◇ doc comments via Claude API.'
                            )
                            _describe 'subcommand' subcommands
                            ;;
                        args)
                            case $words[1] in
                                audit)
                                    _arguments \
                                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                                    '(--release)'--release'[Exit 1 if any public functions are missing ◇ doc comments.]' \
                                    '*:PROJECT...:_rayvn_projects'
                                    ;;
                                update)
                                    _arguments \
                                    '(--delay)'--delay'[Seconds to sleep between API calls to avoid rate limits.]:delay:' \
                                    '(--dry-run)'--dry-run'[Print proposed docs without writing any changes.]' \
                                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                                    '(--lib)'--lib'[Limit to a single library by name.]:lib:' \
                                    '(--missing-only)'--missing-only'[Only process functions missing a ◇ doc comment.]' \
                                    '(--regen)'--regen'[Regenerate docs for all public functions, not just missing/stale.]' \
                                    '(--since)'--since'[Skip functions updated within this duration (e.g. '\''30m'\'', '\''2h'\'', '\''1d'\'').]:since:' \
                                    '(--stale-only)'--stale-only'[Only process functions with potentially stale docs.]' \
                                    '*:PROJECT...:_rayvn_projects'
                                    ;;
                            esac
                            ;;
                    esac
                    ;;
                args)
                    _arguments \
                    '(--check)'--check'[Report drift without updating the file.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '1:SCRIPT:_command_names -e'
                    ;;
                build)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '*:PROJECT...:_rayvn_projects'
                    ;;
                collisions)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '*:PROJECT...:_rayvn_projects'
                    ;;
                deps | dependencies)
                    _arguments \
                    '(--fix)'--fix'[Auto-replace '\''awk'\'' with '\''gawk'\'' and '\''sed'\'' with '\''gsed'\'' in source files for portability.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '*:PROJECT...:_rayvn_projects'
                    ;;
                functions)
                    _arguments \
                    '(--all)'--all'[Also list private (_-prefixed) functions.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '*:ARGS...:'
                    ;;
                index)
                    _arguments \
                    '(--claude)'--claude'[Only update the rayvn guide for Claude Code (~/.config/rayvn/claude-rayvn.md), which is fast. Run it after adding a project to PATH or upgrading rayvn.]' \
                    '(--compact -c)'{--compact,-c}'[Compact index output file (default: ~/.config/rayvn/rayvn-functions-compact.txt).]:compact:' \
                    '(--hash-file)'--hash-file'[Function hash file (default: ~/.config/rayvn/rayvn-function-hashes.txt).]:hash-file:' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--no-compact)'--no-compact'[Skip generating the compact index.]' \
                    '(--no-hash)'--no-hash'[Skip function hash tracking.]' \
                    '(--output -o)'{--output,-o}'[Verbose index output file (default: ~/.config/rayvn/rayvn-functions.md).]:output:' \
                    '*:PROJECT...:_rayvn_projects'
                    ;;
                libraries)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '*:PROJECT...:_rayvn_projects'
                    ;;
                lint)
                    _arguments \
                    '(--fix --ask)'--ask'[Interactively prompt whether to fix each file with violations.]' \
                    '(--fix --ask)'--fix'[Auto-fix all violations that can be corrected automatically.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '*:PROJECT...:_rayvn_projects'
                    ;;
                new | create)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--local)'--local'[Skip GitHub repo creation; initialize a local git repo only.]' \
                    '1:TYPE:(project script library test)' \
                    '2:NAME:'
                    ;;
                pages)
                    _arguments \
                    '(--dir)'--dir'[Output directory (default: project'\''s configured worktree).]:dir:' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--setup --record --publish --view)'--publish'[Generate pages, then commit and push to gh-pages.]' \
                    '(--setup --record --publish --view)'--record'[Re-record asciinema casts; optionally filter by cast ID(s), all if omitted.]:record:' \
                    '(--setup --record --publish --view)'--setup'[First-time setup: create gh-pages branch, worktree, and workflow.]' \
                    '(--setup --record --publish --view)'--view'[Generate pages, then serve locally with Jekyll.]' \
                    '1:PROJECT:_rayvn_projects'
                    ;;
                projects)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '*:PROJECT...:_rayvn_projects'
                    ;;
                register)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '1:NAME:'
                    ;;
                release)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '1:VERSION:'
                    ;;
                test)
                    _arguments \
                    '(--all)'--all'[Run tests locally and then again inside nix.]' \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--nix)'--nix'[Run tests inside a nix develop shell.]' \
                    '*:ARGS...:'
                    ;;
                theme)
                    _arguments \
                    '(--help -h)'{--help,-h}'[Print this help message.]' \
                    '(--show)'--show'[Show current theme.]'
                    ;;
            esac
            ;;
    esac
}

(( $+functions[compdef] )) && compdef _rayvn rayvn
