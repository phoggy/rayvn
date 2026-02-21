#!/usr/bin/env bash
# shellcheck disable=SC2155

# Test case support library.
# Intended for use via: require 'rayvn/test'

### assert functions ----------------------------------------------------------------------------------------

# Fail if a pattern is found in a file.
# Args: match file
#
#   match - grep pattern that must NOT be present
#   file  - path to the file to search
assertNotInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null && fail "'${match}' found in file ${file}."
}

# Fail if a pattern is not found in a file.
# Args: match file
#
#   match - grep pattern that must be present
#   file  - path to the file to search
assertInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null 2>&1  || fail "'${match}' not found in file ${file}."
}

# Fail if two values are not equal (string comparison).
# Args: expected actual [message]
#
#   expected - expected value
#   actual   - actual value to compare
#   message  - optional custom failure message
assertEqual() {
    local msg="${3:-"assert '${1}' == '${2}' failed"}"
    [[ ${1} == "${2}" ]] || fail "${msg}"
}

# Fail if expected does not equal actual after stripping ANSI escape codes from actual.
# Args: expected actual [message]
#
#   expected - expected plain-text value
#   actual   - actual value (may contain ANSI codes; they are stripped before comparison)
#   message  - optional custom failure message
assertEqualStripped() {
    local expected="${1}"
    local actual="${2}"
    local msg="${3:-"assertEqualStripped failed"}"
    assertEqual "${expected}" "${ stripAnsi "${actual}"; }" "${msg}"
}

# Fail if expected does not equal actual; on failure, shows both values with cat -v escapes visible.
# Args: expected actual [message]
#
#   expected - expected value (may contain escape codes)
#   actual   - actual value to compare
#   message  - optional custom failure message
assertEqualEscapeCodes() {
    local expected="${1}"
    local actual="${2}"
    local msg="${3:-"assertEqualEscapeCodes failed"}"
    if [[ ${actual} != "${expected}" ]]; then
        echo "    Expected (visible): ${ echo -n "${expected}" | cat -v; }"
        echo "    Actual (visible):   ${ echo -n "${actual}" | cat -v; }"
        fail "${msg}"
    fi
}

# Fail with a message if a command exits non-zero.
# Args: message command [args...]
#
#   message - failure message to display
#   command - command and arguments to execute
assertTrue() {
    local msg="${1}"
    shift
    "${@}" || fail "${msg}"
}

# Fail with a message if a command exits zero.
# Args: message command [args...]
#
#   message - failure message to display
#   command - command and arguments to execute
assertFalse() {
    local msg="${1}"
    shift
    "${@}" && fail "${msg}"
    return 0
}

# Fail if actual does not contain expected as a substring.
# Args: expected actual [message]
#
#   expected - substring that must be present in actual
#   actual   - value to search within
#   message  - optional custom failure message
assertContains() {
    local expected="${1}"
    local actual="${2}"
    local msg="${3:-"assertContains: '${expected}' not in '${actual}'"}"
    [[ ${actual} == *"${expected}"* ]] || fail "${msg}"
}

# Fail if a numeric value is not within an inclusive range.
# Args: value min max [message]
#
#   value   - numeric value to check
#   min     - minimum allowed value (inclusive)
#   max     - maximum allowed value (inclusive)
#   message - optional custom failure message
assertInRange() {
    local value="${1}"
    local min="${2}"
    local max="${3}"
    local msg="${4:-"assertInRange: ${value} not in ${min}..${max}"}"
    (( value >= min && value <= max )) || fail "${msg}"
}

# Fail if two values are not equal (case-insensitive comparison).
# Args: expected actual [message]
#
#   expected - expected value (compared case-insensitively)
#   actual   - actual value to compare
#   message  - optional custom failure message
assertEqualIgnoreCase() {
    assertEqual "${1,,}" "${2,,}" "${3:-"assert ${1} == ${2} ignore case failed"}"
}

# Fail if an executable is found in PATH.
# Args: executable
#
#   executable - name of the command that must NOT be in PATH
assertNotInPath() {
    local executable="${1}"
    local path="${ command -v ${executable}; }"
    [[ ${path} == '' ]] || fail "${executable} was found in PATH at ${path}"
}

