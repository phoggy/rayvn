#!/usr/bin/env bash

# Library supporting sanitizing and sourcing env style files.
# Intended for use via: require 'rayvn/safe-env'

# require 'rayvn/core'

sourceSafeStaticVars() {
    local safeEnv
    local input="${1}"
    local prefixFilter="${2}"
    safeEnv="$(extractSafeStaticVars "${input}" "${prefixFilter}" | _globalizeDeclarations)" || fail
    source <(echo "${safeEnv}")
}

# extractSafeStaticVars() - Parse bash config files and extract only safe variable declarations
#
# This function processes bash files to extract variable declarations while ensuring
# no side effects can occur by filtering out:
# - All function definitions
# - All function calls
# - All variable declarations containing command substitutions
# - All comments
#
# Usage: extractSafeStaticVars <file_or_string> [prefix_filter]
# Output: Safe variable declarations that can be sourced

extractSafeStaticVars() {
    local input="${1}"
    local prefixFilter="${2}"
    local result
    [[ "${input}" ]] || fail "missing required input"

    result="$(_extractSafeStaticVarsOnly "${input}")" || fail

    if [[ ${prefixFilter} ]]; then
        result="$(_filterStaticVarsByPrefix "${result}" "${prefixFilter}")"
    fi

    echo "${result}"
}

