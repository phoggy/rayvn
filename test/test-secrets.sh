#!/usr/bin/env bash

main() {
    init "$@"

    testStoreAndRetrieve
    testSecretExists
    testDeleteSecret
    testRetrieveNonexistent
    testOverwriteSecret
    testEmptySecret

    return 0
}

init() {

    # Process args

    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${terminal}" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done

    # Use a unique test service name to avoid conflicts
    declare -gx testService="rayvn_test_secrets_${ date +%s; }"
    declare -gx testAccount="test_account"

    # Clean up any existing test secrets
    secretDelete "${testService}" "${testAccount}" 2> /dev/null || true
}

testStoreAndRetrieve() {
    local testSecret="myTestSecret123"

    # Store the secret
    secretStore "${testService}" "${testAccount}" "${testSecret}"

    # Retrieve and verify
    local retrieved
    retrieved=${ secretRetrieve "${testService}" "${testAccount}"; }
    assertEqual "${retrieved}" "${testSecret}" "Retrieved secret should match stored secret"

    # Clean up
    secretDelete "${testService}" "${testAccount}"
}

testSecretExists() {
    local testSecret="existsTest"

    # Secret should not exist initially
    if secretExists "${testService}" "${testAccount}"; then
        fail "Secret should not exist before storing"
    fi

    # Store the secret
    secretStore "${testService}" "${testAccount}" "${testSecret}"

    # Now it should exist
    if ! secretExists "${testService}" "${testAccount}"; then
        fail "Secret should exist after storing"
    fi

    # Clean up
    secretDelete "${testService}" "${testAccount}"

    # Should not exist after deletion
    if secretExists "${testService}" "${testAccount}"; then
        fail "Secret should not exist after deletion"
    fi
}

testDeleteSecret() {
    local testSecret="deleteTest"

    # Store a secret
    secretStore "${testService}" "${testAccount}" "${testSecret}"

    # Verify it exists
    if ! secretExists "${testService}" "${testAccount}"; then
        fail "Secret should exist before deletion"
    fi

    # Delete it
    secretDelete "${testService}" "${testAccount}"

    # Verify it's gone
    local retrieved
    retrieved=${ secretRetrieve "${testService}" "${testAccount}"; }
    assertEqual "${retrieved}" "" "Retrieved secret should be empty after deletion"
}

testRetrieveNonexistent() {
    local nonexistentService="rayvn_test_nonexistent"
    local nonexistentAccount="nonexistent_account"

    # Retrieve non-existent secret should return empty string
    local retrieved
    retrieved=${ secretRetrieve "${nonexistentService}" "${nonexistentAccount}"; }
    assertEqual "${retrieved}" "" "Non-existent secret should return empty string"
}

testOverwriteSecret() {
    local testSecret1="firstSecret"
    local testSecret2="secondSecret"

    # Store first secret
    secretStore "${testService}" "${testAccount}" "${testSecret1}"

    # Verify first secret
    local retrieved
    retrieved=${ secretRetrieve "${testService}" "${testAccount}"; }
    assertEqual "${retrieved}" "${testSecret1}" "First secret should be stored"

    # Overwrite with second secret
    secretStore "${testService}" "${testAccount}" "${testSecret2}"

    # Verify second secret
    retrieved=${ secretRetrieve "${testService}" "${testAccount}"; }
    assertEqual "${retrieved}" "${testSecret2}" "Second secret should overwrite first"

    # Clean up
    secretDelete "${testService}" "${testAccount}"
}

testEmptySecret() {
    local emptySecret=""

    # Store empty secret
    secretStore "${testService}" "${testAccount}" "${emptySecret}"

    # Retrieve and verify it's empty
    local retrieved
    retrieved=${ secretRetrieve "${testService}" "${testAccount}"; }
    assertEqual "${retrieved}" "${emptySecret}" "Empty secret should be retrievable"

    # Clean up
    secretDelete "${testService}" "${testAccount}"
}

source rayvn.up 'rayvn/secrets' 'rayvn/test'
main "$@"
