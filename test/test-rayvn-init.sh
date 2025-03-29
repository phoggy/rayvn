#!/usr/bin/env bash
# shellcheck disable=SC2155

#echo "env: " TODO REMOVE
#env
#echo 'done'
#exit 0

# Cannot use 'require rayvn/test' here since we are going to test it, so
# do it 'manually' here

main() {
    init "${@}"
    testCleanInstall
}

init() {
    readonly rayvnHomeDir="${HOME}/.rayvn"
    readonly bashrcFile="${HOME}/.bashrc"
}
createAlternateHome() {
    # After a clean, we need to be able to assert that rayvn is NOT in the search path.
    # We cannot use removePath on the directory containing 'rayvn' in clean because we
    # may be running inside of brew installed instance and that would then remove a
    # critical system path (e.g. /usr/local/bin)!
    #
    # Instead create a temp directory which we can add and remove from PATH, and put
    # a 'test-ravyn' link in it pointing to the actual binary.

    readonly rayvn='test-rayvn'
    readonly rayvnTempPathDir="$(mktemp -d)"
    trap 'onExit' EXIT
    (
        cd "${rayvnTempPathDir}" || assertFailed
        ln -s "${rayvnBinaryFile}" "${rayvn}"
    )
    appendPath "${rayvnTempPathDir}"
    assertInPath "${rayvn}" "${rayvnBinaryFile}"
    assertEqual "${rayvnTempPathDir}/${rayvn}" "$(which "${rayvn}")"

    # Now, we should be able to execute using "${rayvn}"

    local version="$(${rayvn} --version)"
    assertEqual "${version}" "${RAYVN_VERSION}"
}

onExit() {
    rm -rf "${rayvnTempPathDir}" &> /dev/null
}

clean() {
    exit 0; # TODO keep boot script!!
    rm -rf ${rayvnHomeDir} &> /dev/null                 # TODO need boot script
    removeMatchingLinesFromFile '.rayvn' "${bashrcFile}"
    removeTrailingBlankLinesFromFile "${bashrcFile}"
}

testCleanInstall() {

    # Start clean and double check it.

    clean

    [[ -d ${rayvnHomeDir} ]] && { echo 'found ${ravynHomeDir}'; exit 1; }
    local rayvnInit="$(cat "${bashrcFile}" | grep .rayvn)"
    [[ ${rayvnInit} ]] && { echo 'found '${rayvnInit}' in PATH in ${rayvnInit}'; exit 1; }
    local found="$(which rayvn)"
    [[ ${found} ]] && { echo 'found rayvn in PATH at ${found}'; exit 1; }


    # init rayvn and grab test library
    source "${HOME}/.rayvn/boot.sh" 2> /dev/null && { echo 'rayvn already installed'; exit 1; }
declare -p require _requireExit
    require 'rayvn/test'

#    assertNotInFile '.rayvn' "${bashrcFile}" TODO

    # Install it

    appendPath "${rayvnTempPathDir}"
    ${rayvn} init || assertFailed

    # Act like .bashrc ran

    source ${HOME}/.rayvn/rayvn.env

    # Ensure installed

    assertInPath "${rayvn}" "${rayvnTempPathDir}/${rayvn}"
    assertInFile '.rayvn' "${bashrcFile}"

    # Ensure that functions from our boot script are NOT present in this shell

    assertFunctionNotDefined 'require'
    assertFunctionNotDefined '_exitRequire'

    # Now boot rayvn in this shell

    source "${HOME}/.rayvn/boot.sh" 2>/dev/null || assertFailed 'rayvn not installed'

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

main "${@}"
