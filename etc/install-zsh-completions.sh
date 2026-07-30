#!/usr/bin/env bash

# One-time setup, sourced by rayvn.up only when its own cheap check (a plain grep of
# ~/.zshrc, no function calls) finds that rayvn's zsh completions directory isn't yet on
# $fpath. Kept out of rayvn.up itself — which is parsed on every invocation of every
# rayvn-based tool — so this rarely-exercised logic doesn't add to that cost once it's done
# its job. Requires rayvn/core (show, tildePath) to already be loaded, which it is by the
# time rayvn.up sources this.
#
# Unlike bash-completion, zsh's completion system (compinit/compdef) ships with zsh itself —
# there's no third-party package to detect or recommend installing, and no login-vs-interactive
# startup-file split to work around the way bash has on macOS (zsh reads ~/.zshrc for any
# interactive shell, login or not). This only needs to ensure two things, each independently
# idempotent via its own check:
#
#  1. rayvn's shared zsh-completions directory is on $fpath, so compinit's autoload scan
#     finds the '_<project>' completion functions updateParser symlinks in there.
#  2. compinit is actually called, since a bare zsh install doesn't call it by default (most
#     setups — oh-my-zsh, prezto, manual configs — already do; this is a harmless no-op
#     re-run for those, compinit is idempotent).

_installZshCompletion() {
    local zshrcFile="${HOME}/.zshrc"
    [[ -f "${zshrcFile}" ]] || return 0

    # Single-quoted: this literal '${XDG_DATA_HOME:-$HOME/.local/share}' text is meant to be
    # expanded by zsh itself at shell-startup time, not by this bash script right now.
    local zshCompDir='${XDG_DATA_HOME:-$HOME/.local/share}/rayvn/zsh-completions'

    if ! grep -qF 'rayvn/zsh-completions' "${zshrcFile}" 2> /dev/null; then
        {
            echo ""
            echo "# Added by rayvn.up: put rayvn's zsh completions on fpath"
            echo "fpath=(\"${zshCompDir}\" \$fpath)"
        } >> "${zshrcFile}" && \
        show "Added rayvn's zsh completions directory to" blue "${ tildePath "${zshrcFile}"; }" \
            "— restart your shell (or open a new terminal) to enable tab completion."
    fi

    if ! grep -qw 'compinit' "${zshrcFile}" 2> /dev/null; then
        {
            echo ""
            echo "# Added by rayvn.up: enable zsh's completion system"
            echo "autoload -Uz compinit && compinit"
        } >> "${zshrcFile}" && \
        show "Added" blue "compinit" "to" blue "${ tildePath "${zshrcFile}"; }"
    fi
}

_installZshCompletion
unset -f _installZshCompletion
