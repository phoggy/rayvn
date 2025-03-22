#!/usr/bin/env bash
# shellcheck disable=SC2155

# TODO move util functions into 'test' library
# TODO move init() and main() into rayvn test runner

main() {
    init "${@}"

    testCleanInstall

    echo "PASSED"
}

init() {
    rayvnRootDir="$(realpath "${BASH_SOURCE%/*}/..")"
    rayvnBinDir="${rayvnRootDir}/bin"
    rayvnInstallDir="${HOME}/.rayvn"
    rayvnInstallBinDir="${rayvnInstallDir}/bin"
}

failed() {
    if [[ ${1} ]]; then
        red="$(tput setaf 1)"
        normal="$(tput sgr0)"
        echo
        echo "🔺 ${red}${*}${normal}"
        echo
        printStack
        echo
        exit 1
    else
        exit 0
    fi
}
printStack() {
    local start=1
    local caller=${FUNCNAME[1]}
    local start=1
    [[ ${caller} == "failed" ]] && start=2

    for ((i = ${start}; i < ${#FUNCNAME[@]} - 1; i++)); do
        local function="${FUNCNAME[${i}]}"
        local line=${BASH_LINENO[${i} - 1]}
        local called=${FUNCNAME[${i} - 1]}
        local script=${BASH_SOURCE[${i}]}
        echo "   ${function}() line ${line} [in ${script}] --> ${called}()"
    done
}
clean() {
    local rayvnHomeDir="${HOME}/.rayvn"
    local rayvnPathDir="$rayvnHomeDir}/bin"
    local bashrcFile="${HOME}/.bashrc"

    rm -rf ${rayvnHomeDir} > /dev/null
    removePathDir "${rayvnPathDir}"
    removeMatchingLinesFromFile '.rayvn' "${bashrcFile}"
    removeTrailingBlankLinesFromFile "${bashrcFile}"
}
removeTrailingBlankLinesFromFile() {
    local file="${1}"
    sed -i '.bak' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "${file}"
}

removeMatchingLinesFromFile() {
    local match="${1}"
    local file="${2}"
    if grep -e "${match}" "${file}" > /dev/null; then
        sed -i '.bak' "/.${match}/d" "${file}"
    fi
}
assertNotInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null && failed "'${match}' found in file ${file}."
}
assertInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null 2>&1  || failed "'${match}' not found in file ${file}."
}
removePathDir() {
    local removePath="${1}"
    local pathVariable=${2:-PATH}
    local dir newPath paths
    IFS=':' read -ra paths <<<"${!pathVariable}"

    for dir in "${paths[@]}"; do
        if [[ "${dir}" != "${removePath}" ]]; then
            newPath="${newPath:+$newPath:}${dir}"
        fi
    done
    export ${pathVariable}="${newPath}"
}

assertNotInPath() {
    local executable="${1}"
    local path="$(which ${executable})"
    [[ ${path} == '' ]] || failed "${executable} was found in PATH at ${path}"
}
assertInPath() {
    local executable="${1}"
    local expectedPath="${2}"
    local foundPath="$(which ${executable})"
    [[ ${foundPath} ]] || failed "${executable} was not found in PATH"
    local realPath="$(realpath ${foundPath})"
    if [[ ${expectedPath} ]]; then
        if [[ ${realPath} == "${foundPath}" ]]; then
            if [[ ${foundPath} != "${expectedPath}" ]]; then
                failed "${executable} found at ${foundPath}, expected ${expectedPath}"
            fi
        elif ! [[ ${foundPath} == "${expectedPath}" || ${realPath} == "${expectedPath}" ]]; then
            failed "${executable} found at ${foundPath} --> ${realPath}, expected ${expectedPath}"
        fi
    fi
}

assertFunctionNotDefined() {
    local name="${1}"
    declare -f ${name} > /dev/null 2>&1 && failed "function '${name}(){...} is defined"
}

assertFunctionDefined() {
    local name="${1}"
    declare -f ${name} > /dev/null 2>&1 || failed "function '${name}(){...} is not defined"
}

assertVarNotDefined() {
    local varName="${1}"
    [[ -v ${!varName} ]] && failed "${varName} is defined"
}

assertVarDefined() {
    local varName="${1}"
    declare -p ${varName} > /dev/null 2>&1 || failed "${varName} is not defined"
}

assertHashTableDefined() {
    local varName=${1}
    assertVarDefined ${varName}
    [[ "$(declare -p ${varName} 2>/dev/null)" =~ "declare -A" ]] || failed "${varName} is not a hash table"
}
assertHashKeyNotDefined() {
    local varName="${1}"
    local keyName="${2}"
    [[ -v ${!varName}[${keyName}] ]] && failed "${varName}[${keyName}] is defined"
}

assertHashValue() {
    local varName="${1}"
    local keyName="${2}"
    local expectedValue="${3}"

    [[ -v ${varName}[${keyName}] ]] || failed "${varName}[${keyName}] is not defined"
    local actualValue="$(eval echo \$"{${varName}[${keyName}]}")" # complexity required to use variables for var and key
    [[ ${actualValue} == "${expectedValue}" ]] || failed "${varName}[${keyName}]=${actualValue}, expected '${expectedValue}"
}

testCleanInstall() {
    local bashrc="${HOME}/.bashrc"

    # Start clean and double check it

    clean

    assertNotInPath rayvn
    source "${HOME}/.rayvn/boot.sh" 2>/dev/null && failed 'rayvn already installed'
    assertNotInFile '.rayvn' "${bashrc}"

    # Install it

    ${rayvnBinDir}/rayvn init

    # Act like .bashrc ran

    source ${HOME}/.rayvn/rayvn.env

    # Ensure installed

    assertInPath rayvn "${rayvnBinDir}/rayvn"
    assertInFile '.rayvn' "${bashrc}"

    # Ensure that functions from our boot script are NOT present in this shell

    assertFunctionNotDefined 'require'
    assertFunctionNotDefined '_exitRequire'

    # Now boot rayvn in this shell

    source "${HOME}/.rayvn/boot.sh" 2>/dev/null || failed 'rayvn not installed'

    # Ensure that functions from our boot script are now present in this shell

    assertFunctionDefined 'require'
    assertFunctionDefined '_exitRequire'

    # We have not called require, so our index should not yet be defined

    assertVarNotDefined 'RAYVN_LIBRARIES'

    # Ensure that functions from our core library are NOT present in this shell

    assertFunctionNotDefined 'rootDirPath'
    assertFunctionNotDefined 'tempDirPath'
    assertFunctionNotDefined 'init_rayvn_core'

    # Execute require for our core library

    require 'rayvn/core'

    # Ensure index is as expected

    assertHashTableDefined 'RAYVN_LIBRARIES'
    assertHashKeyNotDefined 'RAYVN_LIBRARIES' 'foobar'
    assertHashValue 'RAYVN_LIBRARIES' 'rayvn' 1
    assertHashValue 'RAYVN_LIBRARIES' 'rayvn_core' 1

    # Ensure that functions from our core library are now present in this shell

    assertFunctionDefined 'rootDirPath'
    assertFunctionDefined 'tempDirPath'
    assertFunctionDefined 'init_rayvn_core'
}

main "${@}"