# Fail if an executable is not found in PATH, or if found at an unexpected path.
# Args: executable [expectedPath]
#
#   executable   - name of the command that must be in PATH
#   expectedPath - optional expected resolved path (symlinks followed)
assertInPath() {
    local executable="${1}"
    local expectedPath="${2}"
    local foundPath="${ command -v ${executable}; }"
    [[ ${foundPath} ]] || fail "${executable} was not found in PATH"
    assertFile "${foundPath}"
    local realPath="${ realpath ${foundPath}; }"

    if [[ ${expectedPath} ]]; then
        if [[ ${realPath} == "${foundPath}" ]]; then
            if [[ ${foundPath} != "${expectedPath}" ]]; then
                fail "${executable} found at ${foundPath}, expected ${expectedPath}"
            fi
        elif ! [[ ${foundPath} == "${expectedPath}" || ${realPath} == "${expectedPath}" ]]; then
            fail "${executable} found at ${foundPath} --> ${realPath}, expected ${expectedPath}"
        fi
    fi
}

# Fail if a function with the given name is currently defined.
# Args: name
#
#   name - function name that must NOT be defined
assertFunctionIsNotDefined() {
    local name="${1}"
    [[ ${ declare -f "${name}" 2> /dev/null; } ]] && fail "${name} is defined: ${ declare -f ${name}; }"
}

# Fail if a variable with the given name is currently defined.
# Args: name
#
#   name - variable name that must NOT be defined
assertVarIsNotDefined() {
    local name="${1}"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] && fail "${name} is defined: ${ declare -f ${name}; }"
}

# Fail if a function with the given name is not currently defined.
# Args: name
#
#   name - function name that must be defined
assertFunctionIsDefined() {
    local name="${1}"
    [[ ${ declare -f "${name}" 2> /dev/null; } ]] || fail "${name} is not defined"
}

# Fail if a variable with the given name is not currently defined.
# Args: name
#
#   name - variable name that must be defined
assertVarIsDefined() {
    local name="${1}"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] || fail "${name} is not defined"
}


# Fail if a variable's declare flags do not match the expected set (order-independent).
# Args: varName expectedFlags
#
#   varName       - name of the variable to inspect
#   expectedFlags - expected declare flags as a string (e.g. "ir", "r", "arx", "A")
assertVarType() {
    local varName="${1}"
    local expectedFlags="${2}"  # e.g. "ir", "r", "arx", "A"

    local declaration
    if ! declaration="${ declare -p "${varName}" 2> /dev/null; }"; then
        fail "${varName} is not defined"
    fi

    local actualFlags="${declaration#*-}"
    actualFlags="${actualFlags% *}"

    local sortedExpected sortedActual
    sortedExpected="${ echo "${expectedFlags}" | grep -o . | sort | tr -d '\n'; }"
    sortedActual="${ echo "${actualFlags}" | grep -o . | sort | tr -d '\n'; }"

    if [[ "${sortedExpected}" != "${sortedActual}" ]]; then
        fail "${varName} has -${sortedActual}, expected -${sortedExpected}"
    fi
}

# Fail if a variable's value does not equal the expected string.
# Args: varName expected
#
#   varName  - name of the variable to check
#   expected - expected string value
assertVarEquals() {
    local varName="${1}"
    local expected="${2}"
    local -n varRef="${varName}"
    assertVarIsDefined "${varName}"
    if [[ ${varRef} != "${expected}" ]]; then
        fail "${varName}=${varRef}, expected ${expected}"
    fi
}

# Fail if a variable's value does not contain the expected substring.
# Args: varName expected
#
#   varName  - name of the variable to check
#   expected - substring that must be present in the variable's value
assertVarContains() {
    local varName="${1}"
    local expected="${2}"
    local -n varRef="${varName}"
    assertVarIsDefined "${varName}"
    if [[ ${varRef} != *"${expected}"* ]]; then
        fail "${varName}=${varRef}, expected ${expected}"
    fi
}

