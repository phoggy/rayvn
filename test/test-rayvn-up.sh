#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2120

main() {
    init "${@}"
    testRayvnUp
}

init() {
 echo "${*}"
    if [[ ${1} == --debug ]]; then
        require 'rayvn/debug'
        setDebug onExit
        debugLogEnvironment "test-rayvn-up"
    fi

    # First, ensure that our environment preconditions are satisfied

    assertEnvPreconditions

    # Create a temp directory to use as HOME and ensure we remove it on exit

    readonly testHome="$(mktemp -d)" || _failed
    trap '_onExit' EXIT

    # Save the current HOME so we can switch

    declare -grx userHome="${HOME}"

    # Keep a copy of PATH so we can restore it

    declare -gr origPath="${PATH}"
}

_onExit() {
    rm -rf "${testHome}" &> /dev/null
}

assertEnvPreconditions() {
    errorPrefix='precondition: '

    # Make sure we did not inherit our boot vars

    _assertVarIsNotDefined rayvnConfigDir
    _assertVarIsNotDefined rayvnConfigLibDir
    _assertVarIsNotDefined rayvnConfigBinDir
    _assertVarIsNotDefined rayvnConfigPkgDir
    _assertVarIsNotDefined rayvnLibraryIndex

    # Ensure we have the required vars

    _assertVarIsDefined rayvnInstallHome
    _assertVarIsDefined rayvnInstallBinary
    _assertVarIsDefined testFunctionNames

    # Ensure we contain only our own functions

    local allFunctions=$(declare -F | awk '{print $NF}')
    declare -A expectedFunctions=
    local name

    for name in ${expectedFunctionNames}; do
        expectedFunctions["${name}"]=1
    done

    for name in ${allFunctions}; do
        [[ "${expectedFunctions["${name}"]}" ]] && _failed "function '${name}' is present"
        unset -f expectedFunctions["${name}"]  || _failed "unset expected"
    done

    [[ ${expectedFunctions[*]} ]] && _failed "missing functions '${expectedFunctions[*]}'"
    unset expectedFunctions

    # Now make sure we do not have the require function

    _assertFunctionIsNotDefined require

    errorPrefix=''
}

# Prefix all assert function names with '_' so that we know they don't collide with
# similar functions in 'rayvn/test'

_assertFunctionIsNotDefined() {
    local name="${1}"
    [[ $(declare -f "${name}" 2> /dev/null) ]] && _failed "${name} is set: $(declare -f ${name})"
}
_assertFunctionIsDefined() {
    local name="${1}"
    [[ ! $(declare -f "${name}" 2> /dev/null) ]] && _failed "${name} not set"
}

_assertVarIsDefined() {
    local name="${1}"
    [[ ! $(declare -p "${name}" 2> /dev/null) ]] && _failed "${name} not set"
}

_assertVarIsNotDefined() {
    local name="${1}"
    [[ $(declare -p "${name}" 2> /dev/null) ]] && _failed "${name} is set"
}

_assertFileDoesNotExist() {
  local file="${1}"
  [[ -e "${file}" ]] && _failed "${file} does not exist"
}

_assertFileExists() {
  local file="${1}"
  [[ -e "${file}" ]] || _failed "${file} does not exist"
}
_assertIsFile() {
  local file="${1}"
  _assertFileExists "${file}"
  [[ -f "${file}" ]] || _failed "${file} is not a file"
}

_assertIsDirectory() {
  local dir="${1}"
  _assertFileExists "${dir}"
  [[ -d "${dir}" ]] || _failed "${dir} is not a directory"
}

