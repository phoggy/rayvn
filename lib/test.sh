#!/usr/bin/env bash
# shellcheck disable=SC2155

# Test case support library.
# Intended for use via: require 'rayvn/test'

### assert functions ----------------------------------------------------------------------------------------

assertNotInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null && assertionFailed "'${match}' found in file ${file}."
}

assertInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null 2>&1  || assertionFailed "'${match}' not found in file ${file}."
}

assertEqual() {
    local msg="${3:-"assert ${1} == ${2} failed"}"
    [[ ${1} == "${2}" ]] || assertionFailed "${msg}"
}

assertEqualIgnoreCase() {
    assertEqual "${1,,}" "${2,,}" "${3:-"assert ${1} == ${2} ignore case failed"}"
}

assertNotInPath() {
    local executable="${1}"
    local path="${ command -v ${executable}; }"
    [[ ${path} == '' ]] || assertionFailed "${executable} was found in PATH at ${path}"
}

assertInPath() {
    local executable="${1}"
    local expectedPath="${2}"
    local foundPath="${ command -v ${executable}; }"
    [[ ${foundPath} ]] || assertionFailed "${executable} was not found in PATH"
    assertFile "${foundPath}"
    local realPath="${ realpath ${foundPath}; }"

    if [[ ${expectedPath} ]]; then
        if [[ ${realPath} == "${foundPath}" ]]; then
            if [[ ${foundPath} != "${expectedPath}" ]]; then
                assertionFailed "${executable} found at ${foundPath}, expected ${expectedPath}"
            fi
        elif ! [[ ${foundPath} == "${expectedPath}" || ${realPath} == "${expectedPath}" ]]; then
            assertionFailed "${executable} found at ${foundPath} --> ${realPath}, expected ${expectedPath}"
        fi
    fi
}

assertFunctionIsNotDefined() {
    local name="${1}"
    [[ ${ declare -f "${name}" 2> /dev/null; } ]] && assertionFailed "${name} is defined: ${ declare -f ${name}; }"
}

assertVarIsNotDefined() {
    local name="${1}"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] && assertionFailed "${name} is defined: ${ declare -f ${name}; }"
}

assertFunctionIsDefined() {
    local name="${1}"
    [[ ${ declare -f "${name}" 2> /dev/null; } ]] || assertionFailed "${name} is not defined"
}

assertVarIsDefined() {
    local name="${1}"
    [[ ${ declare -p "${name}" 2> /dev/null; } ]] || assertionFailed "${name} is not defined"
}


assertVarType() {
    local varName="${1}"
    local expectedFlags="${2}"  # e.g. "ir", "r", "arx", "A"

    local declaration
    if ! declaration="${ declare -p "${varName}" 2> /dev/null; }"; then
        assertionFailed "${varName} is not defined"
    fi

    local actualFlags="${declaration#*-}"
    actualFlags="${actualFlags% *}"

    local sortedExpected sortedActual
    sortedExpected="${ echo "${expectedFlags}" | grep -o . | sort | tr -d '\n'; }"
    sortedActual="${ echo "${actualFlags}" | grep -o . | sort | tr -d '\n'; }"

    if [[ "${sortedExpected}" != "${sortedActual}" ]]; then
        assertionFailed "${varName} has -${sortedActual}, expected -${sortedExpected}"
    fi
}

assertVarEquals() {
    local varName="${1}"
    local expected="${2}"
    local -n varRef="${varName}"
    assertVarIsDefined "${varName}"
    if [[ ${varRef} != "${expected}" ]]; then
        assertionFailed "${varName}=${varRef}, expected ${expected}"
    fi
}

assertVarContains() {
    local varName="${1}"
    local expected="${2}"
    local -n varRef="${varName}"
    assertVarIsDefined "${varName}"
    if [[ ${varRef} != *"${expected}"* ]]; then
        assertionFailed "${varName}=${varRef}, expected ${expected}"
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
                assertionFailed "${varName}[${i}]=${arrayRef[${i}]}, expected ${expected[${i}]}"
            fi
        done
    else
        assertionFailed "${varName} length=${arrayLen}, expected ${expectedLen}"
    fi
}

assertHashTableIsDefined() {
    local varName=${1}
    assertVarIsDefined ${varName}
    [[ "${ declare -p ${varName} 2>/dev/null; }" =~ "declare -A" ]] || assertionFailed "${varName} is not a hash table"
}

assertHashTableIsNotDefined() {
    local varName=${1}
    assertVarIsNotDefined ${varName}
}

assertHashKeyIsDefined() {
    local varName="${1}"
    local keyName="${2}"

    assertHashTableIsDefined "${varName}"
    [[ -v ${varName}[${keyName}] ]] || assertionFailed "${varName}[${keyName}] is NOT defined"
}

assertHashKeyIsNotDefined() {
    local varName="${1}"
    local keyName="${2}"
    [[ -v ${varName}[${keyName}] ]] && assertionFailed "${varName}[${keyName}] is defined"
}

assertHashValue() {
    local varName="${1}"
    local keyName="${2}"
    local expectedValue="${3}"
    assertHashKeyIsDefined "${varName}" "${keyName}"

    local actualValue="${ eval echo \$"{${varName}[${keyName}]}"; }" # complexity required to use variables for var and key
    [[ ${actualValue} == "${expectedValue}" ]] || assertionFailed "${varName}[${keyName}]=${actualValue}, expected '${expectedValue}"
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
    _rayvnProjects[${projectName}${_projectRootSuffix}]="${projectRoot}"
    _rayvnProjects[${projectName}${_libraryRootSuffix}]="${projectRoot}/lib"
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