UNSUPPORTED="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_extractSafeStaticVarsOnly() {
    local input="${1}"
    local buffer=""
    declare -i in_function=0
    declare -i brace_depth=0
    declare -i in_multiline_var=0
    declare -i skip_multiline=0
    declare -i in_multiline_string=0

    printf "\n%s\n\n" "# ---- begin safe static variables"

    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip empty lines and comments
        [[ -z "${line}" ]] && continue
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue

        # Remove inline comments
        local clean_line="${line%%#*}"
        clean_line="${clean_line%"${clean_line##*[![:space:]]}"}"

        # Skip if line becomes empty after comment removal
        [[ -z "${clean_line}" ]] && continue

        # Count braces for tracking depth
        local temp="${clean_line//[^\{]}"
        local open_braces=${#temp}
        temp="${clean_line//[^\}]}"
        local close_braces=${#temp}
        (( brace_depth += open_braces - close_braces ))

        # Detect function definitions
        if [[ "${clean_line}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([[:space:]]*\)[[:space:]]*\{ ]] ||
           [[ "${clean_line}" =~ ^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(\([[:space:]]*\))?[[:space:]]*\{ ]]; then
            in_function=1
            continue
        fi

        # Check if we're exiting a function
        if (( in_function )); then
            if (( brace_depth <= 0 )); then
                in_function=0
                brace_depth=0
            fi
            continue
        fi

        # Skip function calls (simple heuristic)
        if [[ "${clean_line}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*$ ]]; then
            continue
        fi

        # Skip if we're inside a block that's not a variable declaration
        if (( brace_depth > 0 )); then
            if [[ "${clean_line}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*= ]] ||
               [[ "${clean_line}" =~ ^[[:space:]]*declare[[:space:]] ]]; then
                # Variable inside a block, process it
                :
            else
                continue
            fi
        fi

        # Handle multiline variable continuation
        if (( in_multiline_var )); then
            if (( skip_multiline )); then
                if [[ "${clean_line}" == *\)* ]]; then
                    in_multiline_var=0
                    skip_multiline=0
                    buffer=""
                fi
                continue
            fi

            buffer+=$'\n'"${clean_line}"

            # Check for unsafe content
            if [[ "${clean_line}" == *'$('* ]] || [[ "${clean_line}" == *'`'* ]]; then
                skip_multiline=1
                buffer=""
                continue
            fi

            # Check if this ends the multiline variable
            if [[ "${clean_line}" == *\)* ]]; then
                echo "${buffer}"
                in_multiline_var=0
                buffer=""
            fi
            continue
        fi

        # Handle multiline string continuation
        if (( in_multiline_string )); then
            buffer+=$'\n'"${clean_line}"

            # Check for unsafe content
            if [[ "${clean_line}" == *'$('* ]] || [[ "${clean_line}" == *'`'* ]]; then
                in_multiline_string=0
                buffer=""
                continue
            fi

            # Check if string ends (unescaped quote)
            if [[ "${clean_line}" == *\" ]] && [[ "${clean_line}" != *\\\" ]]; then
                echo "${buffer}"
                in_multiline_string=0
                buffer=""
            fi
            continue
        fi

        # Check for start of multiline array
        if [[ "${clean_line}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\( ]] ||
           [[ "${clean_line}" =~ ^[[:space:]]*declare[[:space:]]+[^=]*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\( ]]; then

            # Count parentheses to check if it's complete on one line
            local open_count="${clean_line//[^\(]}"
            local close_count="${clean_line//[^\)]}"

            if [[ ${#open_count} -eq ${#close_count} ]]; then
                # Single line array
                if [[ "${clean_line}" == *'$('* ]] || [[ "${clean_line}" == *'`'* ]]; then
                    continue
                fi
                echo "${clean_line}"
            else
                # Multi-line array
                buffer="${clean_line}"
                if [[ "${clean_line}" == *'$('* ]] || [[ "${clean_line}" == *'`'* ]]; then
                    skip_multiline=1
                fi
                in_multiline_var=1
            fi
            continue
        fi

        # Check for start of multiline string
        if [[ "${clean_line}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\" ]] &&
           ([[ "${clean_line}" != *\" ]] || [[ "${clean_line}" == *\\\" ]]); then

            buffer="${clean_line}"
            if [[ "${clean_line}" == *'$('* ]] || [[ "${clean_line}" == *'`'* ]]; then
                buffer=""
                continue
            fi
            in_multiline_string=1
            continue
        fi

        # Check for regular variable declarations
        if [[ "${clean_line}" =~ ^[[:space:]]*(declare[[:space:]]+[^=]*[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*= ]] ||
           [[ "${clean_line}" =~ ^[[:space:]]*declare[[:space:]]+[^=]*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*$ ]]; then

            # Check for command substitutions
            if [[ "${clean_line}" == *'$('* ]] || [[ "${clean_line}" == *'`'* ]]; then
                continue
            fi

            echo "${clean_line}"
        fi

    done < <(
        if [[ -f "${input}" ]]; then
            cat -- "${input}"
        else
            printf '%s\n' "${input}"
        fi
    )

    printf "\n%s\n" "# ---- end safe static variables"
}


_globalizeDeclarations() {
    sed -E '
        /^(declare[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*)-g([a-zA-Z]*[[:space:]]+)?/b end
        s/^(declare[[:space:]]+-)([a-zA-Z]+)([[:space:]]+)/\1g\2\3/
        s/^(declare)([[:space:]]+)/\1 -g\2/

        :end

        /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\(/ {
            s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=\((.*)\)$/\1declare -g -a \2=(\3)/
        }
    '
}

_filterStaticVarsByPrefix() {
    local input="${1}"
    local prefix="${2}"

    [[ -f "${input}" ]] && input="$(<"${input}")"

    awk -v prefix="${prefix}" '
    BEGIN {
        collecting = 0
        buffer = ""
        parens = 0
    }

    function flush() {
        if (collecting) {
            print buffer
            collecting = 0
            buffer = ""
            parens = 0
        }
    }

    {
        line = $0
        stripped = line
        sub(/^[ \t]+/, "", stripped)

        if (stripped ~ /^#/ || stripped == "") {
            if (collecting) buffer = buffer "\n" line
            next
        }

        if (!collecting) {
            split(stripped, parts, "=")
            raw = parts[1]
            sub(/^(declare|typeset|local|export)[ \t]+/, "", raw)
            n = split(raw, tokens, /[ \t]+/)
            for (i = 1; i <= n; i++) {
                if (tokens[i] !~ /^-/) {
                    var = tokens[i]
                    break
                }
            }
            if (var ~ ("^" prefix)) {
                collecting = 1
                buffer = line
                if (line ~ /=\([ \t]*$/ || line ~ /\([ \t]*$/) {
                    parens++
                } else {
                    flush()
                }
            }
        } else {
            buffer = buffer "\n" line
            if (line ~ /\(/) parens++
            if (line ~ /\)/) parens--
            if (parens <= 0) flush()
        }
    }

    END { flush() }
    ' <<< "${input}"
}
