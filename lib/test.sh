#!/usr/bin/env bash
# shellcheck disable=SC2155

# Test case support.
# Use via: require 'rayvn/test'


# ──────────────────────────────────────────────────────────────────────────────
# ASSERT FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Fail if a pattern is found in a file.
#
# · ARGS
#
#   match (string)  Pattern to search for.
#   file (string)   Path to the file to search.

assertNotInFile() {
    local match="$1"
    local file="$2"
    ! grep -qe "${match}" "${file}" || fail "'${match}' found in file ${file}."
}

# ◇ Fail if a grep pattern is not found in a file.
#
# · ARGS
#
#   match (string)  Pattern to search for.
#   file (string)   Path to the file to search.

assertInFile() {
    local match="$1"
    local file="$2"
    grep -e "${match}" "${file}" > /dev/null 2>&1  || fail "'${match}' not found in file ${file}."
}

# ◇ Fails with a message if two strings are not equal.
#
# · ARGS
#
#   expected (string)  Expected value.
#   actual (string)    Actual value.
#   message (string)   Optional custom failure message.

assertEqual() {
    local msg="${3:-"assert '$1' == '$2' failed"}"
    [[ $1 == "$2" ]] || fail "${msg}"
}

# ◇ Fail if expected does not equal actual after stripping ANSI escape codes from actual.
#
# · ARGS
#
#   expected (string)  Expected plain-text value.
#   actual (string)    Value to compare; ANSI codes are stripped before comparison.
#   msg (string)       Optional failure message.

assertEqualStripped() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-"assertEqualStripped failed"}"
    assertEqual "${expected}" "${ stripAnsi "${actual}"; }" "${msg}"
}

# ◇ Assert two strings are equal, printing both with cat -v (escape codes visible) on failure.
#
# · ARGS
#
#   expected (string)  Expected value (may contain escape codes).
#   actual (string)    Actual value to compare.
#   msg (string)       Failure message; defaults to "assertEqualEscapeCodes failed".

assertEqualEscapeCodes() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-"assertEqualEscapeCodes failed"}"
    if [[ ${actual} != "${expected}" ]]; then
        echo "    Expected (visible): ${ echo -n "${expected}" | cat -v; }"
        echo "    Actual (visible):   ${ echo -n "${actual}" | cat -v; }"
        fail "${msg}"
    fi
}

# ◇ Fail with msg if a command exits non-zero.
#
# · ARGS
#
#   msg (string)  Failure message to display.
#   @             Command and arguments to execute.

assertTrue() {
    local msg="$1"
    shift
    "$@" || fail "${msg}"
}

# ◇ Fail with msg if a command exits zero.
#
# · ARGS
#
#   msg (string)  Message to display on failure.
#   cmd (string)  Command and arguments to execute.

assertFalse() {
    local msg="$1"
    shift
    "$@" && fail "${msg}"
    return 0
}

# ◇ Fail if actual does not contain expected as a substring.
#
# · ARGS
#
#   expected (string)  Substring that must be present in actual.
#   actual (string)    Value to search within.
#   msg (string)       Optional custom failure message.

assertContains() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-"assertContains: '${expected}' not in '${actual}'"}"
    [[ ${actual} == *"${expected}"* ]] || fail "${msg}"
}

# ◇ Fail if a numeric value is not within the inclusive range [min, max].
#
# · ARGS
#
#   value (int)   Value to check.
#   min (int)     Minimum allowed value (inclusive).
#   max (int)     Maximum allowed value (inclusive).
#   msg (string)  Custom failure message.

assertInRange() {
    local value="$1"
    local min="$2"
    local max="$3"
    local msg="${4:-"assertInRange: ${value} not in ${min}..${max}"}"
    (( value >= min && value <= max )) || fail "${msg}"
}

# ◇ Fail if two strings are not equal, ignoring case.

assertEqualIgnoreCase() {
    assertEqual "${1,,}" "${2,,}" "${3:-"assert $1 == $2 ignore case failed"}"
}

# ◇ Fails if an executable is found in PATH.

assertNotInPath() {
    local executable="$1"
    local path="${ command -v ${executable}; }"
    [[ ${path} == '' ]] || fail "${executable} was found in PATH at ${path}"
}

# ◇ Fail if an executable is not found in PATH, or optionally at an unexpected path.
#
# · ARGS
#
#   executable (string)    Name of the command that must be in PATH.
#   expectedPath (string)  Expected path; checked against both the found path and its
#                          realpath to account for symlinks.

