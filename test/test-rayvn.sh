#!/usr/bin/env bash
# shellcheck disable=SC2155

# Cannot use 'require rayvn/test' here since we are going to test it, so
# do it 'manually' here

source "$(dirname "${0}")/../lib/test.sh"; init_rayvn_test

suiteAll() {   # TODO: clarify suite model
    testCleanInstall
    echo "PASSED" # TODO REMOVE, should be in test runner
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

suiteAll "${@}"
