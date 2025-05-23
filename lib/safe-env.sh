#!/usr/bin/env bash

# Library supporting sanitizing and sourcing env style files.
# Intended for use via: require 'rayvn/safe-env'

require 'rayvn/core'

# Strip all dynamic code content, keeping only safe static variable declarations, with optional prefix filtering,
# and source the result.
# Arg 1: path to an existing file or a string.
# Arg 2: optional prefix filter. If present, vars without that prefix will be stripped.
sourceSafeStaticVars() {
    local safeEnv
    local input="${1}"
    local prefixFilter="${2}"
    safeEnv="$(extractSafeStaticVars "${input}" "${prefixFilter}" | _globalizeDeclarations)" || fail
    source <(echo "${safeEnv}")
}

# Strip all dynamic code content, keeping only safe static variable declarations, with optional prefix filtering.
# Arg 1: path to an existing file or a string.
# Arg 2: optional prefix filter. If present, vars without that prefix will be stripped.
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

# Generated by ChatGPT (with lots of input and iterations!).
_extractSafeStaticVarsOnly() {
    local input="${1}"
    printf "\n%s\n\n" "# ---- begin safe static variables"
    local buffer=() insideString=0 insideParen=0 unsafe=0

    _isUnsafeLine() {
        local text="${1}"
        local regex='(\$\(\(|\$\(|\\|`|<<|<\(|>\(|[[:space:]]eval[[:space:]]|[[:space:]]let[[:space:]])'
        [[ "${text}" =~ $regex ]]
    }

    _isVarDeclStart() {
        [[ "${1}" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*= ]] || \
        [[ "${1}" =~ ^[[:space:]]*declare[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*[a-zA-Z_][a-zA-Z0-9_]*= ]]
    }

    _readInput() {
        if [[ -f "${input}" ]]; then
            cat -- "${input}"
        else
            printf '%s\n' "${input}"
        fi
    }

    _emitBufferIfSafe() {
        if (( ${#buffer[@]} )) && (( ! unsafe )); then
            local joined
            joined="$(printf '%s\n' "${buffer[@]}")"
            if _isVarDeclStart "${joined}" && ! _isUnsafeLine "${joined}"; then
                printf '%s\n' "${joined}"
            fi
        fi
        buffer=()
        unsafe=0
        insideString=0
        insideParen=0
    }

    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ "${line}" =~ ^[[:space:]]*$ ]] && continue

        if (( insideString || insideParen )); then
            buffer+=("${line}")
            _isUnsafeLine "${line}" && unsafe=1

            # Track parens and quotes
            [[ "${line}" =~ \) ]] && (( insideParen-- ))

            # Count unescaped quotes (") in the line
            quoteCount=$(grep -o '\(^\|[^\\]\)"' <<< "${line}" | wc -l)
            (( quoteCount % 2 != 0 )) && (( insideString = 1 - insideString ))

            if (( insideString == 0 && insideParen == 0 )); then
                _emitBufferIfSafe
            fi
            continue
        fi

        if _isVarDeclStart "${line}"; then
            buffer=("${line}")
            unsafe=0
            _isUnsafeLine "${line}" && unsafe=1

            # Track quote and paren state
            quoteCount=$(grep -o '\(^\|[^\\]\)"' <<< "${line}" | wc -l)
            (( quoteCount % 2 != 0 )) && (( insideString = 1 - insideString ))

            [[ "${line}" =~ \( ]] && ! [[ "${line}" =~ \) ]] && (( insideParen++ ))

            if (( insideString == 0 && insideParen == 0 )); then
                _emitBufferIfSafe
            fi
        else
            _emitBufferIfSafe  # flush leftovers when hitting non-declaration
        fi
    done < <(_readInput)

    _emitBufferIfSafe  # flush any remaining buffer
    printf "\n%s\n" "# ---- end safe static variables"
}

# Filter to convert local variables global.
# Generated by ChatGPT

# Promote declare lines to use -g (if not already included) AND
# Convert raw array assignments (e.g., foo=(...)) to declare -g -a foo=(...)
_globalizeDeclarations() {
    sed -E '
        # If declare already contains -g (in any position), skip (no change)
        /^(declare[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*)-g([a-zA-Z]*[[:space:]]+)?/b end

        # Add -g to existing flags
        s/^(declare[[:space:]]+-)([a-zA-Z]+)([[:space:]]+)/\1g\2\3/

        # If no flags, insert -g after declare
        s/^(declare)([[:space:]]+)/\1 -g\2/

        :end

        # Convert raw array assignment to declare -g -a
        /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=\(/ {
            s/^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=\((.*)\)$/\1declare -g -a \2=(\3)/
        }
    '
}

# Filters variable declarations to return only those with a given prefix.
# Generated by ChatGPT (with lots of input and iterations!).
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

            # Remove any declare/local/etc.
            sub(/^(declare|typeset|local|export)[ \t]+/, "", raw)

            # Find first non-flag token as var name
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

                # Detect multiline declaration opening
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
