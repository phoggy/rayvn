#!/usr/bin/env bash

# Library for dependency management.
# Intended for use via: require 'rayvn/dependency'

require 'rayvn/core'

assertExecutables() {
    local dependenciesVarName="${1}"
    declare -n deps="${dependenciesVarName}"
    for name in "${!deps[@]}"; do
        if [[ ${name} =~ _extract$ ]]; then
            _assertExecutable "${name%_extract}" "${dependenciesVarName}"
        fi
    done
}

_assertMinimumVersion() {
    local minimum="${1}"
    local version="${2}"
    local targetName="${3}"
    local errorSuffix="${4}"
    local lowest=$(printf '%s\n%s\n' "${version}" "${minimum}" | sort -V | head -n 1)
    [[ "${lowest}" != "${minimum}" ]] && assertionFailed "requires ${targetName} version >= ${minimum}, found ${lowest} ${errorSuffix}"
    return 0
}

assertBashVersion() {
    local minVersion="${1:-5}"
    _assertMinimumVersion "${minVersion}" "${BASH_VERSINFO:-0}" "bash" "at ${BASH} (update PATH to fix)"
}

extractVersion() {
    local command="${1}"
    local method="${2}"

    case "${method}" in
        0) echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}" ;;
        1) ${command} --version 2>&1 | head -n 1 | cut -d' ' -f2 ;;
        2) ${command} --version 2>&1 | head -n 1 | cut -d' ' -f3 ;;
        3) ${command} -version 2>&1 | tail -n 1 | cut -d' ' -f3 ;;
        4) ${command} --version 2>&1 | tail -n 1 | cut -d'-' -f2 ;;
        5) ${command} -ver 2>&1 ;;
        *) fail "unknown extract method: ${method}"
    esac
}

_assertExecutable() {
    local executable="${1}"
    local dependenciesVarName="${2}"
    declare -n deps="${dependenciesVarName}"
    local defaultMin="${deps[${executable}_min]}"
    local minVersion="${3:-${defaultMin}}"
    if [[ ${defaultMin} != '' ]]; then
        _assertExecutableFound "${executable}" ${dependenciesVarName}
        local extractMethod="${deps[${executable}_extract]}"
        if [[ ${minVersion} != 0 ]]; then
            local version=$(extractVersion ${executable} ${extractMethod})
            local errMsg=":"
            if [[ ${brewInstalled} && ${deps[${executable}_brew]} == true ]]; then
                errMsg+=" try 'brew update ${executable}' or see"
            else
                errMsg+=" see"
            fi
            errMsg+=" ${deps[${executable}_install]}"

            _assertMinimumVersion ${minVersion} ${version} "${executable}" "${errMsg}"
        fi
    else
        assertFail "unregistered dependency: ${executable}"
    fi
}

_assertExecutableFound() {
    local executable="${1}"
    local dependenciesVarName="${2}"
    declare -n deps="${dependenciesVarName}"
    if ! command -v ${executable} &> /dev/null; then
        local errMsg="${executable} not found."
        if [[ ${brewInstalled} && ${deps[${executable}_brew]} == true ]]; then
            local tap="${deps[${executable}_brew_tap]}"
            if [[ ${tap} ]]; then
                errMsg+=" Try 'brew tap ${tap} && brew install ${executable}' or see"
            else
                errMsg+=" Try 'brew install ${executable}' or see"
            fi
        else
            errMsg+=" See"
        fi
        errMsg+=" ${deps[${executable}_install]} "
        assertFail "${errMsg}"
    fi
}
