#!/usr/bin/env bash

# Library for dependency management.
# Intended for use via: require 'rayvn/dependency'

require 'rayvn/core' 'rayvn/safe-env'

assertProjectDependencies() {
    local -n projectsArrayRef="${1}"
    declare -i quiet="${2:-0}"
    local projectName
    (
        for projectName in "${projectsArrayRef[@]}"; do
            _assertProjectDependencies "${projectName}" "${quiet}"
        done
    )
}

listProjectDependencies() {
    local -n projectsArrayRef="${1}"
    local dependencies=()
    local minVersions=()
    local projectName i source name tap minVersion line
    (
        for projectName in "${projectsArrayRef[@]}"; do
            _collectProjectDependencies "${projectName}" dependencies minVersions
            echo
            echo "$(ansi bold ${projectName})"
            echo
            for (( i = 0; i < ${#dependencies[@]}; i++ )); do
                source="${dependencies[i]}"
                name="${source##*/}"
                tap="${source%/*}"
                minVersion=${minVersions[i]}
                line="${name} ${minVersion}"
                [[ ${tap} == */* ]] && line+=" (tap '${tap}')"

                echo "${line}"
            done
        done
    )
}

UNSUPPORTED="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_assertProjectDependencies() {
    local projectName="${1}"
    declare -i quiet="${2:-0}"
    (( ! quiet )) && echo -n "Checking $(ansi bold ${projectName}) project dependencies: "
    _setProjectDependencies "${projectName}"
    for key in "${!projectDependencies[@]}"; do
        if [[ ${key} == *_extract ]]; then
            _assertExecutable "${key%_extract}"
        fi
    done
    (( ! quiet )) && echo "${_greenCheckMark}"
}

_collectProjectDependencies() {
    local key executable brew tap url dep brewName depName
    local projectName="${1}"
    local -n dependenciesRef="${2}"
    local -n minVersionsRef="${3}"
    local useBrewName="${4:-false}"
    local rayvnDeps=()
    local nonRayvnDeps=()
    local minVers=()
    _setProjectDependencies "${projectName}"

    # Collect rayvn and non-rayvn dependencies then append to keep rayvn dependencies first

    for key in "${!projectDependencies[@]}"; do
        if [[ ${key} == *_min ]]; then
            executable="${key%_min}"
            brewName=${projectDependencies[${executable}_brew_name]:-${executable}}
            brew=${projectDependencies[${executable}_brew]}
            tap=${projectDependencies[${executable}_brew_tap]}
            url=${projectDependencies[${executable}_url]}
            minVers+=("${projectDependencies[${executable}_min]}")

            [[ ${useBrewName} == true ]] && depName="${brewName}" || depName="${executable}"
            if [[ -n "${tap}" ]]; then
                dep="${tap}/${depName}"
            elif [[ ${brew} == true ]]; then
                dep="${depName}"
            elif brew which-formula "${depName}" &> /dev/null; then
                dep="${depName}"
            else
                fail "${depName} is not available from brew. Maybe there is a tap? See ${url}"
            fi

            if [[ ${url} == */github.com/phoggy/* ]]; then
                rayvnDeps+=("${dep}")
            else
                nonRayvnDeps+=("${dep}")
            fi
        fi
    done

    dependenciesRef=("${rayvnDeps[@]}" "${nonRayvnDeps[@]}")
    minVersionsRef=("${minVers[@]}")
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
                local brewName=${projectDependencies[${executable}_brew_name]:-${executable}}
                errMsg+=" try 'brew update ${brewName}' or see"
            else
                errMsg+=" see"
            fi
            errMsg+=" ${projectDependencies[${executable}_url]}"

            _assertMinimumVersion ${minVersion} ${version} "${executable}" "${errMsg}"
        fi
    else
        fail "unregistered dependency: ${executable}"
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
        fail "${errMsg}"
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
