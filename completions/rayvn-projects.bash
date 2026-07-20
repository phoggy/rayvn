#!/usr/bin/env bash

# Shared bash completion support for rayvn ecosystem development. Hand-maintained, not
# generated: defines __rayvnCompletionProjects(), used by each project's own generated
# completions/<project>.bash to complete PROJECT-name positionals, then sources rayvn's own
# completions (always present, alongside this file) plus every other rayvn-based project's
# completions file, discovered via ~/.config/rayvn/projects/ (one file per project, named for
# the project, containing its root path) rather than a hardcoded list — so any project you've
# run at least once (valt, wardn, or one that doesn't exist yet) is picked up automatically.
# That directory is maintained by rayvn.up; see there. Auto-installed by rayvn.up, which
# appends a line sourcing this file to ~/.bash_profile the first time it's missing.
#
# Names in this file use a '__' prefix rather than rayvn's usual single-underscore 'private
# function' convention, since this file (and every generated completions/<project>.bash it
# sources) is loaded directly into the user's interactive shell, outside rayvn.up's
# require()/collision-detection machinery — a name collision here wouldn't be caught the way
# it would be between two libraries loaded via require(). '__' is unused elsewhere in
# rayvn/valt/wardn, so it's collision-free by construction.

# Scan PATH for rayvn project roots (dev layout: <root>/bin/, Nix layout: <prefix>/bin/ with
# rayvn.pkg under share/) and output their project names, one per line.
__rayvnCompletionProjects() {
    local dir pkg IFS=:
    for dir in $PATH; do
        [[ -d "${dir}" ]] || continue
        for pkg in "${dir}/../rayvn.pkg" "${dir}/../share/"*/rayvn.pkg; do
            [[ -f "${pkg}" ]] && gawk -F"'" '/^projectName=/{print $2; exit}' "${pkg}" 2>/dev/null
        done
    done | sort -u
}

# rayvn is always present alongside this file; no lookup needed
_rayvnCompletionsFile="$( dirname "${BASH_SOURCE[0]}" )/rayvn.bash"
[[ -f "${_rayvnCompletionsFile}" ]] && source "${_rayvnCompletionsFile}"
unset _rayvnCompletionsFile

# Every other project seen at least once by rayvn.up on this machine
_rayvnKnownProjectsDir="${HOME}/.config/rayvn/projects"
if [[ -d "${_rayvnKnownProjectsDir}" ]]; then
    for _rayvnKnownProjectFile in "${_rayvnKnownProjectsDir}"/*; do
        [[ -f "${_rayvnKnownProjectFile}" ]] || continue
        _rayvnKnownProjectName="${_rayvnKnownProjectFile##*/}"
        [[ "${_rayvnKnownProjectName}" != rayvn ]] || continue
        read -r _rayvnKnownProjectRoot < "${_rayvnKnownProjectFile}"
        _rayvnCompletionsFile="${_rayvnKnownProjectRoot}/completions/${_rayvnKnownProjectName}.bash"
        [[ -f "${_rayvnCompletionsFile}" ]] && source "${_rayvnCompletionsFile}"
    done
fi
unset _rayvnKnownProjectsDir _rayvnKnownProjectFile _rayvnKnownProjectName _rayvnKnownProjectRoot _rayvnCompletionsFile
