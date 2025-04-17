#!/usr/bin/env bash

# Library supporting sanitizing and sourcing env style files.
# Intended for use via: require 'rayvn/safe-env'

require 'rayvn/core'

# Source an env file after striping all content except static variable declarations, with optional prefix filter.
sourceEnvFile() {
    local envFile="${1}"
    local prefixFilter="${2}"
    source <(extractStaticVars "${envFile}" "${prefixFilter}")
}

# Strip all content in an env file except static variable declarations.
# Optionally filter result by a required prefix.
extractStaticVars() {
    local envFile="${1}"
    local prefixFilter="${2:-}"
    assertFile ${envFile}
    if [[ ${prefixFilter} ]]; then
        _filterVarsByPrefix "${envFile}" "${prefixFilter}"
    else
        _extractStaticVarsOnly "${envFile}"
    fi
}

_filterVarsByPrefix() {
    local envFile="${1}"
    local prefix="${2}"

    _extractStaticVarsOnly "${envFile}" | awk -v prefix="${prefix}" '
        {
            # Skip comment lines
            if ($0 ~ /^[[:space:]]*#/) next

            # Match variable assignment at start of line
            if ($0 ~ /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=/) {
                varName = $1
                sub(/[[:space:]]*=.*/, "", varName)
                if (index(varName, prefix) == 1) {
                    print
                }
                next
            }

            # Match associative array declarations (e.g., declare -A map=...)
            if ($0 ~ /^[[:space:]]*declare[[:space:]]+-[aA]/) {
                split($0, parts, "=")
                # Get last word before '='
                sub(/.*[[:space:]]/, "", parts[1])
                varName = parts[1]
                if (index(varName, prefix) == 1) {
                    print
                }
            }
        }
    '
}

_extractStaticVarsOnly() {
    local envFile="${1}"
    local inHeredoc=0 heredocTag=""
    local inArray=0
    local buffer=""
    local line

    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Handle heredoc body
        if (( inHeredoc )); then
            buffer+=$'\n'"${line}"
            [[ "${line}" == "${heredocTag}" ]] && {
                echo "${buffer}"
                inHeredoc=0
                buffer=""
            }
            continue
        fi

        # Handle array continuation
        if (( inArray )); then
            buffer+=$'\n'"${line}"
            [[ "${line}" =~ \) ]] && {
                echo "${buffer}"
                inArray=0
                buffer=""
            }
            continue
        fi

        # Skip functions (detected by open brace or function keyword)
        [[ "${line}" =~ ^[[:space:]]*(function[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{ ]] && continue
        [[ "${line}" =~ ^[[:space:]]*\}[[:space:]]*$ ]] && continue

        # Heredoc detection
        if [[ "${line}" =~ '<<[-]?[A-Za-z_][A-Za-z0-9_]*' ]]; then
            heredocTag="${line##*<<}"
            heredocTag="${heredocTag//[[:space:]]/}"  # Trim spaces
            buffer="${line}"
            inHeredoc=1
            continue
        fi

        # Array start detection
        if [[ "${line}" =~ ^[[:space:]]*(declare[[:space:]]+-[aA][[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*=\\?\(* ]]; then
            buffer="${line}"
            if [[ ! "${line}" =~ \) ]]; then
                inArray=1
            else
                echo "${buffer}"
                buffer=""
            fi
            continue
        fi

        # Ignore subshells or commands in assignment
        if [[ "${line}" =~ =.*\$\(.+\) ]]; then
            continue
        fi

        # Handle continuation lines with \
        if [[ "${line}" =~ \\$ ]]; then
            buffer+="${line%\\}"
            continue
        fi

        # Simple assignment match
        if [[ "${buffer}${line}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*= ]]; then
            echo "${buffer}${line}"
        fi

        buffer=""
    done < "${envFile}"
}

