#!/usr/bin/env bash
# shellcheck disable=SC2155

# Test case support library.
# Intended for use via: require 'rayvn/test'

### Test lifecycle -----------------------------------------------------------------------------------------

# Initialize test counters. Call at start of test file.
beginTest() {
    declare -gi _testCount=0
    declare -gi _passCount=0
    declare -gi _failCount=0
}

# Print summary and fail if any tests failed. Call at end of test file.
endTest() {
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Total tests:  ${_testCount}"
    echo "Passed:       ${_passCount}"
    echo "Failed:       ${_failCount}"
    echo ""

    if (( _failCount == 0 )); then
        echo "✓ All tests passed!"
        return 0
    else
        fail "${_failCount} tests failed"
    fi
}

### assert functions ----------------------------------------------------------------------------------------

assertNotInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null && fail "'${match}' found in file ${file}."
}

assertInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null 2>&1  || fail "'${match}' not found in file ${file}."
}

# Assert expected equals actual, with test counting and output.
# Usage: assertEqual "test name" "expected" "actual"
assertEqual() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    (( _testCount++ ))

    if [[ ${actual} == "${expected}" ]]; then
        (( _passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    else
        (( _failCount++ ))
        echo "  ✗ ${testName}"
        echo "    Expected: '${expected}'"
        echo "    Actual:   '${actual}'"
        return 1
    fi
}

# Assert expected equals actual after stripping ANSI codes.
# Usage: assertEqualStripped "test name" "expected" "actual"
assertEqualStripped() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    assertEqual "${testName}" "${expected}" "${ stripAnsi "${actual}"; }"
}

