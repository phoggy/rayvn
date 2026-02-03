#!/usr/bin/env bash
# shellcheck disable=SC2155

# Test suite for the rayvn/oauth library
# Tests constants, service key arrays, service map construction, validation, port finding, and HTML output

main() {
    init "${@}"

    testServiceKeyConstants
    testServiceKeysArray
    testGoogleProviderUrls
    testAssertValidOAuthServiceValid
    testAssertValidOAuthServiceNullValue
    testProviderNameCaseInsensitive
    testServiceMapStructure
    testGetOAuthServiceGoogle
    testGetOAuthServiceWithEnvCredentials
    testFindFreePort
    testFindFreePortCustomRange
    testOAuthSuccessHtml

    return 0
}

init() {
    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${ tty; }" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done

    # Mock the secrets functions to avoid real keychain interaction
    secretStore() { :; }
    secretRetrieve() { echo ""; }
    secretDelete() { :; }
    secretExists() { return 1; }
}

# --- Service key constants ---

testServiceKeyConstants() {
    assertEqual "${_oAuthProviderKey}" "providerName" "provider key"
    assertEqual "${_oAuthScopeKey}" "scope" "scope key"
    assertEqual "${_oAuthIdKey}" "clientId" "client ID key"
    assertEqual "${_oAuthSecretKey}" "clientSecret" "client secret key"
    assertEqual "${_oAuthUrlKey}" "authUrl" "auth URL key"
    assertEqual "${_oAuthTokenKey}" "tokenUrl" "token URL key"
}

# --- Service keys array ---

