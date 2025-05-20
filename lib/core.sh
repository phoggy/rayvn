#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library supporting common functionality
# Intended for use via: require 'rayvn/core'

if [[ ! ${CORE_GLOBALS_DECLARED} ]]; then

    trap '_onExit' EXIT
    declare -grx newline=$'\n'
    declare -grx osName="$(uname)"
    declare -grx macOS=$( [[ ${osName} == Darwin ]] && echo true )
    declare -grx linux=$( [[ ${osName} == Linux ]] && echo true )
    declare -grx rayvnRootDir="$(realpath "${BASH_SOURCE%/*}/..")"

    # Are stdout and stderr both terminals?

    if [[ -t 1 && -t 2 ]]; then

        # Yes, so remember and export the TTY so we can redirect from within
        # child processes

        declare -grx terminal=$(tty)

        # Set constant ANSI codes for some cursor and erase operations

        declare -grx _eraseToEndOfLine=$(printf $'\x1b[0K')
        declare -grx _eraseCurrentLine=$(printf '\x1b[2K\r')
        declare -grx _cursorUpOneAndEraseLine=$(printf $'\x1b[1F\x1b[0K')
        declare -grx _cursorLeftOne=$(printf '\x1b[1D')

        # Set ansi colors if terminal supports colors

        if (($(tput colors) >= 8)); then
            declare -grx ansi_normal="$(tput sgr0)"

            declare -grx ansi_bold="$(tput bold)"
            declare -grx ansi_underline="$(tput smul)"
            declare -grx ansi_italic="$(printf '\e[3m')"
            declare -grx ansi_black="$(tput setaf 0)"
            declare -grx ansi_dim="$(printf '\e[2m')"

            declare -grx ansi_red="$(tput setaf 1)"
            declare -grx ansi_green="$(tput setaf 2)"
            declare -grx ansi_yellow="$(tput setaf 3)"
            declare -grx ansi_blue="$(tput setaf 4)"
            declare -grx ansi_magenta="$(tput setaf 5)"
            declare -grx ansi_cyan="$(tput setaf 6)"
            declare -grx ansi_white="$(tput setaf 7)"

            declare -grx ansi_italic_cyan="${ansi_italic}${ansi_cyan}"

            declare -grx ansi_bold_red="${ansi_bold}${ansi_red}"
            declare -grx ansi_bold_green="${ansi_bold}${ansi_green}"
            declare -grx ansi_bold_yellow="${ansi_bold}${ansi_yellow}"
            declare -grx ansi_bold_blue="${ansi_bold}${ansi_blue}"
            declare -grx ansi_bold_magenta="${ansi_bold}${ansi_magenta}"
            declare -grx ansi_bold_cyan="${ansi_bold}${ansi_cyan}"
            declare -grx ansi_bold_white="${ansi_bold}${ansi_white}"
            declare -grx ansi_bold_italic="${ansi_bold}${ansi_italic}"
        fi

        # Set misc constants

        declare -grx _checkMark="✔"
        declare -grx _greenCheckMark="${ansi_bold_green}${_checkMark}${ansi_normal}"

        # Ensure debug flag is set and off by default

        declare -gxi _debug=0

    elif [[ ${RAYVN_NO_TERMINAL} == true ]]; then

        # No terminal, so ensure we define terminal as empty.
        # Any code that truly requires the terminal should call assertTerminal

        declare -grx terminal=

    else
        echo "🔺 Must be run in a terminal."
        echo
        echo "   This requirement can be bypassed by exporting RAYVN_NO_TERMINAL=true"
        echo "   but be aware that some functionality may not work correctly."
        echo
        exit 1
    fi

    # Is this a mac?

    if [[ ${osName,,} == "darwin" ]]; then

        # Yes, remember if brew is available

        if command -v brew > /dev/null ; then
            declare -grx brewInstalled=true
        fi
    elif [[ ! ${RAYVN_NO_OS_CHECK} ]]; then

        # No, so warn that not tested here!

        echo "⚠️ This code has only been tested on MacOS. Please report any issues at https://github.com/phoggy/rayvn/issues"
        echo
        echo "   This warning can be bypassed by exporting RAYVN_NO_OS_CHECK=true"
        echo "   but be aware that some functionality may not work correctly."
        echo
    fi

    declare -grx CORE_GLOBALS_DECLARED=true
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
    local fileName="${1:-}"
    if [[ -z ${_rayvnTempDir:-} ]]; then
        declare -grx _rayvnTempDir="$(mktemp -d)" || fail "could not create temp directory"
        chmod 700 "${_rayvnTempDir}" || fail "chmod failed for rayvn temp directory"
    fi
    [[ ${fileName} ]] && echo "${_rayvnTempDir}/${fileName}" || echo "${_rayvnTempDir}"
}

makeDir() {
    local dir="${1}"
    [[ ${2} ]] && dir="${1}/${2}"
    mkdir -p "${dir}" || fail "could not create directory ${dir}"
    echo "${dir}"
}

assertTerminal() {
    [[ ${terminal} ]] || assertionFailed "must be run in a terminal"
}

_resetTerminal() {
    if [[ ${terminal} ]]; then
        tput cnorm
        stty echo 2> /dev/null
        stty -f ${terminal} echo 2> /dev/null
    fi
}

_onExit() {
    [[ ${terminal} ]] && echo
    _resetTerminal
    if [[ ${_rayvnTempDir} ]]; then
        # The "--" option below stops option parsing and allows filenames starting with "-"
        rm -rf -- "${_rayvnTempDir}"
    fi
}

addExitHandler() {
    local newCommand
    getTrapCommand() { printf '%s\n' "${3}"; }
    newCommand="$(
        eval "getTrapCommand $(trap -p EXIT)"
        printf '%s\n' "${1}"
        )"
    trap -- "${newCommand}" EXIT
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
    (
        require 'rayvn/safe-env'
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
    declare -p name
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

saveCursor() {
    assertTerminal
    tput sc
}

restoreCursor() {
    assertTerminal
    tput rc
}

eraseToEndOfLine() {
    assertTerminal
    echo -n "${_eraseToEndOfLine}"
}

eraseCurrentLine() {
    assertTerminal
    echo -n "${_eraseCurrentLine}"
}

cursorUpOneAndEraseLine() {
    assertTerminal
    echo -n "${_cursorUpOneAndEraseLine}"
}

cursorPosition() {
    assertTerminal
    local position
    read -sdR -p $'\E[6n' position
    position=${position#*[} # Strip decoration characters <ESC>[
    echo "${position}"    # Return position in "row;col" format
}

cursorRow() {
    assertTerminal
    local row column
    IFS=';' read -sdR -p $'\E[6n' row column
    echo "${row#*[}"
}

cursorColumn() {
    assertTerminal
    local row column
    IFS=';' read -sdR -p $'\E[6n' row column
    echo "${column}"
}

moveCursor() {
    assertTerminal
    tput cup "${1}" "${2}"
}

ansi() {
    local color="ansi_${1}"
    shift
    [[ ${terminal} ]] && echo -n "${!color}${*}${ansi_normal}" || echo -n "${*}"
}

printRed() {
    print "$(ansi red "${*}")" > ${terminal}
}

printRepeat() {
    local msg="${1}"
    local count=${2}
    for ((i = 0; i < ${count}; ++i)); do
        echo -n "${msg}" > ${terminal}
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
    ) > ${terminal}
}

printFormatted() {
    printf "${1}\n" "${@:2}" > ${terminal}
}

print() {
    echo -e "${*}" > ${terminal}
}

warn() {
    print "⚠️ $(ansi yellow "${*}")" >&2
}

error() {
    print "🔺 $(ansi red "${*}")" >&2
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
    isDebug && printStack
    exit 0
}

# Debug control functions

isDebug() {
    (( _debug ))
}

setDebug() {
    require 'rayvn/debug'
    _setDebug "${@}"
}

# Placeholder debug functions, replaced in setDebug()

debug() { :; }
debugDir() { :; }
debugEnvironment() { :; }
debugFile() { :; }
debugJson() { :; }
debugStatus() { :; }
debugVarIsNotSet() { :; }
debugVarIsSet() { :; }
debugVars() { :; }