# Assert expected equals actual, showing cat -v output on failure.
# Usage: assertEqualEscapeCodes "test name" "expected" "actual"
assertEqualEscapeCodes() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    (( _testCount++ ))

    if [[ ${actual} == "${expected}" ]]; then
        (( _passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    else
        (( _failCount++ ))
        echo "  ✗ ${testName}"
        echo "    Expected: '${expected}'"
        echo "    Actual:   '${actual}'"
        echo "    Expected (visible): ${ echo -n "${expected}" | cat -v; }"
        echo "    Actual (visible):   ${ echo -n "${actual}" | cat -v; }"
        return 1
    fi
}

# Assert that a command succeeds (exits 0).
# Usage: assertTrue "test name" command [args...]
assertTrue() {
    local testName="${1}"
    shift

    (( _testCount++ ))

    if "${@}"; then
        (( _passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    else
        (( _failCount++ ))
        echo "  ✗ ${testName}"
        return 1
    fi
}

# Assert that a command fails (exits non-0).
# Usage: assertFalse "test name" command [args...]
assertFalse() {
    local testName="${1}"
    shift

    (( _testCount++ ))

    if "${@}"; then
        (( _failCount++ ))
        echo "  ✗ ${testName}"
        return 1
    else
        (( _passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    fi
}

# Assert that actual contains expected substring.
# Usage: assertContains "test name" "expected substring" "actual"
assertContains() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    (( _testCount++ ))

    if [[ ${actual} == *"${expected}"* ]]; then
        (( _passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    else
        (( _failCount++ ))
        echo "  ✗ ${testName}"
        echo "    Expected to contain: '${expected}'"
        echo "    Actual: '${actual}'"
        return 1
    fi
}

# Assert value is within range (inclusive).
# Usage: assertInRange "test name" value min max
assertInRange() {
    local testName="${1}"
    local value="${2}"
    local min="${3}"
    local max="${4}"

    (( _testCount++ ))

    if (( value >= min && value <= max )); then
        (( _passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    else
        (( _failCount++ ))
        echo "  ✗ ${testName}"
        echo "    Expected: ${min} <= value <= ${max}"
        echo "    Actual: ${value}"
        return 1
    fi
}

assertEqualIgnoreCase() {
    assertEqual "${1,,}" "${2,,}" "${3:-"assert ${1} == ${2} ignore case failed"}"
}

assertNotInPath() {
    local executable="${1}"
    local path="${ command -v ${executable}; }"
    [[ ${path} == '' ]] || fail "${executable} was found in PATH at ${path}"
}

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

assertFunctionIsNotDefined() {
    local name="${1}"
    [[ ${ declare -f "${name}" 2> /dev/null; } ]] && fail "${name} is defined: ${ declare -f ${name}; }"
}

assertVarIsNotDefined() {
    local name="${1}"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] && fail "${name} is defined: ${ declare -f ${name}; }"
}

assertFunctionIsDefined() {
    local name="${1}"
    [[ ${ declare -f "${name}" 2> /dev/null; } ]] || fail "${name} is not defined"
}

assertVarIsDefined() {
    local name="${1}"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] || fail "${name} is not defined"
}


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

assertVarEquals() {
    local varName="${1}"
    local expected="${2}"
    local -n varRef="${varName}"
    assertVarIsDefined "${varName}"
    if [[ ${varRef} != "${expected}" ]]; then
        fail "${varName}=${varRef}, expected ${expected}"
    fi
}

assertVarContains() {
    local varName="${1}"
    local expected="${2}"
    local -n varRef="${varName}"
    assertVarIsDefined "${varName}"
    if [[ ${varRef} != *"${expected}"* ]]; then
        fail "${varName}=${varRef}, expected ${expected}"
    fi
}

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

assertHashTableIsDefined() {
    local varName=${1}
    assertVarIsDefined ${varName}
    [[ "${ declare -p ${varName} 2>/dev/null; }" =~ "declare -A" ]] || fail "${varName} is not a hash table"
}

assertHashTableIsNotDefined() {
    local varName=${1}
    assertVarIsNotDefined ${varName}
}

assertHashKeyIsDefined() {
    local varName="${1}"
    local keyName="${2}"

    assertHashTableIsDefined "${varName}"
    [[ -v ${varName}[${keyName}] ]] || fail "${varName}[${keyName}] is NOT defined"
}

assertHashKeyIsNotDefined() {
    local varName="${1}"
    local keyName="${2}"
    [[ -v ${varName}[${keyName}] ]] && fail "${varName}[${keyName}] is defined"
}

assertHashValue() {
    local varName="${1}"
    local keyName="${2}"
    local expectedValue="${3}"
    assertHashKeyIsDefined "${varName}" "${keyName}"

    local actualValue="${ eval echo \$"{${varName}[${keyName}]}"; }" # complexity required to use variables for var and key
    [[ ${actualValue} == "${expectedValue}" ]] || fail "${varName}[${keyName}]=${actualValue}, expected '${expectedValue}"
}

### PATH functions ----------------------------------------------------------------------------------------

# Prepend directory to PATH.
# Removes directory prior to prepend if already present.
prependPath () {
    local path="${1}"
    local pathVariable=${2:-PATH}
    removePath "${path}" ${pathVariable}
    declare -gx ${pathVariable}="${path}${!pathVariable:+:${!pathVariable}}"
}

# Append directory to PATH.
# Removes directory prior to append if already present.
appendPath () {
    local path="${1}"
    local pathVariable=${2:-PATH}
    removePath "${path}" ${pathVariable}
    declare -gx  ${pathVariable}="${!pathVariable:+${!pathVariable}:}${path}"
}

# Remove directory from PATH.
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

# Print PATH one line per directory.
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

removeRayvnProject() {
    local projectName="${1}"
    unset "_rayvnProjects[${projectName}${_projectRootSuffix}]"
    unset "_rayvnProjects[${projectName}${_libraryRootSuffix}]"
}

requireAndAssertFailureContains() {
    local library="${1}"
    local expected="${2}"
    unset _requireFailure 2> /dev/null
    declare -g _rayvnRequireFailHandler='_captureRequireFailure'
    require "${library}"
    assertVarContains _requireFailure "${expected}"
}

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