assertInPath() {
    local executable="$1"
    local expectedPath="$2"
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

# ◇ Fail if a function with the given name is currently defined.
#
# · ARGS
#
#   name (string)  Name of the function that must not be defined.

assertFunctionIsNotDefined() {
    local name="$1"
    [[ ${ declare -f "${name}" 2> /dev/null; } ]] && fail "${name} is defined: ${ declare -f ${name}; }" || true
}

# ◇ Fail if a variable with the given name is currently defined.
#
# · ARGS
#
#   name (string)  Variable name that must not be defined.

assertVarIsNotDefined() {
    local name="$1"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] && fail "${name} is defined: ${ declare -f ${name}; }" || true
}

# ◇ Fail if a function with the given name is not currently defined.
#
# · ARGS
#
#   name (string)  Name of the function that must be defined.

assertFunctionIsDefined() {
    local name="$1"
    [[ ${ declare -f "${name}" 2> /dev/null; } ]] || fail "${name} is not defined"
}

# ◇ Fail if a variable with the given name is not currently defined.
#
# · ARGS
#
#   name (string)  Name of the variable to check.

assertVarIsDefined() {
    local name="$1"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] || fail "${name} is not defined"
}


# ◇ Fail if a variable's declare flags do not match the expected set (order-independent).
#
# · ARGS
#
#   varName (stringRef)     Name of the variable to inspect.
#   expectedFlags (string)  Expected declare flags as a string (e.g. "ir", "r", "arx", "A").

assertVarType() {
    local varName="$1"
    local expectedFlags="$2"  # e.g. "ir", "r", "arx", "A"

    local declaration
    if ! declaration="${ declare -p "${varName}" 2> /dev/null; }"; then
        fail "${varName} is not defined"
    fi

    local actualFlags
    [[ "${declaration}" =~ ^declare[[:space:]]+-([a-zA-Z]+)[[:space:]] ]] || fail "${varName} has unexpected declaration format"
    actualFlags="${BASH_REMATCH[1]}"

    local sortedExpected sortedActual
    sortedExpected="${ echo "${expectedFlags}" | grep -o . | sort | tr -d '\n'; }"
    sortedActual="${ echo "${actualFlags}" | grep -o . | sort | tr -d '\n'; }"

    if [[ "${sortedExpected}" != "${sortedActual}" ]]; then
        fail "${varName} has -${sortedActual}, expected -${sortedExpected}"
    fi
}

# ◇ Fail if a named variable's value does not equal the expected string.
#
# · ARGS
#
#   varName (stringRef)  The name of the variable to check.
#   expected (string)    The expected string value.

assertVarEquals() {
    local varName="$1"
    local expected="$2"
    local -n varRef="${varName}"
    assertVarIsDefined "${varName}"
    if [[ ${varRef} != "${expected}" ]]; then
        fail "${varName}=${varRef}, expected ${expected}"
    fi
}

# ◇ Fail if the variable named varName does not contain expected as a substring.
#
# · ARGS
#
#   varName (stringRef)  Name of the variable to check.
#   expected (string)    Substring that must be present in the variable's value.

assertVarContains() {
    local varName="$1"
    local expected="$2"
    local -n varRef="${varName}"
    assertVarIsDefined "${varName}"
    if [[ ${varRef} != *"${expected}"* ]]; then
        fail "${varName}=${varRef}, expected ${expected}"
    fi
}

# ◇ Fail if an indexed array's contents do not exactly match the expected values.
#
# · ARGS
#
#   varName (arrayRef)  Name of the indexed array variable to check.
#   expected (string)   Remaining args are the expected element values in order.

