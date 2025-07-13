#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library supporting common functionality
# Intended for use via: require 'rayvn/core'

if (( ! _rayvnCoreGlobalsSet )); then

    # Setup exit handling

    declare -g _rayvnExitTasks=()
    trap '_onExit' EXIT
    trap '_onTerm' TERM
    trap '_onHup' HUP
    trap '_onInt' INT

    # We need to set ${terminal} so that it can be used as a redirect.
    # Are stdout and stderr both terminals?

    if [[ -t 1 && -t 2 ]]; then

        # Yes, so set terminal to the tty and remember that ANSI is supported.

        declare -grx terminal="/dev/tty"
        declare -grxi terminalSupportsAnsi=1

    else

        # No. Ensure FD 3 exists and points to original stdout, then set terminal
        # to use it and remember that ANSI is not supported.

        [[ -t 3 ]] || exec 3>&1
        declare -grx terminal="&3"
        declare -grxi terminalSupportsAnsi=0
    fi

    # Set some constants

    declare -grx osName="$(uname)"
    declare -grxi onMacOS=$(( osName == "Darwin" ))
    declare -grxi onLinux=$(( osName == "Linux" ))
    declare -grx rayvnRootDir="$(realpath "${BASH_SOURCE%/*}/..")"
    declare -grx rayvnConfigDirPath="${HOME}/.rayvn"
    declare -grx _checkMark='✔'
    declare -grx _crossMark='✗'
    declare -gxi _debug=0

    # Set ANSI related constants

    if (( terminalSupportsAnsi)); then

        # Set ANSI colors if terminal supports them

        if (( $(tput colors) >= 8 )); then
            declare -grx ansi_normal="$(tput sgr0)"

            declare -grx ansi_bold="$(tput bold)"
            declare -grx ansi_underline="$(tput smul)"
            declare -grx ansi_italic=$'\e[3m'
            declare -grx ansi_black="$(tput setaf 0)"
            declare -grx ansi_dim=$'\e[2m'

            declare -grx ansi_red="$(tput setaf 1)"
            declare -grx ansi_green="$(tput setaf 2)"
            declare -grx ansi_yellow="$(tput setaf 3)"
            declare -grx ansi_blue="$(tput setaf 4)"
            declare -grx ansi_magenta="$(tput setaf 5)"
            declare -grx ansi_cyan="$(tput setaf 6)"
            declare -grx ansi_white="$(tput setaf 7)"

            declare -grx ansi_italic_cyan="${ansi_italic}${ansi_cyan}"
            declare -grx ansi_italic_red="${ansi_italic}${ansi_red}"

            declare -grx ansi_bold_red="${ansi_bold}${ansi_red}"
            declare -grx ansi_bold_green="${ansi_bold}${ansi_green}"
            declare -grx ansi_bold_yellow="${ansi_bold}${ansi_yellow}"
            declare -grx ansi_bold_blue="${ansi_bold}${ansi_blue}"
            declare -grx ansi_bold_magenta="${ansi_bold}${ansi_magenta}"
            declare -grx ansi_bold_cyan="${ansi_bold}${ansi_cyan}"
            declare -grx ansi_bold_white="${ansi_bold}${ansi_white}"
            declare -grx ansi_bold_italic="${ansi_bold}${ansi_italic}"
        fi

        declare -grx _greenCheckMark="${ansi_bold_green}${_checkMark}${ansi_normal}"
        declare -grx _redCrossMark="${ansi_bold_red}${_crossMark}${ansi_normal}"

    else

        declare -grx _greenCheckMark="${_checkMark}"
        declare -grx _redCrossMark="${_crossMark}"
    fi

    # Is this a mac?

    if [[ ${osName,,} == "darwin" ]]; then

        # Yes, remember if brew is available

        if command -v brew > /dev/null; then
            declare -grxi _brewIsInstalled=1
        fi
    elif [[ ! -v RAYVN_NO_OS_CHECK ]]; then

        # No, so warn!

        echo "⚠️ This code contains MacOS specific functionality and likely will not work here."
        echo
        echo "   This warning can be bypassed by exporting RAYVN_NO_OS_CHECK=true"
        echo "   but be aware that some functionality may not work correctly."
        echo
    fi

    declare -grxi _rayvnCoreGlobalsSet=1
fi

allNewFilesUserOnly() {
    # Ensure that all new files are accessible by the current user only
    umask 0077
}

withDefaultUmask() {
    withUmask 0022 "${@}"
}

withUmask() {
    local newUmask="${1}"
    local oldUmask status
    shift

    # Save umask and set to new

    oldUmask="$(umask)"
    umask "${newUmask}"

    # execute the command and save the status

    "${@}"
    status=${?}

    # Restore the original umask and return command status
    umask "${oldUmask}"
    return "${status}"
}

rootDirPath() {
    echo "${rayvnRootDir}/${1}"
}

tempDirPath() {
    ensureTempDir
    local fileName="${1:-}"
    [[ ${fileName} ]] && echo "${_rayvnTempDir}/${fileName}" || echo "${_rayvnTempDir}"
}

ensureTempDir() {
    if [[ -z ${_rayvnTempDir:-} ]]; then
        declare -grx _rayvnTempDir="$(withUmask 0077 mktemp -d)" || fail "could not create temp directory"
        chmod 700 "${_rayvnTempDir}" || fail "chmod failed on temp dir"
    fi
}

makeTempFile() {
    ensureTempDir
    local fileName="${1:-XXXXXXXXXXX}" # create random file name if not present
    local file="$(mktemp "${_rayvnTempDir}/${fileName}")"
   # chmod 600 "${file}" || fail "chmod failed on ${file}"
    echo "${file}"
}

makeTempDir() {
    ensureTempDir
    local dirName="${1:-XXXXXXXXXXX}" # create random dir name if not present
    local directory="$(mktemp "${_rayvnTempDir}/${dirName}")"
    echo "${directory}"
}

configDirPath() {
    local fileName="${1:-}"
    if [[ -z ${_rayvnConfigDir:-} ]]; then
        local configDir="${rayvnConfigDirPath}"
        [[ ${currentProjectName} != rayvn ]] && configDir+="/${currentProjectName}"
        withUmask 0077 ensureDir "${configDir}"
        _rayvnConfigDir="${configDir}"
    fi
    [[ -n ${fileName} ]] && echo "${_rayvnConfigDir}/${fileName}" || echo "${_rayvnConfigDir}"
}

ensureDir() {
    local dir="${1}"
    if [[ ! -d ${dir} ]]; then
        makeDir "${dir}" > /dev/null
    fi
}

makeDir() {
    local dir="${1}"
    [[ -z ${2:-} ]] && dir="${1}/${2}"
    mkdir -p "${dir}" || fail "could not create directory ${dir}"
    echo "${dir}"
}

assertAnsiSupported() {
    (( terminalSupportsAnsi )) || assertionFailed "must be run in a terminal"
}

_restoreTerminal() {
    if (( terminalSupportsAnsi )); then
        stty sane
        printf '\e[?25h'  # Show cursor in case sane does not
    fi
}

_onTerm() {
    _restoreTerminal
    ansi italic_red "🔺 killed\n"
    exit 1
}

_onHup() {
    _restoreTerminal
    ansi italic_red "🔺 killed (SIGHUP)\n"
    exit 1
}

_onInt() {
    _restoreTerminal
    ansi italic_red "🔺 exiting (ctrl-c)\n"
    exit 1
}

_onExit() {
    _restoreTerminal

    # Add a line unless disabled

    [[ -n ${noEchoOnExit} ]] && echo

    # Delete temp dir if we created it

    if [[ ${_rayvnTempDir} ]]; then
        rm -rf -- "${_rayvnTempDir}" &> /dev/null
    fi

    # Run any added tasks

    for task in "${_rayvnExitTasks[@]}"; do
        eval "${task}"
    done
}

addExitHandler() {
    _rayvnExitTasks+=("${1}")
}

dirName() {
    local path=${1%/}
    echo "${path%/*}"
}

baseName() {
    local path=${1%/}
    echo "${path##*/}"
}

