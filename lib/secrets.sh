#!/usr/bin/env bash

# Secure credential storage library using system keychains.
# Intended for use via: require 'rayvn/secrets'

# Store a secret in the system keychain
# Usage: secretStore <service> <account> <secret>
secretStore() {
    local service="${1}"
    local account="${2}"
    local secret="${3}"

    if (( onMacOS )); then
        _secretStoreMacOS "${service}" "${account}" "${secret}"
    elif (( onLinux )); then
        _secretStoreLinux "${service}" "${account}" "${secret}"
    else
        fail "Unsupported platform for secret storage"
    fi
}

# Retrieve a secret from the system keychain
# Usage: secretRetrieve <service> <account>
# Returns: The secret value, or empty string if not found
secretRetrieve() {
    local service="${1}"
    local account="${2}"

    if (( onMacOS )); then
        _secretRetrieveMacOS "${service}" "${account}"
    elif (( onLinux )); then
        _secretRetrieveLinux "${service}" "${account}"
    else
        fail "Unsupported platform for secret retrieval"
    fi
}

# Delete a secret from the system keychain
# Usage: secretDelete <service> <account>
secretDelete() {
    local service="${1}"
    local account="${2}"

    if (( onMacOS )); then
        _secretDeleteMacOS "${service}" "${account}"
    elif (( onLinux )); then
        _secretDeleteLinux "${service}" "${account}"
    else
        fail "Unsupported platform for secret deletion"
    fi
}

# Check if a secret exists in the system keychain
# Usage: secretExists <service> <account>
# Returns: 0 if exists, 1 if not
secretExists() {
    local service="${1}"
    local account="${2}"

    local secret
    secret=${ secretRetrieve "${service}" "${account}"; }
    [[ -n "${secret}" ]]
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/secrets' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_secrets() {
    require 'rayvn/core'
}

# macOS keychain operations using security command

_secretStoreMacOS() {
    local service="${1}"
    local account="${2}"
    local secret="${3}"

    # Delete existing entry if present (security add-generic-password fails if exists)
    _secretDeleteMacOS "${service}" "${account}" 2> /dev/null

    # Add new entry
    security add-generic-password \
        -a "${account}" \
        -s "${service}" \
        -w "${secret}" \
        -U > /dev/null 2>&1 || fail "Failed to store secret in macOS keychain"
}

_secretRetrieveMacOS() {
    local service="${1}"
    local account="${2}"

    local secret
    secret=${ security find-generic-password \
        -a "${account}" \
        -s "${service}" \
        -w 2> /dev/null; }

    echo "${secret}"
}

_secretDeleteMacOS() {
    local service="${1}"
    local account="${2}"

    security delete-generic-password \
        -a "${account}" \
        -s "${service}" \
        > /dev/null 2>&1 || true
}

# Linux secret-tool operations using libsecret

_secretStoreLinux() {
    local service="${1}"
    local account="${2}"
    local secret="${3}"

    # Check if secret-tool is available
    if ! command -v secret-tool > /dev/null 2>&1; then
        fail "secret-tool not found. Install libsecret-tools package"
    fi

    # Store secret (will replace if exists)
    echo -n "${secret}" | secret-tool store \
        --label="${service}:${account}" \
        service "${service}" \
        account "${account}" || fail "Failed to store secret in Linux keyring"
}

_secretRetrieveLinux() {
    local service="${1}"
    local account="${2}"

    # Check if secret-tool is available
    if ! command -v secret-tool > /dev/null 2>&1; then
        fail "secret-tool not found. Install libsecret-tools package"
    fi

    local secret
    secret=${ secret-tool lookup \
        service "${service}" \
        account "${account}" 2> /dev/null; }

    echo "${secret}"
}

_secretDeleteLinux() {
    local service="${1}"
    local account="${2}"

    # Check if secret-tool is available
    if ! command -v secret-tool > /dev/null 2>&1; then
        return 0  # Silently succeed if tool not available
    fi

    secret-tool clear \
        service "${service}" \
        account "${account}" \
        2> /dev/null || true
}
