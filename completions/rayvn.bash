#!/usr/bin/env bash

# Bash completion for the rayvn CLI.

# Scan PATH for rayvn project roots (dev layout: <root>/bin/, Nix layout: <prefix>/bin/ with
# rayvn.pkg under share/) and output their names.
_rayvn_projects() {
    local dir pkg IFS=:
    for dir in $PATH; do
        [[ -d "${dir}" ]] || continue
        for pkg in "${dir}/../rayvn.pkg" "${dir}/../share/"*/rayvn.pkg; do
            [[ -f "${pkg}" ]] && gawk -F"'" '/^projectName=/{print $2; exit}' "${pkg}" 2>/dev/null
        done
    done | sort -u
}

# Output PROJECT/LIBRARY completions for a given project name.
_rayvn_libraries() {
    local project="${1}" dir pkg pname libDir lib IFS=:
    for dir in $PATH; do
        [[ -d "${dir}" ]] || continue
        for pkg in "${dir}/../rayvn.pkg" "${dir}/../share/"*/rayvn.pkg; do
            [[ -f "${pkg}" ]] || continue
            pname=$( gawk -F"'" '/^projectName=/{print $2; exit}' "${pkg}" 2>/dev/null )
            [[ "${pname}" == "${project}" ]] || continue
            libDir="${pkg%/*}/lib"
            [[ -d "${libDir}" ]] || continue
            for lib in "${libDir}"/*.sh; do
                [[ -f "${lib}" ]] && echo "${project}/$( basename "${lib}" .sh )"
            done
            return
        done
    done
}

_rayvn() {
    local cur prev words cword
    if declare -F _init_completion > /dev/null 2>&1; then
        _init_completion || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword="${COMP_CWORD}"
    fi

    local commands='new libraries functions test theme lint collisions dependencies index docs pages build release register projects'

    if (( cword == 1 )); then
        COMPREPLY=( $( compgen -W "${commands} -v --version -h --help" -- "${cur}" ) )
        return
    fi

    local projects
    case "${words[1]}" in
        new)
            [[ "${cword}" == 2 ]] && COMPREPLY=( $( compgen -W 'project script library test' -- "${cur}" ) )
            ;;
        docs)
            if (( cword == 2 )); then
                COMPREPLY=( $( compgen -W 'audit update' -- "${cur}" ) )
                return
            fi
            projects=$( _rayvn_projects )
            case "${words[2]}" in
                audit)  COMPREPLY=( $( compgen -W "--release ${projects}" -- "${cur}" ) ) ;;
                update) COMPREPLY=( $( compgen -W "--dry-run --regen --missing-only --stale-only --lib --since --delay ${projects}" -- "${cur}" ) ) ;;
                *)      COMPREPLY=( $( compgen -W "${projects}" -- "${cur}" ) ) ;;
            esac
            ;;
        functions)
            if [[ "${cur}" == */* ]]; then
                COMPREPLY=( $( compgen -W "$( _rayvn_libraries "${cur%%/*}" )" -- "${cur}" ) )
            else
                projects=$( _rayvn_projects )
                COMPREPLY=( $( compgen -W "--all ${projects}" -- "${cur}" ) )
            fi
            ;;
        test)
            projects=$( _rayvn_projects )
            COMPREPLY=( $( compgen -W "--nix --all ${projects}" -- "${cur}" ) )
            ;;
        lint)
            projects=$( _rayvn_projects )
            COMPREPLY=( $( compgen -W "--fix --ask ${projects}" -- "${cur}" ) )
            ;;
        dependencies)
            projects=$( _rayvn_projects )
            COMPREPLY=( $( compgen -W "--fix ${projects}" -- "${cur}" ) )
            ;;
        collisions | build | libraries | projects)
            projects=$( _rayvn_projects )
            COMPREPLY=( $( compgen -W "${projects}" -- "${cur}" ) )
            ;;
        pages)
            projects=$( _rayvn_projects )
            COMPREPLY=( $( compgen -W "--setup --record --publish --view --dir ${projects}" -- "${cur}" ) )
            ;;
        index)
            projects=$( _rayvn_projects )
            COMPREPLY=( $( compgen -W "-o -c --no-compact --no-hash --hash-file ${projects}" -- "${cur}" ) )
            ;;
        release)
            projects=$( _rayvn_projects )
            COMPREPLY=( $( compgen -W "--repo ${projects}" -- "${cur}" ) )
            ;;
        theme)
            COMPREPLY=( $( compgen -W '--show' -- "${cur}" ) )
            ;;
    esac
}

complete -F _rayvn rayvn