testServiceKeysArray() {
    local expectedCount=6
    local actualCount=${#_oAuthServiceKeys[@]}
    assertEqual "${actualCount}" "${expectedCount}" "service keys array should have ${expectedCount} entries"

    # Verify all expected keys are present
    isMemberOf "providerName" _oAuthServiceKeys || fail "'providerName' not in _oAuthServiceKeys"
    isMemberOf "scope" _oAuthServiceKeys || fail "'scope' not in _oAuthServiceKeys"
    isMemberOf "clientId" _oAuthServiceKeys || fail "'clientId' not in _oAuthServiceKeys"
    isMemberOf "clientSecret" _oAuthServiceKeys || fail "'clientSecret' not in _oAuthServiceKeys"
    isMemberOf "authUrl" _oAuthServiceKeys || fail "'authUrl' not in _oAuthServiceKeys"
    isMemberOf "tokenUrl" _oAuthServiceKeys || fail "'tokenUrl' not in _oAuthServiceKeys"
}

# --- Google provider URLs ---

testGoogleProviderUrls() {
    assertEqual "${_googleAuthUrl}" "https://accounts.google.com/o/oauth2/v2/auth" "Google auth URL"
    assertEqual "${_googleTokenUrl}" "https://oauth2.googleapis.com/token" "Google token URL"
}

# --- _assertValidOAuthService ---

testAssertValidOAuthServiceValid() {
    local -A validService=(
        [providerName]="google"
        [scope]="https://www.googleapis.com/auth/gmail.readonly"
        [clientId]="test-client-id"
        [clientSecret]="test-client-secret"
        [authUrl]="https://accounts.google.com/o/oauth2/v2/auth"
        [tokenUrl]="https://oauth2.googleapis.com/token"
    )
    _assertValidOAuthService validService
}

testAssertValidOAuthServiceNullValue() {
    local -A nullService=(
        [providerName]="google"
        [scope]="https://www.googleapis.com/auth/gmail.readonly"
        [clientId]="null"
        [clientSecret]="test-client-secret"
        [authUrl]="https://accounts.google.com/o/oauth2/v2/auth"
        [tokenUrl]="https://oauth2.googleapis.com/token"
    )
    local caught=0
    ( _quietFail=1; _assertValidOAuthService nullService ) &> /dev/null || caught=1
    (( caught == 1 )) || fail "validation should fail when a key has value 'null'"
}

# --- Provider validation ---

testProviderNameCaseInsensitive() {
    # getOAuthService lowercases the provider name, so the auth/token URL vars
    # should resolve correctly regardless of input case
    local upperVarName="_${ echo "GOOGLE" | tr '[:upper:]' '[:lower:]'; }AuthUrl"
    assertEqual "${upperVarName}" "_googleAuthUrl" "lowercased provider var name"
    varIsDefined "${upperVarName}" || fail "lowercased Google auth URL var should be defined"
}

# --- Service map structure ---

testServiceMapStructure() {
    # Manually construct a service map as getOAuthService would and verify its structure
    local -A service=(
        [${_oAuthProviderKey}]="google"
        [${_oAuthScopeKey}]="https://www.googleapis.com/auth/gmail.readonly"
        [${_oAuthIdKey}]="test-id"
        [${_oAuthSecretKey}]="test-secret"
        [${_oAuthUrlKey}]="${_googleAuthUrl}"
        [${_oAuthTokenKey}]="${_googleTokenUrl}"
    )

    # Validate using the library's own validator
    _assertValidOAuthService service

    # Verify values match expected keys
    assertEqual "${service[providerName]}" "google" "provider via key constant"
    assertEqual "${service[authUrl]}" "${_googleAuthUrl}" "auth URL via key constant"
    assertEqual "${service[tokenUrl]}" "${_googleTokenUrl}" "token URL via key constant"

    # Verify all keys are present
    local key
    for key in "${_oAuthServiceKeys[@]}"; do
        [[ -n "${service[${key}]}" ]] || fail "key '${key}' should have a value"
    done
}

# --- getOAuthService ---

testGetOAuthServiceGoogle() {
    local -A myService=()
    getOAuthService "google" myService \
        "https://www.googleapis.com/auth/gmail.readonly" \
        "test-client-id" \
        "test-client-secret"

    assertEqual "${myService[providerName]}" "google" "provider should be 'google'"
    assertEqual "${myService[scope]}" "https://www.googleapis.com/auth/gmail.readonly" "scope"
    assertEqual "${myService[clientId]}" "test-client-id" "client ID"
    assertEqual "${myService[clientSecret]}" "test-client-secret" "client secret"
    assertEqual "${myService[authUrl]}" "${_googleAuthUrl}" "auth URL"
    assertEqual "${myService[tokenUrl]}" "${_googleTokenUrl}" "token URL"

    # Verify the resulting map passes validation
    _assertValidOAuthService myService
}

testGetOAuthServiceWithEnvCredentials() {
    # Test that environment variables are picked up when no explicit credentials given
    local -A myService=()
    GOOGLE_CLIENT_ID="env-client-id" GOOGLE_CLIENT_SECRET="env-client-secret" \
        getOAuthService "google" myService "https://www.googleapis.com/auth/gmail.readonly"

    assertEqual "${myService[clientId]}" "env-client-id" "client ID from env"
    assertEqual "${myService[clientSecret]}" "env-client-secret" "client secret from env"
}

# --- _findFreePort ---

testFindFreePort() {
    local port
    port=${ _findFreePort; }
    [[ -n "${port}" ]] || fail "_findFreePort should return a port"
    (( port >= 8080 && port <= 8180 )) || fail "port ${port} should be in range 8080-8180"
}

testFindFreePortCustomRange() {
    local port
    port=${ _findFreePort 9090 9100; }
    [[ -n "${port}" ]] || fail "_findFreePort should return a port in custom range"
    (( port >= 9090 && port <= 9100 )) || fail "port ${port} should be in range 9090-9100"
}

# --- _oAuthSuccessHtml ---

testOAuthSuccessHtml() {
    local html
    html=${ _oAuthSuccessHtml; }
    [[ -n "${html}" ]] || fail "HTML should not be empty"
    [[ ${html} == *"<!DOCTYPE html>"* ]] || fail "HTML should start with DOCTYPE"
    [[ ${html} == *"Authorization Successful"* ]] || fail "HTML should contain 'Authorization Successful'"
    [[ ${html} == *"close this window"* ]] || fail "HTML should instruct user to close window"
    [[ ${html} == *"</html>"* ]] || fail "HTML should contain closing html tag"
}

doNotSetFunctionsReadOnly=1
source rayvn.up 'rayvn/test' 'rayvn/oauth'
main "$@"
