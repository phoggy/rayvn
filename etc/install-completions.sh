#!/usr/bin/env bash

# One-time setup, sourced by rayvn.up only when its own cheap check (a plain grep of
# ~/.bashrc plus a sentinel-file check, no function calls) finds that bash-completion isn't
# yet wired in. Kept out of rayvn.up itself — which is parsed on every invocation of every
# rayvn-based tool — so this rarely-exercised logic doesn't add to that cost once it's done
# its job. Requires rayvn/core (show, tildePath, configDirPath) to already be loaded, which
# it is by the time rayvn.up sources this.
#
# Ensures two things, each independently idempotent via its own check:
#
#  1. ~/.bash_profile sources ~/.bashrc — bash-completion's own documented recommendation:
#     interactive-only settings belong in ~/.bashrc, not ~/.bash_profile, since a nested
#     (non-login) interactive bash only reads ~/.bashrc; macOS doesn't create ~/.bashrc or
#     source it from ~/.bash_profile by default.
#
#  2. If bash-completion is installed, its bootstrap line is added to ~/.bashrc. If it isn't
#     installed at all, an informational note is shown once (tracked via a sentinel file,
#     since there's no line to grep for in that case) — completions still work either way;
#     rayvn's own are discovered by its dynamic loader once it is installed.

# Best-effort detection of whether the 'bash-completion' package (v1 or v2) is installed, by
# checking its well-known install locations rather than a PATH/binary check: it has no binary
# of its own to check (see nixSkipBinaryCheck in rayvn.pkg — it's a sourced shell library, not
# an executable). Checking whether _init_completion is already a function here would also not
# work: rayvn.up runs in a script subprocess, not the user's interactive login shell, so it
# would never see what that shell has actually sourced. Not exhaustive, just the common
# Homebrew/Linux/Nix locations. On success, and if a var name is given, sets it to the found
# bootstrap script's path (what ~/.bashrc needs to source).
_bashCompletionAvailable() {
    local _bcFoundDiscard=''
    local -n _bcFoundRef="${1:-_bcFoundDiscard}"
    local candidate candidates=(
        "${HOMEBREW_PREFIX:-}/etc/profile.d/bash_completion.sh"
        '/opt/homebrew/etc/profile.d/bash_completion.sh'
        '/usr/local/etc/profile.d/bash_completion.sh'
        '/usr/share/bash-completion/bash_completion'
        '/etc/profile.d/bash_completion.sh'
        '/etc/bash_completion'
    )
    for candidate in "${candidates[@]}"; do
        [[ -n "${candidate}" && -f "${candidate}" ]] && { _bcFoundRef="${candidate}"; return 0; }
    done
    if command -v brew &> /dev/null; then
        local brewPrefix; brewPrefix="${ brew --prefix 2> /dev/null; }"
        if [[ -n "${brewPrefix}" && -f "${brewPrefix}/etc/profile.d/bash_completion.sh" ]]; then
            _bcFoundRef="${brewPrefix}/etc/profile.d/bash_completion.sh"
            return 0
        fi
    fi
    local profileDir
    for profileDir in ${NIX_PROFILES:-}; do
        if [[ -f "${profileDir}/share/bash-completion/bash_completion" ]]; then
            _bcFoundRef="${profileDir}/share/bash-completion/bash_completion"
            return 0
        fi
    done
    return 1
}

_installBashCompletion() {
    local profileFile="${HOME}/.bash_profile"
    [[ -f "${profileFile}" ]] || return 0
    local bashrcFile="${HOME}/.bashrc"

    grep -qF '.bashrc' "${profileFile}" 2> /dev/null || {
        {
            echo ""
            echo "# Added by rayvn.up: source ~/.bashrc for interactive-only settings (e.g. bash-completion)"
            echo "[[ -f \"\${HOME}/.bashrc\" ]] && source \"\${HOME}/.bashrc\""
        } >> "${profileFile}" && \
        show "Added a" blue "${ tildePath "${bashrcFile}"; }" "source line to" blue "${ tildePath "${profileFile}"; }"
    }

    local bcPath
    if _bashCompletionAvailable bcPath; then
        grep -qF "${bcPath}" "${bashrcFile}" 2> /dev/null && return 0
        {
            echo ""
            echo "# Added by rayvn.up: enable bash-completion (tab completion for rayvn and other tools)"
            echo "[[ -r \"${bcPath}\" ]] && . \"${bcPath}\""
        } >> "${bashrcFile}" || return 0
        show "Added bash-completion to" blue "${ tildePath "${bashrcFile}"; }" \
            "— restart your shell (or open a new terminal) to enable tab completion."
    else
        declare -F configDirPath > /dev/null || return 0
        local sentinel; sentinel=${ configDirPath -p rayvn '.bash-completion-notice-shown'; }
        [[ -f "${sentinel}" ]] && return 0
        show warning "bash-completion doesn't appear to be installed" \
            "— completions will still work, but installing it" glue " (" glue bold "brew install bash-completion@2" \
            glue ")" "gives richer behavior, like completing" bold "--opt=value" primary "correctly."
        : > "${sentinel}"
    fi
}

_installBashCompletion
unset -f _installBashCompletion _bashCompletionAvailable
