#!/usr/bin/env bash

# Sanitize and source env style files.
# Use via: require 'rayvn/config'

# ◇ Source only safe, static variable declarations from a config file or string into the current env.
#
# · ARGS
#
#   input (string)         Path to a config file or a raw bash string to parse.
#   prefixFilter (string)  Optional variable name prefix to restrict which vars are sourced.

sourceConfigFile() {
    local safeEnv
    local input="$1"
    local prefixFilter="$2"
    safeEnv="${ extractSafeStaticVars "${input}" "${prefixFilter}" | _globalizeDeclarations; }" || fail
    source <(echo "${safeEnv}")
}

# ◇ Parse a bash config file or string, extracting only safe static variable declarations.
#   Filters out function definitions, function calls, command substitutions, and comments.
#
# · ARGS
#
#   input (string)         String or file path containing bash variable declarations to parse.
#   prefixFilter (string)  Only include variables matching this prefix (optional).

extractSafeStaticVars() {
    local input="$1"
    local prefixFilter="$2"
    local result
    [[ "${input}" ]] || fail "missing required input"

    result="${ _extractSafeStaticVarsOnly "${input}"; }" || fail

    if [[ -n ${prefixFilter} ]]; then
        result="${ _filterStaticVarsByPrefix "${result}" "${prefixFilter}"; }"
    fi

    echo "${result}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/config' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_config() {
    :
}

