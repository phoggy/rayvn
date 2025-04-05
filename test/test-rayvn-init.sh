#!/usr/bin/env bash
# shellcheck disable=SC2155

main() {
    init "${@}"
    testCleanInstall
}

init() {
    #logEnv "test.env"  # TODO: activate under a debug flag passed in the env

    # First, ensure that our environment preconditions are satisfied

    assertEnvPreconditions

    # Create a temp directory to use as HOME and ensure we remove it on exit

    readonly testHome="$(mktemp -d)" || _failed
    trap '_onExit' EXIT

    # Save the current HOME so we can switch

    declare -grx userHome="${HOME}"

    # Set some vars pointing into the rayvn install that invoked us

    declare -grx rayvnInstallDir="${installDir}"
    declare -grx rayvnInstallLibDir="${rayvnInstallDir}/lib"
    declare -grx rayvnInstallBinDir="${rayvnInstallDir}/bin"
    declare -grx rayvnInstallPkgDir="${rayvnInstallDir}/pkg"

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
    _assertVarIsNotDefined RAYVN_LIBRARIES

    # Ensure we have the required vars

    _assertVarIsDefined installDir
    _assertVarIsDefined installedBinary
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

    # Now make sure we do not have the require and _exitRequire functions

    _assertFunctionIsNotDefined require
    _assertFunctionIsNotDefined _exitRequire

    errorPrefix=''
}