assertArrayEquals() {
    local varName="$1"
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

# ◇ Fail if a variable is not defined as an associative array (hash table).
#
# · ARGS
#
#   varName (mapRef)  Name of the variable that must be a defined associative array.

assertHashTableIsDefined() {
    local varName=$1
    assertVarIsDefined ${varName}
    [[ "${ declare -p ${varName} 2>/dev/null; }" =~ "declare -A" ]] || fail "${varName} is not a hash table"
}

# ◇ Fail if an associative array variable is currently defined.
#
# · ARGS
#
#   varName (mapRef)  Name of the variable that must not be defined.

assertHashTableIsNotDefined() {
    local varName=$1
    assertVarIsNotDefined ${varName}
}

# ◇ Fail if a key is not present in an associative array.
#
# · ARGS
#
#   varName (mapRef)  Name of the associative array variable.
#   keyName (string)  Key that must be defined in the array.

assertHashKeyIsDefined() {
    local varName="$1"
    local keyName="$2"

    assertHashTableIsDefined "${varName}"
    [[ -v ${varName}[${keyName}] ]] || fail "${varName}[${keyName}] is NOT defined"
}

# ◇ Fail if a key is present in an associative array.
#
# · ARGS
#
#   varName (mapRef)  Name of the associative array variable.
#   keyName (string)  Key that must NOT be defined in the array.

assertHashKeyIsNotDefined() {
    local varName="$1"
    local keyName="$2"
    [[ -v ${varName}[${keyName}] ]] && fail "${varName}[${keyName}] is defined" || true
}

# ◇ Fail if the value at a key in an associative array does not equal the expected value.
#
# · ARGS
#
#   varName (mapRef)        Name of the associative array variable.
#   keyName (string)        Key to look up.
#   expectedValue (string)  Expected value at that key.

assertHashValue() {
    local varName="$1"
    local keyName="$2"
    local expectedValue="$3"
    assertHashKeyIsDefined "${varName}" "${keyName}"

    local actualValue="${ eval echo \$"{${varName}[${keyName}]}"; }" # complexity required to use variables for var and key
    [[ ${actualValue} == "${expectedValue}" ]] || fail "${varName}[${keyName}]=${actualValue}, expected '${expectedValue}"
}

# ──────────────────────────────────────────────────────────────────────────────
# PATH FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Prepend a directory to a PATH-style variable, removing any existing occurrence first.
#
# · ARGS
#
#   path (string)          Name of the directory to prepend.
#   pathVariable (string)  Name of the colon-separated path variable (default: PATH).

prependPath () {
    local path="$1"
    local pathVariable=${2:-PATH}
    removePath "${path}" ${pathVariable}
    declare -gx ${pathVariable}="${path}${!pathVariable:+:${!pathVariable}}"
}

# ◇ Append a directory to a PATH-style variable, removing any existing occurrence first.
#
# · ARGS
#
#   path (string)          Name of directory to append.
#   pathVariable (string)  Name of the colon-separated path variable (default: PATH).

appendPath () {
    local path="$1"
    local pathVariable=${2:-PATH}
    removePath "${path}" ${pathVariable}
    declare -gx  ${pathVariable}="${!pathVariable:+${!pathVariable}:}${path}"
}

# ◇ Remove all occurrences of a directory from a colon-separated path variable.
#
# · ARGS
#
#   removePath (string)    Directory path to remove.
#   pathVariable (string)  Name of the path variable to modify (default: PATH). [R/W]

removePath () {
    local removePath="$1"
    local pathVariable=${2:-PATH}
    local dir newPath paths
    IFS=':' read -ra paths <<< "${!pathVariable}"

    shopt -s nocasematch
    for dir in "${paths[@]}" ; do
        if [[ "${dir}" != "${removePath}" ]] ; then
            newPath="${newPath:+${newPath}:}${dir}"
        fi
    done
    shopt -u nocasematch

    declare -gx  ${pathVariable}="${newPath}"
}

# ◇ Print a PATH-style variable with each directory on its own numbered line.
#
# · ARGS
#
#   pathVariable (string)  Name of the colon-separated path variable to display (default: PATH).

printPath() {
    local pathVariable=${1:-PATH}
    if [[ ${!pathVariable} ]]; then
        echo
        echo "${pathVariable} search order:"
        echo ${PATH} | tr ':' '\n' | nl
        echo
    else
        echo "'${pathVariable}' is not defined"
    fi
}

# ◇ Register a rayvn project by name and root directory, resolving symlinks via realpath.
#
# · ARGS
#
#   projectName (string)  Name to register the project under.
#   projectRoot (string)  Path to the project root directory (resolved to real path).
#
# · RETURNS
#
#   0  project successfully registered
#   1  project already registered with the same root (no-op)

addRayvnProject() {
    local projectName="$1"
    local projectRoot="$2"
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

# ◇ Unregister a project previously added with addRayvnProject().
#
# · ARGS
#
#   projectName (string)  Name of the project to remove.

removeRayvnProject() {
    local projectName="$1"
    unset "_rayvnProjects[${projectName}${_projectRootSuffix}]"
    unset "_rayvnProjects[${projectName}${_libraryRootSuffix}]"
}

# ◇ Require a library and assert the failure message contains an expected substring.
#
# · ARGS
#
#   library (string)   Path to require (e.g. 'rayvn/core').
#   expected (string)  Substring that must appear in the captured failure message.

requireAndAssertFailureContains() {
    local library="$1"
    local expected="$2"
    unset _requireFailure 2> /dev/null
    declare -g _rayvnRequireFailHandler='_captureRequireFailure'
    require "${library}"
    assertVarContains _requireFailure "${expected}"
}

# ◇ Run a function N times and print timing results including ops/sec.
#
# · ARGS
#
#   functionName (string)  Name of the function to benchmark.
#   iterations (int)       Number of times to call the function.
#   testCase (string)      Label printed in the results line.
#   [...] (string)         Optional arguments passed to the function on each invocation.

benchmark() {
    local functionName=$1
    local iterations=$2
    local testCase=$3
    shift 3
    local args=("$@")

    local startTime=${EPOCHREALTIME}

    for (( i=0; i < ${iterations}; i++ )); do
        ${functionName} "${args[@]}" > /dev/null
    done

    local endTime=${EPOCHREALTIME}
    local duration=${ gawk "BEGIN {printf \"%.6f\", ${endTime} - ${startTime}}"; }
    local opsPerSec=${ gawk "BEGIN {printf \"%.2f\", ${iterations} / ${duration}}"; }

    printf "%-30s %-15s %10d iterations in %8.4f sec (%10s ops/sec)\n" \
      "${testCase}" "${functionName}" "${iterations}" "${duration}" "${opsPerSec}"
}

# ──────────────────────────────────────────────────────────────────────────────
# TTY CAPTURE FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Begin capturing terminal UI output to a temp file. Access captured output via
#   getTtyOutput() or getTtyText(). Pair with stopTtyCapture() to restore.

startTtyCapture() {
    local captureFile; captureFile=${ makeTempFile tty-capture-XXXXXX; }
    eval "exec ${ttyFd}>\"${captureFile}\""
    declare -g ttyCapturePath="${captureFile}"
}

# ◇ Stop capturing and restore terminal UI output to the original terminal device.

stopTtyCapture() {
    eval "exec ${ttyFd}<>\"${terminal}\""
    unset ttyCapturePath
}

# ◇ Clear the tty capture file content without stopping capture.

clearTtyCapture() {
    eval "exec ${ttyFd}>\"${ttyCapturePath}\""
}

# ◇ Return raw tty capture content including all ANSI escape sequences.

getTtyOutput() {
    cat "${ttyCapturePath}"
}

# ◇ Return tty capture content with all ANSI escape sequences stripped.

getTtyText() {
    gsed 's/\x1b\[[0-9;?]*[A-Za-z]//g' < "${ttyCapturePath}"
}

# ◇ Fail if raw (ANSI-encoded) tty capture content does not contain expected as a substring.
#   Use this to assert on escape sequences directly. Use assertTtyContains for visible text.
#
# · ARGS
#
#   expected (string)  Substring that must be present in raw tty output (e.g. $'\e[?25l').
#   msg (string)       Optional failure message.

assertTtyRawContains() {
    local expected="$1"
    local msg="${2:-tty raw output does not contain expected sequence}"
    local raw; raw=${ getTtyOutput; }
    [[ "${raw}" == *"${expected}"* ]] || fail "${msg}"
}

# ◇ Fail if captured tty text does not contain expected as a substring.
#
# · ARGS
#
#   expected (string)  Substring that must be present in tty output.
#   msg (string)       Optional failure message.

assertTtyContains() {
    local expected="$1"
    local msg="${2:-tty output does not contain '${expected}'}"
    local text; text=${ getTtyText; }
    [[ ${text} == *"${expected}"* ]] || fail "${msg}"
}

# ◇ Fail if captured tty text contains expected as a substring.
#
# · ARGS
#
#   expected (string)  Substring that must NOT be present in tty output.
#   msg (string)       Optional failure message.

assertTtyNotContains() {
    local expected="$1"
    local msg="${2:-tty output should not contain '${expected}'}"
    local text; text=${ getTtyText; }
    [[ ${text} != *"${expected}"* ]] || fail "${msg}"
}

# ──────────────────────────────────────────────────────────────────────────────
# INPUT SIMULATION FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Begin simulating user input from a string. Redirects stdinFd to a temp file
#   containing the given input so prompt functions read from it instead of the
#   terminal. Pair with stopInputSimulation() to restore.
#
# · ARGS
#
#   input (string)  The simulated input (e.g. "y" for a confirm, "2" for a choice).

startInputSimulation() {
    local input="$1"
    local inputFile; inputFile=${ makeTempFile stdin-sim-XXXXXX; }
    printf '%s' "${input}" > "${inputFile}"
    eval "exec ${stdinFd}< \"${inputFile}\""
    declare -g _stdinSimFile="${inputFile}"
}

# ◇ Stop simulating user input and restore stdinFd to the real stdin.

stopInputSimulation() {
    eval "exec ${stdinFd}<&0"
    rm -f "${_stdinSimFile}"
    unset _stdinSimFile
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/test' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_test() {
    :
}

_captureRequireFailure() {
    declare -g _requireFailure="$1"
    unset _rayvnRequireFailHandler
}

