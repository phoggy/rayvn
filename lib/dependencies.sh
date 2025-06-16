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
    local errMsg
    (( ! quiet )) && echo -n "Checking $(ansi bold ${projectName}) project dependencies: "

    # Load project dependencies and assert that all projects referenced in require calls are present

    _assertRequiredProjects "${projectName}"

    # Check all
    for key in "${!projectDependencies[@]}"; do
        if [[ ${key} == *_url ]]; then
            local name="${key%_url}"
            local extract=${projectDependencies[${name}_extract]}
            local brew=${projectDependencies[${name}_brew]}

            if [[ -n "${extract}" ]]; then
                _assertExecutable "${name}"
            elif [[ ${brew} == true ]]; then
                _assertBrewInstall "${name}"
            else
                fail "unknown dependency: ${key}"
            fi
        fi
    done
    (( ! quiet )) && echo "${_greenCheckMark}"
}

_assertBrewInstall() {
    local name="${1}"
    if (( _brewIsInstalled )); then
        if ! brew info ${name} &> /dev/null; then
            _failNotFound "${name}"
        fi
    else
        _failNotFound "${name}"
    fi
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
            else
                dep="${depName}"
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
        6) brew info ${command} 2>&1 | tail -n 1 | cut -d' ' -f3 ;;
        *) fail "unknown version extract method: ${method}" ;;
    esac
}

_assertExecutable() {
    local name="${1}"
    local minVersion="${projectDependencies[${name}_min]}"
    if [[ -n "${minVersion}" ]]; then
        _assertExecutableFound "${name}"
        local extractMethod="${projectDependencies[${name}_extract]}"
        if [[ ${minVersion} != 0 ]]; then
            local version=$(_extractVersion ${name} ${extractMethod})
            _assertMinimumVersion ${minVersion} ${version} "${name}"
        fi
    else
        fail "unknown dependency: ${name}"
    fi
}

_assertExecutableFound() {
    local executable="${1}"
    if ! command -v ${executable} &> /dev/null; then
        _failNotFound "${executable}"
    fi
}

_assertMinimumVersion() {
    local minimum="${1}"
    local version="${2}"
    local targetName="${3}"
    local lowest=$(printf '%s\n%s\n' "${version}" "${minimum}" | sort -V | head -n 1)
    if [[ "${lowest}" != "${minimum}" ]]; then
        local errMsg="requires ${targetName} version >= ${minimum}, found ${lowest}"
        _dependencyFailed "${targetName}" "${errMsg}" 1
    fi
    return 0
}

_failNotFound() {
    local target="${1}"
    local errMsg="${target} not found"
    _dependencyFailed "${1}" "${errMsg}" 0
}

_dependencyFailed() {
    local target="${1}"
    local errMsg="${2}."
    declare -i update=${3:-0}
    local url="${projectDependencies[${target}_url]}"
    local brew="${projectDependencies[${target}_brew]}"
    local tap="${projectDependencies[${target}_tap]}"
    declare -i appendedMsg=0

    if [[ ${brew} == true ]]; then
        if (( _brewIsInstalled )); then
            local command=
            if (( update )); then
                command="brew update ${target} && brew install ${target}"
            elif [[ -n ${tap} ]]; then
                command="brew tap ${tap} && brew install ${target}"
            else
                command="brew install ${target}"
            fi
            errMsg+=" Try '${command}'"
            appendedMsg=1
        else
            fail "Homebrew is required, see https://brew.sh/"
        fi
    fi
    if [[ -n ${url} ]]; then
        if (( appendedMsg )); then
            errMsg+=" or see ${url}"
        else
            errMsg+=" See ${url}"
        fi
    fi

    fail "${errMsg}"
}
