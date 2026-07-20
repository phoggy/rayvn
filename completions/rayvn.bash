#!/usr/bin/env bash

# Generated bash completion for the rayvn CLI — DO NOT EDIT.
# Regenerate via 'rayvn args bin/rayvn'.

__rayvnComplete() {
    local cur prev words cword
    if declare -F _init_completion > /dev/null 2>&1; then
        _init_completion || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword="${COMP_CWORD}"
    fi

    if (( cword == 1 )); then
        COMPREPLY=($(compgen -W "args build collisions deps dependencies functions index libraries lint new create pages projects register release test theme docs -v --version -h --help" -- "${cur}"))
        return
    fi

    case "${words[1]}" in
        docs)
            if (( cword == 2 )); then
                COMPREPLY=($(compgen -W "audit update" -- "${cur}"))
                return
            fi
            ;;
    esac

    case "${words[1]} ${words[2]:-}" in
        "docs audit")
            [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help --release -h" -- "${cur}")); return; }
            local _relIdx=$(( cword - 3 ))
            (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
            ;;
        "docs update")
            [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--delay --dry-run --help --lib --missing-only --regen --since --stale-only -h" -- "${cur}")); return; }
            local _relIdx=$(( cword - 3 ))
            (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
            ;;
        *)
            case "${words[1]}" in
                args)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--check --help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx == 0 )) && { COMPREPLY=($(compgen -f -- "${cur}")); return; }
                    ;;
                build)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
                    ;;
                collisions)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
                    ;;
                deps | dependencies)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--fix --help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
                    ;;
                functions)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--all --help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    ;;
                index)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--compact --hash-file --help --no-compact --no-hash --output -c -h -o" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
                    ;;
                libraries)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
                    ;;
                lint)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--ask --fix --help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
                    ;;
                new | create)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help --local -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx == 0 )) && { COMPREPLY=($(compgen -W "project script library test" -- "${cur}")); return; }
                    ;;
                pages)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--dir --help --publish --record --setup --view -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx == 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
                    ;;
                projects)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    (( _relIdx >= 0 )) && { declare -F __rayvnCompletionProjects > /dev/null && COMPREPLY=($(compgen -W "$(__rayvnCompletionProjects)" -- "${cur}")); return; }
                    ;;
                register)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    ;;
                release)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    ;;
                test)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--all --help --nix -h" -- "${cur}")); return; }
                    local _relIdx=$(( cword - 2 ))
                    ;;
                theme)
                    [[ "${cur}" == -* ]] && { COMPREPLY=($(compgen -W "--help --show -h" -- "${cur}")); return; }
                    ;;
            esac
            ;;
    esac
}

complete -F __rayvnComplete rayvn
