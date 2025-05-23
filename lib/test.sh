#!/usr/bin/env bash
# shellcheck disable=SC2155

# Test case support library.
# Intended for use via: require 'rayvn/test'

require 'rayvn/core'

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

assertNotInPath() {
    local executable="${1}"
    local path="$(command -v ${executable})"
    [[ ${path} == '' ]] || assertionFailed "${executable} was found in PATH at ${path}"
}

assertInPath() {
    local executable="${1}"
    local expectedPath="${2}"
    local foundPath="$(command -v ${executable})"
    [[ ${foundPath} ]] || assertionFailed "${executable} was not found in PATH"
    assertFile "${foundPath}"
    local realPath="$(realpath ${foundPath})"

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
    [[ $(declare -f "${name}" 2> /dev/null) ]] && assertionFailed "${name} is set: $(declare -f ${name})"
}

assertFunctionIsDefined() {
    local name="${1}"
    [[ ! $(declare -f "${name}" 2> /dev/null) ]] && assertionFailed "${name} not set"
}

assertVarIsDefined() {
    local name="${1}"
    [[ ! $(declare -p "${name}" 2> /dev/null) ]] && assertionFailed "${name} not set"
}

assertVarIsNotDefined() {
    local name="${1}"
    [[ $(declare -p "${name}" 2> /dev/null) ]] && assertionFailed "${name} is set"
}

assertHashTableIsDefined() {
    local varName=${1}
    assertVarIsDefined ${varName}
    [[ "$(declare -p ${varName} 2>/dev/null)" =~ "declare -A" ]] || assertionFailed "${varName} is not a hash table"
}

assertHashTableIsNotDefined() {
    local varName=${1}
    assertVarIsNotDefined ${varName}
}

assertHashKeyIsDefined() {
    local varName="${1}"
    local keyName="${2}"

    assertHashTableIsDefined "${varName}"

    # TODO: the line below screws up function name syntax color (white instead of blue), but executes fine

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

    local actualValue="$(eval echo \$"{${varName}[${keyName}]}")" # complexity required to use variables for var and key
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
        echo "'${pathVariable}' not set"
    fi
}
