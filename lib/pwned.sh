#!/usr/bin/env bash

# Library supporting password/phrase generation
# Intended for use via: require 'rayvn/pwned'

require 'rayvn/core'

init_rayvn_pwned() {
    declare -A dependencies=(

        [curl_min]='7.76.0'
        [curl_brew]=true
        [curl_install]='https://curl.se/dlwiz/?type=bin'
        [curl_version]='versionExtract'
    )

    assertExecutables dependencies
}

readonly pwnedPasswordsApiUrl='https://api.pwnedpasswords.com'

hasNotBeenPwned() {
    local pass="${1}"
    local hash=$(echo -n "${pass}" | shasum | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
    local prefix=${hash:0:5}
    local suffix=${hash:5}
    local results=$(curl -m 10 -s -H 'Add-Padding: true' "${pwnedPasswordsApiUrl}/range/${prefix}")
    if [[ ! ${results} ]]; then
        return 1  # Unable to check
    fi

    local match=$(echo "${results}" | grep ${suffix} )
    if [[ ${match} ]]; then
        local count=$(echo "${match}" | cut -d':' -f2)
        if [[ ${count} != 0 ]]; then
            return 2  # has been pwned
        fi
    fi
    return 0 # has not been pwned
}
