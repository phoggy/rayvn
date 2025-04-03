#!/usr/bin/env bash
# shellcheck disable=SC2155

main() {
    init "${@}"
    testCleanInstall
}

init() {

    # Check our preconditions

    assertPreconditions

    # Create a temp directory to use as HOME and ensure we remove it on exit

    readonly testHome="$(mktemp -d)" || _failed
    trap '_onExit' EXIT

    # Save the current HOME so we can switch

    declare -grx userHome="${HOME}"

    # Set some vars pointing into the rayvn install that invoked us

    declare -grx rayvnInstallDir="${rayvnPath}"
    declare -grx rayvnInstallLibDir="${rayvnInstallDir}/lib"
    declare -grx rayvnInstallBinDir="${rayvnInstallDir}/bin"
    declare -grx rayvnInstallPkgDir="${rayvnInstallDir}/pkg"
}

_onExit() {
    rm -rf "${testHome}" &> /dev/null
}

# Prefix all assert function names with '_' so that we know they don't collide with
# similar functions in 'rayvn/test'

_assertFunctionIsNotDefined() {
    local name="${1}"
    [[ ! $(declare -p "${name}" 2> /dev/null) ]] && _failed "${name} is set"
}
_assertFunctionIsDefined() {
    local name="${1}"
    [[ ! $(declare -p "${name}" 2> /dev/null) ]] && _failed "${name} not set"
}

_assertVarIsDefined() {
    local name="${1}"
    [[ ! $(declare -p "${name}" 2> /dev/null) ]] && _failed "${name} not set"
}

_assertVarNotDefined() {
    local name="${1}"
    [[ ! $(declare -p "${name}" 2> /dev/null) ]] || _failed "${name} is set"
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

assertPreconditions() {
    declare -g errorPrefix='precondition: '

    # Make sure we did not inherit our boot vars

    _assertVarNotDefined rayvnConfigDir
    _assertVarNotDefined rayvnConfigLibDir
    _assertVarNotDefined rayvnConfigBinDir
    _assertVarNotDefined rayvnConfigPkgDir
    _assertVarNotDefined RAYVN_LIBRARIES

    # Ensure we have the required vars

    _assertVarIsDefined rayvnPath
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

    # Now make sure we do not have the require and _requireExit functions

    _assertFunctionIsNotDefined require
    _assertFunctionIsNotDefined _requireExit

    errorPrefix=''
}

testCleanInstall() {

    # Switch HOME to test home

    useTestHome

    # Double check that we have the expected vars

    [[ "${HOME}" == "${testHome}" ]] || _failed "HOME var is not pointing to ${testHome}"
    [[ "${rayvnConfigDir}" == "${testHome}"/* ]] || _failed "rayvnConfigDir is not within testHomeDir: ${rayvnConfigDir}"

    # Make sure that HOME directory is empty

    [[ "$(find "${HOME}" -mindepth 1 -print -quit)" ]] && _failed "test HOME dir '${HOME}' is not empty"

    # Run init

    rayvn init || { echo 'rayvn init failed'; exit 1; }

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

    # Unset the vars used in boot

    unset rayvnConfigDir
    unset rayvnConfigLibDir
    unset rayvnConfigBinDir
    unset rayvnConfigPkgDir
    unset RAYVN_LIBRARIES

    # OK, now boot rayvn from the test home using the generated env file

    source "${rayvnEnvFile}" 2> /dev/null || _failed 'rayvn is not installed!'

    # Make sure we now hove the expected functions and vars

    _assertFunctionIsNotDefined require
    _assertFunctionIsNotDefined _requireExit

    _assertVarIsDefined rayvnConfigDir
    _assertVarIsDefined rayvnConfigLibDir
    _assertVarIsDefined rayvnConfigBinDir
    _assertVarIsDefined rayvnConfigPkgDir
    _assertVarIsDefined RAYVN_LIBRARIES

    # Ensure that functions from our core library are NOT present in this shell

    _assertFunctionIsNotDefined 'rootDirPath'
    _assertFunctionIsNotDefined 'tempDirPath'
    _assertFunctionIsNotDefined 'init_rayvn_core'

    # Ensure that functions from our test library are NOT present in this shell

    _assertFunctionIsNotDefined 'rootDirPath'
    _assertFunctionIsNotDefined 'tempDirPath'
    _assertFunctionIsNotDefined 'init_rayvn_core'

    # Now we should be able to require our shared test functions

echo 'require'
    require 'rayvn/test' || _failed 'require 'rayvn/test' failed'

    # Make sure we have some of them

    _assertFunctionIsNotDefined assertInPath
    _assertFunctionIsNotDefined assertInFile
    _assertFunctionIsNotDefined assertFunctionNotDefined
    _assertFunctionIsNotDefined assertHashTableDefined
    _assertFunctionIsNotDefined assertHashKeyNotDefined
    _assertFunctionIsNotDefined assertHashValue

    # OK, so now use them to ensure library index is as expected

    assertHashTableDefined 'RAYVN_LIBRARIES'
    assertHashKeyNotDefined 'RAYVN_LIBRARIES' 'foobar'
    assertHashValue 'RAYVN_LIBRARIES' 'rayvn' 1
    assertHashValue 'RAYVN_LIBRARIES' 'rayvn_test' 1
    assertHashValue 'RAYVN_LIBRARIES' 'rayvn_core' 1

    # Ensure that functions from our core library are now present in this shell

    assertFunctionDefined 'rootDirPath'
    assertFunctionDefined 'tempDirPath'
    assertFunctionDefined 'init_rayvn_core'
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