logEnv() {
    local file="${1}"
    (
        printf "%s\n\n" '--- VARIABLES --------------'
        declare -p
        printf "\n\n%s\n\n" '--- FUNCTIONS ---------------'
        declare -f
    ) > "${file}"
    echo "Wrote env to ${file}"
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

_failed() {
    echo "${errorPrefix}${1}"
    exit 1
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
    declare -gx rayvnConfigDir="${HOME}/.rayvn"
    declare -gx rayvnConfigLibDir="${rayvnConfigDir}/lib"
    declare -gx rayvnConfigBinDir="${rayvnConfigDir}/bin"
    declare -gx rayvnConfigPkgDir="${rayvnConfigDir}/pkg"
    declare -gx rayvnBootFile="${rayvnConfigDir}/boot.sh"
    declare -gx rayvnEnvFile="${rayvnConfigDir}/rayvn.env"
}

testCleanInstall() {

    # Switch HOME to test home

    useTestHome

    # Double check that we have the expected vars

    [[ "${HOME}" == "${testHome}" ]] || _failed "HOME var is not pointing to ${testHome}"
    [[ "${rayvnConfigDir}" == "${testHome}"/* ]] || _failed "rayvnConfigDir is not within testHomeDir: ${rayvnConfigDir}"

    # Make sure that HOME directory is empty

    [[ "$(find "${HOME}" -mindepth 1 -print -quit)" ]] && _failed "test HOME dir '${HOME}' is not empty"

    # Double check that we don't have any of our config dirs (the above should do that, but in case we screw up somewhere...)

    _assertFileDoesNotExist "${rayvnConfigDir}"
    _assertFileDoesNotExist "${rayvnConfigLibDir}"
    _assertFileDoesNotExist "${rayvnConfigBinDir}"
    _assertFileDoesNotExist "${rayvnConfigPkgDir}"

    # Run init

    ${installedBinary} init || { echo 'rayvn init failed'; exit 1; }

    # Check that the expected directories were created

    _assertIsDirectory "${rayvnConfigDir}"
    _assertIsDirectory "${rayvnConfigLibDir}"
    _assertIsDirectory "${rayvnConfigBinDir}"
    _assertIsDirectory "${rayvnConfigPkgDir}"

    # Check that the expected files were created

    _assertIsFile "${bashrcFile}"
    _assertIsFile "${rayvnBootFile}"
    _assertIsFile "${rayvnEnvFile}"

    # Ensure that the .bashrc file contains a reference to our env file

    _assertInFile '.rayvn/rayvn.env' "${bashrcFile}"

    # List the contents of HOME

    (
        cd ${HOME} || _failed "could not cd to ${HOME}"
        echo "Listing test HOME dir..."
        echo
        ls -laR
    )
    # Clear all of the boot vars

    unset rayvnConfigDir
    unset rayvnConfigLibDir
    unset rayvnConfigBinDir
    unset rayvnConfigPkgDir
    unset RAYVN_LIBRARIES

    # Remove all PATH dirs containing rayvn so that we can test rayvn.env

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

    [[ "$(which rayvn)" ]] && _failed "rayvn found after PATH removals"

    # OK, now source rayvn.env from the test home using the generated env file to put binary in path

    source "${rayvnEnvFile}" 2> /dev/null || _failed 'source ${rayvnEnvFile} failed'

    # Now make sure that we can find rayvn within our test home

    rayvnPath="$(which rayvn)" || _failed "which rayvn failed after source of rayvn.env"
    [[ "${rayvnPath}" == "${testHome}"/* ]] || _failed "rayvn is not within testHomeDir ${rayvnConfigDir}, got ${rayvnPath}"

    # Make sure we do not yet hove the boot functions and vars

    _assertFunctionIsNotDefined require
    _assertFunctionIsNotDefined _exitRequire

    _assertVarIsNotDefined rayvnConfigDir
    _assertVarIsNotDefined rayvnConfigLibDir
    _assertVarIsNotDefined rayvnConfigBinDir
    _assertVarIsNotDefined rayvnConfigPkgDir
    _assertVarIsNotDefined RAYVN_LIBRARIES

    # Ensure that functions from our core library are NOT present in this shell

    _assertFunctionIsNotDefined 'rootDirPath'
    _assertFunctionIsNotDefined 'tempDirPath'
    _assertFunctionIsNotDefined 'init_rayvn_core'

    # Ensure that functions from our test library are NOT present in this shell

    _assertFunctionIsNotDefined 'rootDirPath'
    _assertFunctionIsNotDefined 'tempDirPath'
    _assertFunctionIsNotDefined 'init_rayvn_core'

    # Now boot rayvn

    source "${rayvnBootFile}" 2> /dev/null || _failed 'source ${rayvnBootFile} failed'

    # Make sure our boot functions and vars are now present

    _assertFunctionIsDefined require
    _assertFunctionIsDefined _exitRequire

    _assertVarIsDefined rayvnConfigDir
    _assertVarIsDefined rayvnConfigLibDir
    _assertVarIsDefined rayvnConfigBinDir
    _assertVarIsDefined rayvnConfigPkgDir
    _assertVarIsDefined RAYVN_LIBRARIES

    # Good, now we should be able to require our shared test functions

    require 'rayvn/test' || _failed 'require 'rayvn/test' failed'

    # Make sure we have some of them

    _assertFunctionIsDefined assertInPath
    _assertFunctionIsDefined assertInFile
    _assertFunctionIsDefined assertFunctionNotDefined
    _assertFunctionIsDefined assertHashTableDefined
    _assertFunctionIsDefined assertHashKeyNotDefined
    _assertFunctionIsDefined assertHashValue

    # OK, so now use them to ensure library index is as expected

    assertHashTableDefined 'RAYVN_LIBRARIES'
    assertHashKeyNotDefined 'RAYVN_LIBRARIES' 'foobar'
    assertHashValue 'RAYVN_LIBRARIES' 'rayvn' 2      # both core and test
    assertHashValue 'RAYVN_LIBRARIES' 'rayvn_test' 1
    assertHashValue 'RAYVN_LIBRARIES' 'rayvn_core' 1

    # Ensure that functions from our core library are now present in this shell

    assertFunctionDefined 'rootDirPath'
    assertFunctionDefined 'tempDirPath'
    assertFunctionDefined 'init_rayvn_core'

    # Finally, restore PATH in case other test functions need it

    export PATH="${origPath}"
}

removeTrailingBlankLinesFromFile() {
    local file="${1}"
    sed -i '.bak' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "${file}"
}

removeMatchingLinesFromFile() {
    local match="${1}"
    local file="${2}"
    assertFile "${file}"
    if grep -e "${match}" "${file}" > /dev/null; then
        sed -i '.bak' "/.${match}/d" "${file}"
    fi
}

main "${@}"
