#!/usr/bin/env bash

# Library for dependency management.
# Intended for use via: require 'rayvn/dependency'

require 'rayvn/core' 'rayvn/safe-env'

listBrewDependencies() {
    local projectName="${1:-}"
    (
        if [[ -n "${projectName}" ]]; then
            _listProjectBrewDependencies "${projectName}"
        else
            local key
            for key in "${!_rayvnProjects[@]}"; do
                if [[ ${key} == *::project ]]; then
                    projectName="${key%%::*}"
                    _listProjectBrewDependencies "${projectName}"
                fi
            done
        fi
    )
}

assertProjectDependencies() {
    local projectName="${1}"
    declare -i verbose="${2:-0}"
    (
        if [[ -n "${projectName}" ]]; then
            _assertProjectDependencies "${projectName}" "${verbose}"
        else
            local key
            for key in "${!_rayvnProjects[@]}"; do
                if [[ ${key} == *::project ]]; then
                    projectName="${key%%::*}"
                    _assertProjectDependencies "${projectName}" "${verbose}"
                fi
            done
        fi
    )
}

UNSUPPORTED="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_assertProjectDependencies() {
    local projectName="${1}"
    declare -i verbose="${2:-0}"
    (( verbose )) && echo -n "checking project '${projectName}' dependencies "
    _setProjectDependencies "${projectName}"
    for key in "${!projectDependencies[@]}"; do
        if [[ ${key} == *_extract$ ]]; then
            _assertExecutable "${key%_extract}"
        fi
    done
    (( verbose )) && echo "${_greenCheckMark}"
}

_listProjectBrewDependencies() {
    local projectName="${1}"
    local dependencies=()
    _collectBrewDependencies "${projectName}" dependencies
    echo "$(ansi bold ${projectName}) ${dependencies[*]}"
}

_collectBrewDependencies() {
    local key executable brew tap url dep
    local projectName="${1}"
    local -n resultVar="${2}"
    local rayvnDeps=()
    local nonRayvnDeps=()
    _setProjectDependencies "${projectName}"

    # Collect rayvn and non-rayvn rayvnDeps then append to keep rayvn dependencies first

    for key in "${!projectDependencies[@]}"; do
        if [[ ${key} == *_min ]]; then
            executable="${key%_min}"
            brew=${projectDependencies[${executable}_brew]}
            tap=${projectDependencies[${executable}_brew_tap]}
            url=${projectDependencies[${executable}_url]}

            if [[ -n "${tap}" ]]; then
                dep="${tap}/${executable}"
            elif [[ ${brew} == true ]]; then
                dep="${executable}"
            elif brew which-formula "${executable}" &> /dev/null; then
                dep="${executable}"
            else
                fail "${executable} is not available from brew. Maybe there is a tap? See ${url}"
            fi

            if [[ ${url} == */github.com/phoggy/* ]]; then
                rayvnDeps+=("${dep}")
            else
                nonRayvnDeps+=("${dep}")
            fi
        fi
    done

    resultVar+=("${rayvnDeps[@]}" "${nonRayvnDeps[@]}")
}

_setProjectDependencies() {
    local projectName="${1}"
    local projectRoot="${_rayvnProjects[${projectName}${_projectRootSuffix}]}"
    [[ -n "${projectRoot}" ]] || fail "project '${projectName}' not found"
    local pkgFile="${projectRoot}/rayvn.pkg"
    assertFileExists "${pkgFile}"
    sourceSafeStaticVars "${pkgFile}" project
    if ! declare -p projectDependencies &> /dev/null; then
        fail "No projectDependencies found in '${pkgFile}'"
    fi
}

_extractVersion() {
    local command="${1}"
    local method="${2}"

    case "${method}" in
        0) echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}" ;;
        1) ${command} --version 2>&1 | head -n 1 | cut -d' ' -f2 ;;
        2) ${command} --version 2>&1 | head -n 1 | cut -d' ' -f3 ;;
        3) ${command} -version 2>&1 | tail -n 1 | cut -d' ' -f3 ;;
        4) ${command} --version 2>&1 | tail -n 1 | cut -d'-' -f2 ;;
        5) ${command} -ver 2>&1 ;;
        *) fail "unknown version extract method: ${method}" ;;
    esac
}

_assertExecutable() {
    local executable="${1}"
    local minVersion="${projectDependencies[${executable}_min]}"
    if [[ -n "${minVersion}" ]]; then
        _assertExecutableFound "${executable}"
        local extractMethod="${projectDependencies[${executable}_extract]}"
        if [[ ${minVersion} != 0 ]]; then
            local version=$(_extractVersion ${executable} ${extractMethod})
            local errMsg=":"
            if [[ ${brewIsInstalled} && ${projectDependencies[${executable}_brew]} == true ]]; then
                errMsg+=" try 'brew update ${executable}' or see"
            else
                errMsg+=" see"
            fi
            errMsg+=" ${projectDependencies[${executable}_url]}"

            _assertMinimumVersion ${minVersion} ${version} "${executable}" "${errMsg}"
        fi
    else
        assertFail "unregistered dependency: ${executable}"
    fi
}

_assertExecutableFound() {
    local executable="${1}"
    if ! command -v ${executable} &>/dev/null; then
        local errMsg="${executable} not found."
        if [[ ${brewIsInstalled} && ${projectDependencies[${executable}_brew]} == true ]]; then
            local tap="${projectDependencies[${executable}_brew_tap]}"
            if [[ ${tap} ]]; then
                errMsg+=" Try 'brew tap ${tap} && brew install ${executable}' or see"
            else
                errMsg+=" Try 'brew install ${executable}' or see"
            fi
        else
            errMsg+=" See"
        fi
        errMsg+=" ${projectDependencies[${executable}_url]} "
        assertFail "${errMsg}"
    fi
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