# Written by Claude Sonnet 4
_extractSafeStaticVarsOnly() {
    local input="$1"
    local buffer=""
    declare -i inFunction=0
    declare -i braceDepth=0
    declare -i inMultilineVar=0
    declare -i skipMultiline=0
    declare -i inMultilineString=0

    printf "\n%s\n\n" "# ---- begin safe static variables"

    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Skip empty lines and comments
        [[ -z "${line}" ]] && continue
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue

        # Remove inline comments
        local cleanLine="${line%%#*}"
        cleanLine="${cleanLine%"${cleanLine##*[![:space:]]}"}"

        # Skip if line becomes empty after comment removal
        [[ -z "${cleanLine}" ]] && continue

        # Count braces for tracking depth
        local temp="${cleanLine//[^\{]}"
        local openBraces=${#temp}
        temp="${cleanLine//[^\}]}"
        local closeBraces=${#temp}
        (( braceDepth += openBraces - closeBraces ))

        # Detect function definitions
        if [[ "${cleanLine}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([[:space:]]*\)[[:space:]]*\{ ]] ||
           [[ "${cleanLine}" =~ ^[[:space:]]*function[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(\([[:space:]]*\))?[[:space:]]*\{ ]]; then # lint-ok
            inFunction=1
            continue
        fi

        # Check if we're exiting a function
        if (( inFunction )); then
            if (( braceDepth <= 0 )); then
                inFunction=0
                braceDepth=0
            fi
            continue
        fi

        # Skip function calls (simple heuristic)
        if [[ "${cleanLine}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*$ ]]; then
            continue
        fi

        # Skip if we're inside a block that's not a variable declaration
        if (( braceDepth > 0 )); then
            if [[ "${cleanLine}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*= ]] ||
               [[ "${cleanLine}" =~ ^[[:space:]]*declare[[:space:]] ]]; then
                # Variable inside a block, process it
                :
            else
                continue
            fi
        fi

        # Handle multiline variable continuation
        if (( inMultilineVar )); then
            if (( skipMultiline )); then
                if [[ "${cleanLine}" == *\)* ]]; then
                    inMultilineVar=0
                    skipMultiline=0
                    buffer=""
                fi
                continue
            fi

            buffer+=$'\n'"${cleanLine}"

            # Check for unsafe content
            if [[ "${cleanLine}" == *'$('* ]] || [[ "${cleanLine}" == *'`'* ]] || [[ "${cleanLine}" == *'${ '* ]]; then # lint-ok
                skipMultiline=1
                buffer=""
                continue
            fi

            # Check if this ends the multiline variable
            if [[ "${cleanLine}" == *\)* ]]; then
                echo "${buffer}"
                inMultilineVar=0
                buffer=""
            fi
            continue
        fi

        # Handle multiline string continuation
        if (( inMultilineString )); then
            buffer+=$'\n'"${cleanLine}"

            # Check for unsafe content
            if [[ "${cleanLine}" == *'$('* ]] || [[ "${cleanLine}" == *'`'* ]] || [[ "${cleanLine}" == *'${ '* ]]; then # lint-ok
                inMultilineString=0
                buffer=""
                continue
            fi

            # Check if string ends (unescaped quote)
            if [[ "${cleanLine}" == *\" ]] && [[ "${cleanLine}" != *\\\" ]]; then
                echo "${buffer}"
                inMultilineString=0
                buffer=""
            fi
            continue
        fi

        # Check for start of multiline array
        if [[ "${cleanLine}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\( ]] ||
           [[ "${cleanLine}" =~ ^[[:space:]]*declare[[:space:]]+[^=]*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\( ]]; then

            # Count parentheses to check if it's complete on one line
            local openCount="${cleanLine//[^\(]}"
            local closeCount="${cleanLine//[^\)]}"

            if (( ${#openCount} == ${#closeCount} )); then
                # Single line array
                if [[ "${cleanLine}" == *'$('* ]] || [[ "${cleanLine}" == *'`'* ]] || [[ "${cleanLine}" == *'${ '* ]]; then # lint-ok
                    continue
                fi
                echo "${cleanLine}"
            else
                # Multi-line array
                buffer="${cleanLine}"
                if [[ "${cleanLine}" == *'$('* ]] || [[ "${cleanLine}" == *'`'* ]] || [[ "${cleanLine}" == *'${ '* ]]; then # lint-ok
                    skipMultiline=1
                fi
                inMultilineVar=1
            fi
            continue
        fi

        # Check for start of multiline string
        if [[ "${cleanLine}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\" ]] &&
           ([[ "${cleanLine}" != *\" ]] || [[ "${cleanLine}" == *\\\" ]]); then

            buffer="${cleanLine}"
            if [[ "${cleanLine}" == *'$('* ]] || [[ "${cleanLine}" == *'`'* ]] || [[ "${cleanLine}" == *'${ '* ]]; then # lint-ok
                buffer=""
                continue
            fi
            inMultilineString=1
            continue
        fi

        # Check for regular variable declarations
        if [[ "${cleanLine}" =~ ^[[:space:]]*(declare[[:space:]]+[^=]*[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*= ]] ||
           [[ "${cleanLine}" =~ ^[[:space:]]*declare[[:space:]]+[^=]*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*$ ]]; then

            # Check for command substitutions
            if [[ "${cleanLine}" == *'$('* ]] || [[ "${cleanLine}" == *'`'* ]] || [[ "${cleanLine}" == *'${ '* ]]; then # lint-ok
                continue
            fi

            echo "${cleanLine}"
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

# Written by ChatGPT 4o
_globalizeDeclarations() {
    gsed -E '
        /^(declare[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*)-g([a-zA-Z]*[[:space:]]+)?/b end
        s/^(declare[[:space:]]+-)([a-zA-Z]+)([[:space:]]+)/\1g\2\3/
        t end
        s/^(declare)([[:space:]]+)/\1 -g\2/

        :end

        /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\(/ {
            s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=\(( .*)\)$/\1declare -g -a \2=(\3)/
        }
    '
}

# Written by ChatGPT 4o
_filterStaticVarsByPrefix() {
    local input="$1"
    local prefix="$2"

    [[ -f "${input}" ]] && input="${ <"${input}"; }"

    gawk -v prefix="${prefix}" '
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
            if (var ~ ("^" prefix )) {
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
