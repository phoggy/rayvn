#!/usr/bin/env bash

# Library for dependency management.
# Intended for use via: require 'rayvn/dependency'

require 'rayvn/core' 'rayvn/safe-env'

printBrewDependencies() {
    local key
    for key in "${!_rayvnProjects[@]}"; do
        if [[ ${key} == *::project ]]; then
            local projectName="${key%%::*}"
            (
                _printProjectBrewDependencies "${projectName}"
            )
        fi
    done
}

assertDependencies() {
    local key
    for key in "${!_rayvnProjects[@]}"; do
        if [[ ${key} == *::project ]]; then
            local projectName="${key%%::*}"
            (
                _getProjectDependencies "${projectName}"
                echo -n "checking project '${projectName}' dependencies "
                _assertExecutables projectDependencies
                echo "${_greenCheckMark}"
            )
        fi
    done
}

UNSUPPORTED="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_assertExecutables() {
    local dependenciesVarName="${1}"
    declare -n deps="${dependenciesVarName}"
    for key in "${!deps[@]}"; do
        if [[ ${key} == *_extract$ ]]; then
            _assertExecutable "${key%_extract}" "${dependenciesVarName}"
        fi
    done
}

_printProjectBrewDependencies() {
    local key executable brew tap url rayvnDep
    local projectName="${1}"
    local executables=()
    local nonRayvnExecutables=()
    _getProjectDependencies "${projectName}"

    # Collect rayvn and non-rayvn executables then append to keep rayvn dependencies first

    for key in "${!projectDependencies[@]}"; do
        if [[ ${key} == *_min ]]; then
            executable="${key%_min}"
            url=${projectDependencies[${executable}_url]}
            if [[ ${url} == */github.com/phoggy/* ]]; then
                executables+=("${executable}")
            else
                nonRayvnExecutables+=("${executable}")
            fi
        fi
    done
    executables+=("${nonRayvnExecutables[@]}")

    for executable in "${executables[@]}"; do
        brew=${projectDependencies[${executable}_brew]}
        tap=${projectDependencies[${executable}_brew_tap]}
        if [[ -n "${tap}" ]]; then
            echo "    depends_on \"${tap}/${executable}\""
        elif [[ ${brew} == true ]]; then
            echo "    depends_on \"${executable}\""
        elif brew which-formula "${executable}" &> /dev/null; then
            echo "    depends_on \"${executable}\""
        else
            url=${projectDependencies[${executable}_url]}
            fail "${executable} is not available from brew. Maybe there is a tap? See ${url}"
        fi
    done
}

_getProjectDependencies() {
    local projectName="${1}"
    local pkgFile="${_rayvnProjects[${projectName}${_projectRootSuffix}]}/rayvn.pkg"
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
    local dependenciesVarName="${2}"
    declare -n deps="${dependenciesVarName}"
    local defaultMin="${deps[${executable}_min]}"
    local minVersion="${3:-${defaultMin}}"
    if [[ ${defaultMin} != '' ]]; then
        _assertExecutableFound "${executable}" ${dependenciesVarName}
        local extractMethod="${deps[${executable}_extract]}"
        if [[ ${minVersion} != 0 ]]; then
            local version=$(_extractVersion ${executable} ${extractMethod})
            local errMsg=":"
            if [[ ${brewIsInstalled} && ${deps[${executable}_brew]} == true ]]; then
                errMsg+=" try 'brew update ${executable}' or see"
            else
                errMsg+=" see"
            fi
            errMsg+=" ${deps[${executable}_url]}"

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
    if ! command -v ${executable} &>/dev/null; then
        local errMsg="${executable} not found."
        if [[ ${brewIsInstalled} && ${deps[${executable}_brew]} == true ]]; then
            local tap="${deps[${executable}_brew_tap]}"
            if [[ ${tap} ]]; then
                errMsg+=" Try 'brew tap ${tap} && brew install ${executable}' or see"
            else
                errMsg+=" Try 'brew install ${executable}' or see"
            fi
        else
            errMsg+=" See"
        fi
        errMsg+=" ${deps[${executable}_url]} "
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
