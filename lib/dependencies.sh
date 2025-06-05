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

    # Load project dependencies and assert that all projects referenced in require calls are present

    _assertRequiredProjects "${projectName}"

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

    # Load project dependencies and assert that all projects referenced in require calls are present

    _assertRequiredProjects "${projectName}"

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

_getProjectPath() {
    local projectName="${1}"
    local -n projectPathRef="${2}"
    local relativePath="${3:-}"
    local root="${_rayvnProjects[${projectName}${_projectRootSuffix}]}"
    [[ -n "${root}" ]] || fail "project '${projectName}' not found"
    if [[ -n "${relativePath}" ]]; then
        projectPathRef="${root}/${relativePath}"
    else
        projectPathRef="${root}"
    fi
}

_setProjectDependenciesVar() {
    local projectName="${1}"
    local pkgFile
    _getProjectPath "${projectName}" pkgFile 'rayvn.pkg'
    assertFileExists "${pkgFile}"
    sourceSafeStaticVars "${pkgFile}" project
    if ! declare -p projectDependencies &> /dev/null; then
        fail "No projectDependencies found in '${pkgFile}'"
    fi
}

_assertRequiredProjects() {
    local projectName="${1}"
    local projectRequires=()
    local require project
    _setProjectDependenciesVar "${projectName}"
    _collectProjectRequires "${projectName}" projectRequires

    # OK, we have all required libraries, now assert that there is already a dependency

    for require in "${projectRequires[@]}"; do
        project="${require%%/*}"
        if [[ ${project} != "${projectName}" && -z ${projectDependencies[${project}_extract]} ]]; then
            fail "${projectName}/rayvn.pkg projectDependencies is missing entries for ${project}: requires '${require}'"
        fi
    done
}

_collectProjectRequires() {
    local projectName="${1}"
    local -n resultArrayRef="${2}"
    local projectRoot
    local file
    local _required=()
    declare -A seen=()
    _getProjectPath "${projectName}" projectRoot
    for file in "${projectRoot}"/bin/*; do
        _collectFileRequires "${file}" _required seen
    done
    for file in "${projectRoot}"/lib/*.sh; do
        _collectFileRequires "${file}" _required seen
    done
    resultArrayRef=("${_required[@]}")
}

_collectFileRequires() {
    local filePath="${1}"
    local -n outArrayRef="${2}"
    local -n seenRef="${3}"
    local firstLine line
    local result=()

    # Verify file exists and is readable
    [[ -r "${filePath}" ]] || fail "not readable: ${filePath}"

    # Check shebang
    IFS= read -r firstLine < "${filePath}"
    if [[ "${firstLine}" != '#!/usr/bin/env bash'* ]]; then
        warn "missing or invalid shebang in ${filePath}, skipping"
        return 0
    fi

    # Parse for require calls
    while IFS= read -r line || [[ -n "${line}" ]]; do
        # Remove inline comments
        line="${line%%#*}"
        [[ -z "${line//[[:space:]]/}" ]] && continue

        # Match both require ... and source rayvn.up ...
        if [[ ${line} =~ ^[[:space:]]*(require|source[[:space:]]+rayvn\.up)[[:space:]] ]]; then
            while [[ ${line} =~ [\'\"]([a-zA-Z0-9_./-]+)[\'\"] ]]; do
                local lib="${BASH_REMATCH[1]}"
                if [[ -z ${seenRef["${lib}"]+_} ]]; then
                    result+=("${lib}")
                    seenRef["${lib}"]=1
                fi
                line="${line#*\'${lib}\'}"
            done
        fi
    done < "${filePath}"

    outArrayRef+=("${result[@]}")
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