_assertInFile() {
    local match="${1}"
    local file="${2}"
    grep -e "${match}" "${file}" > /dev/null 2>&1  || _failed "'${match}' not found in file ${file}."
}
_printStack() {
    local start=1
    local caller=${FUNCNAME[1]}
    local start=1
    [[ ${caller} == "_failed" ]] && start=2

    for ((i = ${start}; i < ${#FUNCNAME[@]} - 1; i++)); do
        local function="${FUNCNAME[${i}]}"
        local line=${BASH_LINENO[${i} - 1]}
        local called=${FUNCNAME[${i} - 1]}
        local script=${BASH_SOURCE[${i}]}
        echo "   ${function}() line ${line} [in ${script}] --> ${called}()"
    done
}

_failed() {
    echo "${errorPrefix}${1}"
    _printStack
    exit 1
}

_printPath() {
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

_prependPath () {
    local path="${1}"
    local pathVariable=${2:-PATH}
    _removePath "${path}" ${pathVariable}
    declare -gx ${pathVariable}="${path}${!pathVariable:+:${!pathVariable}}"
}

_removePath () {
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

useTestHome() {
    export HOME="${testHome}"
    setHomeVars
}
useUserHome() {
    export HOME="${userHome}"
    setHomeVars
}

setHomeVars() {
    declare -gx bashrcFile="${HOME}/.bashrc"
    declare -gx rayvnConfigHomeDir="${HOME}/.rayvn"
}

testRayvnUp() {

    # Switch HOME to test home

    useTestHome

    # Double check that we have the expected vars

    [[ "${HOME}" == "${testHome}" ]] || _failed "HOME var is not pointing to ${testHome}"
    [[ "${rayvnConfigHomeDir}" == "${testHome}"/* ]] || _failed "rayvnConfigHomeDir is not within testHomeDir: ${rayvnConfigHomeDir}"

    # Make sure that HOME directory is empty

    [[ "$(find "${HOME}" -mindepth 1 -print -quit)" ]] && _failed "test HOME dir '${HOME}' is not empty"

    # Double check that we don't have our config dir (the above should do that, but in case we screw up somewhere...)

    _assertFileDoesNotExist "${rayvnConfigHomeDir}"

    # Clear all boot vars

#    unset rayvnRequireCounts
#    unset rayvnBinaryName
#    unset rayvnProjectRoots
#    unset rayvnHome

    # Double check to ensure we do not yet hove the boot functions and vars

    _assertFunctionIsNotDefined require
    _assertFunctionIsNotDefined _configure

    _assertVarIsNotDefined rayvnRequireCounts
    _assertVarIsNotDefined rayvnBinaryName
    _assertVarIsNotDefined rayvnProjectRoots
    _assertVarIsNotDefined rayvnHome

    # Remove all PATH dirs containing rayvn so that we can test rayvn.up

    while true; do
        found="$(which rayvn)"
        if [[ ${found} ]]; then
            pathDir="$(dirname "${found}")"
            _removePath "${pathDir}"
        else
            break # we're done
        fi
    done

    # Double check it

    [[ "$(which rayvn.up)" ]] && _failed "rayvn.up found after PATH removals"

    # OK, now add the install home back into PATH and check we can find it

    _prependPath "${rayvnInstallHome}/bin"
    [[ "$(which rayvn.up)" ]] || _failed "rayvn.up NOT found after PATH removals"

    # Finally, we're ready to boot, so do it

    source rayvn.up &> /dev/null || _failed 'source rayvn.up failed'

    # Check that it set the expected vars and functions

    _assertFunctionIsDefined require
    _assertFunctionIsNotDefined _configure

    _assertVarIsDefined rayvnRequireCounts
    _assertVarIsDefined rayvnBinaryName
    _assertVarIsDefined rayvnProjectRoots
    _assertVarIsDefined rayvnHome

    # Now make sure that we can find rayvn within our test home TODO: after require 'rayvn/debug'

#    rayvnPath="$(which rayvn)" || _failed "which rayvn failed after source of rayvn.env"
#    [[ "${rayvnPath}" == "${testHome}"/* ]] || _failed "rayvn is not within testHomeDir ${rayvnConfigDir}, got ${rayvnPath}"


    # Ensure that functions from our core library are NOT present in this shell

    _assertFunctionIsNotDefined 'rootDirPath'
    _assertFunctionIsNotDefined 'tempDirPath'
    _assertFunctionIsNotDefined 'init_rayvn_core'

    # Ensure that functions from our test library are NOT present in this shell

    _assertFunctionIsNotDefined 'assertNotInFile'
    _assertFunctionIsNotDefined 'assertInFile'
    _assertFunctionIsNotDefined 'printPath'

    # Good, now we should be able to require our shared test functions

    require 'rayvn/test' || _failed 'require 'rayvn/test' failed'

    # Make sure we have some of them

    _assertFunctionIsDefined assertInPath
    _assertFunctionIsDefined assertInFile
    _assertFunctionIsDefined assertFunctionNotDefined
    _assertFunctionIsDefined assertHashTableDefined
    _assertFunctionIsDefined assertHashKeyNotDefined
    _assertFunctionIsDefined assertHashValue

    # OK, so now use them to ensure project roots are as expected

    assertHashTableDefined 'rayvnProjectRoots'
    assertHashKeyNotDefined 'rayvnProjectRoots' 'foobar'
    assertHashKeyIsDefined 'rayvnProjectRoots' 'rayvn::project'
    assertHashKeyIsDefined 'rayvnProjectRoots' 'rayvn::libraries'
    assertHashValue 'rayvnProjectRoots' 'rayvn::project' "${rayvnInstallHome}"
    assertHashValue 'rayvnProjectRoots' 'rayvn::libraries' "${rayvnInstallHome}/lib"


    # And that counts are as expected

    assertHashValue 'rayvnRequireCounts' 'rayvn' 2      # both core and test
    assertHashValue 'rayvnRequireCounts' 'rayvn_test' 1
    assertHashValue 'rayvnRequireCounts' 'rayvn_core' 1

    # Ensure that functions from our core library are now present in this shell

    assertFunctionDefined 'rootDirPath'
    assertFunctionDefined 'tempDirPath'
    assertFunctionDefined 'init_rayvn_core'

    # Finally, restore PATH in case other test functions need it

    export PATH="${origPath}"
}

main "${@}"
