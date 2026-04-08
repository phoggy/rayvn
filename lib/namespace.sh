#!/usr/bin/env bash

# Detect namespace collisions across registered rayvn project libraries.
# Use via: require 'rayvn/namespace'

# ◇ Check for function and global variable name collisions across all (or specified) registered
#   rayvn project libraries. Reports each collision with its sources and returns 1 if any found.
#
# · USAGE
#
#   checkNamespaces [PROJECT...]
#
#   [PROJECT...]   Registered project names to check. Defaults to all registered projects.
#
# · NOTES
#
#   Globals detected: explicit declare -g* declarations (anywhere in the file). This is the
#   rayvn convention for intentional globals. Implicit globals inside functions (missing
#   local/declare) are caught by the lint implicit-global check.
#
#   _init_* functions are excluded: they are ephemeral init functions, not part of the namespace.

checkNamespaces() {
    local -a projects=("$@")
    (( ${#projects[@]} > 0 )) || _collectNamespaceProjects projects

    local -A functionMap=()
    local -A variableMap=()
    local -i collisions=0
    local project libFile libName qualifiedName libraryRoot

    for project in "${projects[@]}"; do
        libraryRoot="${_rayvnProjects[${project}${_libraryRootSuffix}]:-}"
        [[ -d "${libraryRoot}" ]] || continue
        for libFile in "${libraryRoot}"/*.sh; do
            [[ -f "${libFile}" ]] || continue
            libName="${ basename "${libFile}" .sh; }"
            qualifiedName="${project}/${libName}"
            _collectNamespaceFunctions "${libFile}" "${qualifiedName}" functionMap
            _collectNamespaceGlobals   "${libFile}" "${qualifiedName}" variableMap
        done
    done

    _reportNamespaceCollisions functionMap 'function' collisions
    _reportNamespaceCollisions variableMap 'variable' collisions

    if (( collisions == 0 )); then
        show success bold "No namespace collisions found"
    fi
    return $(( collisions > 0 ? 1 : 0 ))
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/namespace' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_namespace() {
    :
}

_collectNamespaceProjects() {
    local -n _nsProjectsRef="$1"
    local key
    for key in "${!_rayvnProjects[@]}"; do
        [[ "${key}" == *"${_projectRootSuffix}" ]] || continue
        _nsProjectsRef+=("${key%${_projectRootSuffix}}")
    done
}

_collectNamespaceFunctions() {
    local file="$1" qualifiedName="$2"
    local -n _nsFuncMapRef="$3"
    local name

    while IFS= read -r name; do
        [[ -n "${name}" ]] || continue
        if [[ -v _nsFuncMapRef["${name}"] ]]; then
            [[ " ${_nsFuncMapRef["${name}"]} " == *" ${qualifiedName} "* ]] || \
                _nsFuncMapRef["${name}"]+=" ${qualifiedName}"
        else
            _nsFuncMapRef["${name}"]="${qualifiedName}"
        fi
    done < <(gawk '
        /namespace-skip-start/ { skip=1; next }
        /namespace-skip-end/   { skip=0; next }
        skip { next }
        /^[[:space:]]*#/ { next }
        /namespace-ok/ { next }
        /^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)/ {
            match($0, /^([a-zA-Z_][a-zA-Z0-9_]*)/, m)
            if (m[1] !~ /^_init_/) print m[1]
        }
        /^function[[:space:]]/ {
            match($0, /^function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)/, m)
            if (m[1] != "" && m[1] !~ /^_init_/) print m[1]
        }
    ' "${file}")
}

_collectNamespaceGlobals() {
    local file="$1" qualifiedName="$2"
    local -n _nsVarMapRef="$3"
    local name

    while IFS= read -r name; do
        [[ -n "${name}" ]] || continue
        if [[ -v _nsVarMapRef["${name}"] ]]; then
            [[ " ${_nsVarMapRef["${name}"]} " == *" ${qualifiedName} "* ]] || \
                _nsVarMapRef["${name}"]+=" ${qualifiedName}"
        else
            _nsVarMapRef["${name}"]="${qualifiedName}"
        fi
    done < <(gawk '
        /namespace-skip-start/ { skip=1; next }
        /namespace-skip-end/   { skip=0; next }
        skip { next }
        /^[[:space:]]*#/ { next }
        /namespace-ok/ { next }
        # Explicit declare -g* anywhere — the rayvn convention for intentional globals.
        # Matches: declare -g, -gr, -gx, -grx, -gA, -ga, -gi, etc.
        /declare[[:space:]]+-[a-zA-Z]*g[a-zA-Z]*[[:space:]]/ {
            if (match($0, /declare[[:space:]]+-[a-zA-Z]+[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)/, m ))
                print m[1]
        }
    ' "${file}")
}

_reportNamespaceCollisions() {
    local -n _nsColMapRef="$1"
    local type="$2"
    local -n _nsCountRef="$3"
    local name sources
    local -a srcArray=()
    local -i headerPrinted=0

    for name in "${!_nsColMapRef[@]}"; do
        sources="${_nsColMapRef[${name}]}"
        read -ra srcArray <<< "${sources}"
        (( ${#srcArray[@]} > 1 )) || continue
        if (( !headerPrinted )); then
            show error "${type} collisions:"
            headerPrinted=1
        fi
        show bold "  ${name}" glue ':' dim " ${sources}"
        (( _nsCountRef++ ))
    done
}
