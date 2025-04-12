#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library supporting test cases
# Intended for use via: require 'rayvn/test'

require 'rayvn/core'

### assert functions ----------------------------------------------------------------------------------------

assertNotInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null && assertFailed "'${match}' found in file ${file}."
}
assertInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null 2>&1  || assertFailed "'${match}' not found in file ${file}."
}

assertEqual() {
    local msg="${3:-"assert ${1} == ${2} failed"}"
    [[ ${1} == "${2}" ]] || assertFailed "${msg}"
}

assertNotInPath() {
    local executable="${1}"
    local path="$(command -v ${executable})"
    [[ ${path} == '' ]] || assertFailed "${executable} was found in PATH at ${path}"
}
assertInPath() {
    local executable="${1}"
    local expectedPath="${2}"
    local foundPath="$(command -v ${executable})"
    [[ ${foundPath} ]] || assertFailed "${executable} was not found in PATH"
    assertFile "${foundPath}"
    local realPath="$(realpath ${foundPath})"

    if [[ ${expectedPath} ]]; then
        if [[ ${realPath} == "${foundPath}" ]]; then
            if [[ ${foundPath} != "${expectedPath}" ]]; then
                assertFailed "${executable} found at ${foundPath}, expected ${expectedPath}"
            fi
        elif ! [[ ${foundPath} == "${expectedPath}" || ${realPath} == "${expectedPath}" ]]; then
            assertFailed "${executable} found at ${foundPath} --> ${realPath}, expected ${expectedPath}"
        fi
    fi
}

assertFunctionNotDefined() {
    local name="${1}"
    declare -f ${name} > /dev/null 2>&1 && assertFailed "function '${name}(){...} is defined"
}

assertFunctionDefined() {
    local name="${1}"
    declare -f ${name} > /dev/null 2>&1 || assertFailed "function '${name}(){...} is not defined"
}

assertVarNotDefined() {
    local varName="${1}"
    [[ -v ${!varName} ]] && assertFailed "${varName} is defined"
}

assertVarDefined() {
    local varName="${1}"
    declare -p ${varName} > /dev/null 2>&1 || assertFailed "${varName} is not defined"
}

assertHashTableDefined() {
    local varName=${1}
    assertVarDefined ${varName}
    [[ "$(declare -p ${varName} 2>/dev/null)" =~ "declare -A" ]] || assertFailed "${varName} is not a hash table"
}
assertHashKeyIsDefined() {
    local varName="${1}"
    local keyName="${2}"

    assertHashTableDefined "${varName}"

    # TODO: the line below screws up function name syntax color, but executes fine

    [[ -v ${varName}[${keyName}] ]] || assertFailed "${varName}[${keyName}] is NOT defined"
}

assertHashKeyNotDefined() {
    local varName="${1}"
    local keyName="${2}"
    [[ -v ${varName}[${keyName}] ]] && assertFailed "${varName}[${keyName}] is defined"
}

assertHashValue() {
    local varName="${1}"
    local keyName="${2}"
    local expectedValue="${3}"
    assertHashKeyIsDefined "${varName}" "${keyName}"


    local actualValue="$(eval echo \$"{${varName}[${keyName}]}")" # complexity required to use variables for var and key
    [[ ${actualValue} == "${expectedValue}" ]] || assertFailed "${varName}[${keyName}]=${actualValue}, expected '${expectedValue}"
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
        local paths length width i
        echo "${pathVariable} search order:"
        echo
        IFS=':' read -ra paths <<< "${!pathVariable}"
        length=${#paths[@]}
        width=${#length}
        for (( i = 0; i < length; i++ )); do
            printf "%*d. %s\n" "${width}" "$((i + 1))" "${paths[i]}"
        done
        echo
    else
        echo "'${pathVariable}' not set"
    fi
}