# Fail if an indexed array's elements do not exactly match the expected values.
# Args: varName [element...]
#
#   varName  - name of the indexed array variable to check
#   element  - zero or more expected element values in order
assertArrayEquals() {
    local varName="${1}"
    local expected=("${@:2}")
    local -n arrayRef="${varName}"
    assertVarIsDefined "${varName}"
    local arrayLen=${#arrayRef[@]}
    local expectedLen=${#expected[@]}
    if (( arrayLen == expectedLen )); then
        for (( i=0; i < arrayLen; i++ )); do
            if [[ ${arrayRef[${i}]} != "${expected[${i}]}" ]]; then
                fail "${varName}[${i}]=${arrayRef[${i}]}, expected ${expected[${i}]}"
            fi
        done
    else
        fail "${varName} length=${arrayLen}, expected ${expectedLen}"
    fi
}

# Fail if a variable is not defined as an associative array (hash table).
# Args: varName
#
#   varName - name of the variable that must be a defined associative array
assertHashTableIsDefined() {
    local varName=${1}
    assertVarIsDefined ${varName}
    [[ "${ declare -p ${varName} 2>/dev/null; }" =~ "declare -A" ]] || fail "${varName} is not a hash table"
}

# Fail if an associative array variable is currently defined.
# Args: varName
#
#   varName - name of the variable that must NOT be defined
assertHashTableIsNotDefined() {
    local varName=${1}
    assertVarIsNotDefined ${varName}
}

# Fail if a key is not present in an associative array.
# Args: varName keyName
#
#   varName - name of the associative array variable
#   keyName - key that must be defined in the array
assertHashKeyIsDefined() {
    local varName="${1}"
    local keyName="${2}"

    assertHashTableIsDefined "${varName}"
    [[ -v ${varName}[${keyName}] ]] || fail "${varName}[${keyName}] is NOT defined"
}

# Fail if a key is present in an associative array.
# Args: varName keyName
#
#   varName - name of the associative array variable
#   keyName - key that must NOT be defined in the array
assertHashKeyIsNotDefined() {
    local varName="${1}"
    local keyName="${2}"
    [[ -v ${varName}[${keyName}] ]] && fail "${varName}[${keyName}] is defined"
}

# Fail if the value at a key in an associative array does not equal the expected value.
# Args: varName keyName expectedValue
#
#   varName       - name of the associative array variable
#   keyName       - key to look up
#   expectedValue - expected value for that key
assertHashValue() {
    local varName="${1}"
    local keyName="${2}"
    local expectedValue="${3}"
    assertHashKeyIsDefined "${varName}" "${keyName}"

    local actualValue="${ eval echo \$"{${varName}[${keyName}]}"; }" # complexity required to use variables for var and key
    [[ ${actualValue} == "${expectedValue}" ]] || fail "${varName}[${keyName}]=${actualValue}, expected '${expectedValue}"
}

### PATH functions ----------------------------------------------------------------------------------------

# Prepend a directory to a PATH-style variable, removing any existing occurrence first.
# Args: path [pathVariable]
#
#   path         - directory to prepend
#   pathVariable - name of the colon-separated path variable (default: PATH)
prependPath () {
    local path="${1}"
    local pathVariable=${2:-PATH}
    removePath "${path}" ${pathVariable}
    declare -gx ${pathVariable}="${path}${!pathVariable:+:${!pathVariable}}"
}

# Append a directory to a PATH-style variable, removing any existing occurrence first.
# Args: path [pathVariable]
#
#   path         - directory to append
#   pathVariable - name of the colon-separated path variable (default: PATH)
appendPath () {
    local path="${1}"
    local pathVariable=${2:-PATH}
    removePath "${path}" ${pathVariable}
    declare -gx  ${pathVariable}="${!pathVariable:+${!pathVariable}:}${path}"
}

# Remove all occurrences of a directory from a PATH-style variable.
# Args: path [pathVariable]
#
#   path         - directory to remove
#   pathVariable - name of the colon-separated path variable (default: PATH)
removePath () {
    local removePath="${1}"
    local pathVariable=${2:-PATH}
    local dir newPath paths
    IFS=':' read -ra paths <<< "${!pathVariable}"

    shopt -s nocasematch
    for dir in "${paths[@]}" ; do
        if [[ "${dir}" != "${removePath}" ]] ; then
            newPath="${newPath:+$newPath:}${dir}"
        fi
    done
    shopt -u nocasematch

    declare -gx  ${pathVariable}="${newPath}"
}

# Print a PATH-style variable with each directory on its own numbered line.
# Args: [pathVariable]
#
#   pathVariable - name of the colon-separated path variable to display (default: PATH)
printPath() {
    local pathVariable=${1:-PATH}
    if [[ ${!pathVariable} ]]; then
        echo
        echo "${pathVariable} search order:"
        echo $PATH | tr ':' '\n' | nl
        echo
    else
        echo "'${pathVariable}' is not defined"
    fi
}

# Register a rayvn project root for use in tests, resolving symlinks and verifying the directory.
# Returns 1 if the project is already registered with the same root; fails if registered with a different root.
# Args: projectName projectRoot
#
#   projectName - short name for the project (e.g. 'valt')
#   projectRoot - absolute or relative path to the project's root directory
addRayvnProject() {
    local projectName="${1}"
    local projectRoot="${2}"
    assertDirectory "${projectRoot}"
    projectRoot="${ realpath "${projectRoot}"; }" || fail "Could not resolve real path of: ${projectRoot}"
    local existing="${_rayvnProjects["${projectName}::project"]}"
    if [[ -n "${existing}" ]]; then
        if [[ ${existing} == "${projectRoot}" ]]; then \
            return 1 # already present
        else
          fail "project '${projectName}' present with root=${existing}, cannot reset root to ${projectRoot}"
        fi
    else

        # Add project root
        _rayvnProjects[${projectName}${_projectRootSuffix}]="${projectRoot}"

        # Add library root if it exists. First, adjust for nix if needed
        local resourceRoot="${projectRoot}"
        [[ -d "${projectRoot}/share/${projectName}" ]] && resourceRoot="${projectRoot}/share/${projectName}"
        local libraryRoot="${resourceRoot}/lib"
        if [[ -d "${libraryRoot}" ]]; then
            _rayvnProjects[${projectName}${_libraryRootSuffix}]="${libraryRoot}"
        fi
        return 0
    fi
}

# Unregister a previously added rayvn project, removing its project and library root entries.
# Args: projectName
#
#   projectName - short name of the project to remove (e.g. 'valt')
removeRayvnProject() {
    local projectName="${1}"
    unset "_rayvnProjects[${projectName}${_projectRootSuffix}]"
    unset "_rayvnProjects[${projectName}${_libraryRootSuffix}]"
}

# Require a library and assert that the require failure message contains an expected substring.
# Useful for testing libraries that are expected to fail on load.
# Args: library expected
#
#   library  - library path to require (e.g. 'rayvn/core')
#   expected - substring that must appear in the captured failure message
requireAndAssertFailureContains() {
    local library="${1}"
    local expected="${2}"
    unset _requireFailure 2> /dev/null
    declare -g _rayvnRequireFailHandler='_captureRequireFailure'
    require "${library}"
    assertVarContains _requireFailure "${expected}"
}

# Run a function a given number of times and print timing results including ops/sec.
# Args: functionName iterations testCase [args...]
#
#   functionName - name of the function to benchmark
#   iterations   - number of times to call the function
#   testCase     - label printed in the results line
#   args         - optional arguments passed to the function on each invocation
benchmark() {
    local functionName=${1}
    local iterations=${2}
    local testCase=${3}
    shift 3
    local args=("${@}")

    local startTime=${EPOCHREALTIME}

    for (( i=0; i < ${iterations}; i++ )); do
        ${functionName} "${args[@]}" > /dev/null
    done

    local endTime=${EPOCHREALTIME}
    local duration=${ awk "BEGIN {printf \"%.6f\", ${endTime} - ${startTime}}"; }
    local opsPerSec=${ awk "BEGIN {printf \"%.2f\", ${iterations} / ${duration}}"; }

    printf "%-30s %-15s %10d iterations in %8.4f sec (%10s ops/sec)\n" \
      "${testCase}" "${functionName}" "${iterations}" "${duration}" "${opsPerSec}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/test' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_test() {
    require 'rayvn/core'
}

_captureRequireFailure() {
    declare -g _requireFailure="${1}"
    unset _rayvnRequireFailHandler
}