trim() {
    local value="${1}"
    value="${value#"${value%%[![:space:]]*}"}"  # remove leading whitespace
    value="${value%"${value##*[![:space:]]}"}"  # remove trailing whitespace
    echo "${value}"
}

projectVersion() {
    local projectName="${1}"
    local verbose="${2:-}"
    local pkgFile="${_rayvnProjects[${projectName}${_projectRootSuffix}]}/rayvn.pkg"
    assertFileExists "${pkgFile}"
    (
        require 'rayvn/safe-source'
        sourceSafeStaticVars "${pkgFile}" project
        if [[ ${projectReleaseDate} ]]; then
            [[ ${verbose} ]] && description=" (released ${projectReleaseDate})"
        else
            [[ ${verbose} ]] && description=" (pre-release)"
        fi
        echo "${projectName} ${projectVersion}${description}"
    )
}

assertFileExists() {
    [[ -e ${1} ]] || assertionFailed "${1} not found"
}

assertFile() {
    local file="${1}"
    local description="${2:-file}"
    assertFileExists "${file}"
    [[ -f ${1} ]] || assertionFailed "${1} is not an ${description}"
}

assertDirectory() {
    assertFileExists "${1}"
    [[ -d ${1} ]] || assertionFailed "${1} is not a directory"
}

assertFileDoesNotExist() {
    [[ -e "${1}" ]] && assertionFailed "${1} already exists"
}

assertValidFileName() {
    local name="${1}"

    # Reject empty, ".", or ".."
    [[ -z ${name} || ${name} == "." || ${name} == ".." ]] && \
        fail "Invalid filename: '${name}' is reserved or empty"

    # Reject slash
    [[ ${name} == *"/"* ]] && \
        fail "Invalid filename: '${name}' contains forbidden character '/'"

    # Reject control characters
    [[ ${name} =~ [[:cntrl:]] ]] && \
        fail "Invalid filename: '${name}' contains control characters"

    # Reject reserved characters (Windows-unsafe or problematic cross-platform)
    [[ ${name} =~ [\<\>\:\"\\\|\?\*] ]] && \
        fail "Invalid filename: '${name}' contains reserved characters like <>:\"\\|?*"
}

appendVar() {
    export ${1}="${!1:+${!1} }${2}"
}

setFileVar() {
    _setFileSystemVar "${1}" "${2}" "${3}" false
}

setDirVar() {
    _setFileSystemVar "${1}" "${2}" "${3}" true
}

_setFileSystemVar() {
    local -n resultVar="${1}"
    local file="${2}"
    local description="${3}"
    local isDir="${4}"

    [[ ${file} ]] || assertionFailed "${description} path is required"
    [[ -e ${file} ]] || assertionFailed "${file} not found"
    if [[ ${isDir} == true ]]; then
        [[ -d ${file} ]] || assertionFailed "${file} is not a directory"
    else
        [[ -f ${file} ]] || assretFailed "${file} is not a file"
    fi
    local realFile="$(realpath "${file}" 2> /dev/null)"
    resultVar="${realFile}"
}

timeStamp() {
    date "+%Y-%m-%d_%H.%M.%S_%Z"
}

epochSeconds() {
    date +%s
}

secureEraseVars() {
    local varName value length
    while (( ${#} > 0 )); do
        varName="${1}"
        if [[ -n ${!varName+x} ]]; then
            value="${!varName}"
            length="${#value}"
            printf -v "${varName}" '%*s' "${length}" ''
            unset "${varName}"
        fi
        shift
    done
}

ansi() {
    local color="ansi_${1}"
    shift
    (( terminalSupportsAnsi )) && echo -ne "${!color}${*}${ansi_normal}" || echo -ne "${*}"
}


printRepeat() {
    local msg="${1}"
    local count=${2}
    for ((i = 0; i < ${count}; ++i)); do
        echo -n "${msg}"
    done
}

printVars() {
    (
        while (( ${#} > 0 )); do
            local var=${1}
            if declare -p ${var} &> /dev/null; then
                declare -p ${var}
            else
                echo "${var} is not set"
            fi
            shift
        done
    )
}

printFormatted() {
    printf "${1}\n" "${@:2}"
}

print() {
    echo -e "${*}"
}

printRed() {
    ansi red "${*}\n"
}

warn() {
    ansi yellow "⚠️ ${*}\n" >&2
}

error() {
    ansi red "🔺 ${*}\n" >&2
}

redStream() {
    local error
    while read error; do
        printRed "${error}"
    done
}

printStack() {
    local caller=${FUNCNAME[1]}
    declare -i start=1
    declare -i depth=${#FUNCNAME[@]}

    if (( depth > 2 )); then
        [[ ${caller} == "assertionFailed" || ${caller} == "fail" || ${caller} == "bye" ]] && start=2
    fi

    [[ ${1} ]] && { error "${*}"; echo; }

    for ((i = start; i < depth; i++)); do
        local function="${FUNCNAME[${i}]}"
        local line="$(ansi bold_blue ${BASH_LINENO[${i} - 1]})"
        local arrow="$(ansi cyan -\>)"
        local called=${FUNCNAME[${i} - 1]}
        local script="$(ansi dim "${BASH_SOURCE[${i}]}")"
        (( i == start )) && function="$(ansi red "${function}"\(\))" || function="$(ansi blue "${function}"\(\))"
        echo "   ${function} ${script}:${line} ${arrow} ${called}()"
    done
}

assertionFailed() {
    printStack "${*}"
    exit 1
}

fail() {
    printStack "${*}"
    exit 1
}

bye() {
    [[ ${1} ]] && printRed "${*}"
    debugStack
    exit 0
}

# Debug control functions

isDebug() {
    (( _debug ))
}

setDebug() {
    echo "SETTING DEBUG!" # TODO REMOVE!
    require 'rayvn/debug'
    _setDebug "${@}"
}

# Placeholder debug functions, replaced in setDebug()

debug() { :; }
debugEnabled() { return 1; }
debugDir() { :; }
debugStatus() { echo 'debug disabled'; }
debugBinary() { :; }
debugVars() { :; }
debugVarIsSet() { :; }
debugVarIsNotSet() { :; }
debugFile() { :; }
debugJson() { :; }
debugStack() { :; }
debugEnvironment() { :; }
