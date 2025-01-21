#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library supporting common functionality
# Intended for use via: require 'core/base'

if [[ ! ${BASE_GLOBALS_DECLARED} ]]; then

    trap '_onExit' EXIT
    declare -grx libDir="$(realpath "${BASH_SOURCE%/*}")"
    declare -grx rootDir="$(realpath "${libDir}/..")"
    declare -grx newline=$'\n'
    declare -grx osName="$(uname)"

    # Is stdout a terminal?

    if [[ -t 1 ]]; then

        # Yes, so remember and export it so we can redirect from within
        # child processes

        declare -grx terminal=$(tty)

        # Set constant ANSI codes for some cursor and erase operations

        declare -grx _saveCursor=$(printf $'\x1b[s')
        declare -grx _restoreCursor=$(printf $'\x1b[u')
        declare -grx _eraseToEndOfLine=$(printf $'\x1b[0K')
        declare -grx _eraseCurrentLine=$(printf '\x1b[2K\r')
        declare -grx _cursorUpOneAndEraseLine=$(printf $'\x1b[1F\x1b[0K')
        declare -grx _cursorLeftOne=$(printf '\x1b[1D')

        # Set ansi colors if terminal supports colors

        if (($(tput colors) >= 8)); then
            declare -grx ansi_bold="$(tput bold)"
            declare -grx ansi_underline="$(tput smul)"
            declare -grx ansi_italic="$(printf '\e[3m')"
            declare -grx ansi_normal="$(tput sgr0)"
            declare -grx ansi_black="$(tput setaf 0)"

            declare -grx ansi_red="$(tput setaf 1)"
            declare -grx ansi_green="$(tput setaf 2)"
            declare -grx ansi_yellow="$(tput setaf 3)"
            declare -grx ansi_blue="$(tput setaf 4)"
            declare -grx ansi_magenta="$(tput setaf 5)"
            declare -grx ansi_cyan="$(tput setaf 6)"
            declare -grx ansi_white="$(tput setaf 7)"

            declare -grx ansi_bold_red="${ansi_bold}${ansi_red}"
            declare -grx ansi_bold_green="${ansi_bold}${ansi_green}"
            declare -grx ansi_bold_yellow="${ansi_bold}${ansi_yellow}"
            declare -grx ansi_bold_blue="${ansi_bold}${ansi_blue}"
            declare -grx ansi_bold_magenta="${ansi_bold}${ansi_magenta}"
            declare -grx ansi_bold_cyan="${ansi_bold}${ansi_cyan}"
            declare -grx ansi_bold_white="${ansi_bold}${ansi_white}"
            declare -grx ansi_bold_italic="${ansi_bold}${ansi_italic}"
        fi
    else
        echo "🔺 must be run in a terminal"
        exit 1
    fi

    # Is this a mac?

    if [[ ${osName,,} == "darwin" ]]; then

        # Yes, remember if brew is available

        if which brew > /dev/null ; then
            declare -grx brewInstalled=true
        fi
    fi

    declare -grx BASE_GLOBALS_DECLARED=true
fi

rootDirPath() {
    echo "${rootDir}/${1}"
}

tempDirPath() {
    [[ ${1} ]] && echo "${_tempDirectory}/${1}" || echo "${_tempDirectory}"
}

makeDir() {
    local dir="${1}"
    [[ ${2} ]] && dir="${1}/${2}"
    mkdir -p "${dir}" || fail "could not create directory ${dir}"
    echo "${dir}"
}

_resetTerminal() {
    tput cnorm
    stty echo 2> /dev/null
    stty -f ${terminal} echo 2> /dev/null
}

_onExit() {
    echo > ${terminal}
    _resetTerminal
    if [[ ${_tempDirectory} ]]; then
        # The "--" option below stops option parsing and allows filenames starting with "-"
        rm -rf -- "${_tempDirectory}"
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

assertMinimumVersion() {
    local minimum="${1}"
    local version="${2}"
    local targetName="${3}"
    local errorSuffix="${4}"
    local lowest=$(printf '%s\n%s\n' "$version" "$minimum" | sort -V | head -n 1)
    [[ "${lowest}" != "${minimum}" ]] && fail "requires ${targetName} version >= ${minimum}, found ${lowest} ${errorSuffix}"
}

assertBashVersion() {
    local minVersion="${1:-5}"
    assertMinimumVersion "${minVersion}" "${BASH_VERSINFO:-0}" "bash" "at ${BASH} (update PATH to fix)"
}

assertFileExists() {
    [[ -e ${1} ]] || fail "${1} not found"
}

assertFile() {
    local description="${2:file}"
    [[ ${1} ]] || fail "an ${description} is required"
    assertFileExists "${1}"
    [[ -f ${1} ]] || fail "${1} is not an ${description}"
}

assertDirectory() {
    assertFileExists "${1}"
    [[ -d ${1} ]] || fail "${1} is not a directory"
}

assertFileDoesNotExist() {
    [[ -e "${1}" ]] && fail "${1} already exists"
}

assertExecutables() {
    local dependenciesVarName="${1}"
    declare -n deps="${dependenciesVarName}"
    for name in "${!deps[@]}"; do
        if [[ ${name} =~ _version$ ]]; then
            _assertExecutable "${name%_version}" "${dependenciesVarName}"
        fi
    done
}

versionExtract() {
    ${1} --version 2>&1 | head -n 1 | cut -d' ' -f2
}

versionExtractA() {
    ${1} --version 2>&1 | head -n 1 | cut -d' ' -f3
}

versionExtractB() {
    ${1} -version 2>&1 | tail -n 1 | cut -d' ' -f3
}

versionExtractDash() {
    ${1} --version 2>&1 | tail -n 1 | cut -d'-' -f2
}

_assertExecutable() {
    local executable="${1}"
    local dependenciesVarName="${2}"
    declare -n deps="${dependenciesVarName}"
    local defaultMin="${deps[${executable}_min]}"
    local minVersion="${3:-${defaultMin}}"
    if [[ ${defaultMin} != '' ]]; then
        _assertExecutableFound "${executable}" ${dependenciesVarName}
        local versionExtract="${deps[${executable}_version]}"
        if [[ ${minVersion} != 0 ]]; then
            local version=$(${versionExtract} ${executable})
            local errMsg=":"
            if [[ ${brewInstalled} && ${deps[${executable}_brew]} == true ]]; then
                errMsg+=" try 'brew update ${executable}' or see"
            else
                errMsg+=" see"
            fi
            errMsg+=" ${deps[${executable}_install]}"

            assertMinimumVersion ${minVersion} ${version} "${executable}" "${errMsg}"
        fi
    else
        fail "unregistered dependency: ${executable}"
    fi
}

_assertExecutableFound() {
    local executable="${1}"
    local dependenciesVarName="${2}"
    declare -n deps="${dependenciesVarName}"
    if ! which ${executable} >/dev/null; then
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
        fail "${errMsg}"
    fi
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
    [[ ${file} ]] || fail "${description} path is required"
    [[ -e ${file} ]] || fail "${file} not found"
    if [[ ${isDir} == true ]]; then
        [[ -d ${file} ]] || fail "${file} is not a directory"
    else
        [[ -f ${file} ]] || fail "${file} is not a file"
    fi
    resultVar="${file}"
}

timeStamp() {
    date "+%Y-%m-%d_%Z_%H.%M.%S"
}

saveCursor() {
    echo -n "${_saveCursor}"
}

restoreCursor() {
    echo -n "${_restoreCursor}"
}

eraseToEndOfLine() {
    echo -n "${_eraseToEndOfLine}"
}

eraseCurrentLine() {
    echo -n "${_eraseCurrentLine}"
}

cursorUpOneAndEraseLine() {
    echo -n "${_cursorUpOneAndEraseLine}"
}

cursorPosition() {
    local position
    read -sdR -p $'\E[6n' position
    position=${position#*[} # Strip decoration characters <ESC>[
    echo "${position}"    # Return position in "row;col" format
}

cursorRow() {
    local row column
    IFS=';' read -sdR -p $'\E[6n' row column
    echo "${row#*[}"
}

cursorColumn() {
    local row column
    IFS=';' read -sdR -p $'\E[6n' row column
    echo "${column}"
}

moveCursor() {
    tput cup "${1}" "${2}"
}

ansi() {
    local color="ansi_${1}"
    shift
    echo -n "${!color}${*}${ansi_normal}"
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

printVar() {
    echo "${1}: '${!1}'" > ${terminal}
}

printFormatted() {
    printf "${1}\n" "${@:2}" > ${terminal}
}

print() {
    echo "${*}" > ${terminal}
}

warn() {
    print "⚠️  $(ansi yellow "${*}")"
}

error() {
    print "🔺 $(ansi red "${*}")"
}

redStream() {
    local error
    while read error; do
        printRed "${error}"
    done
}

fail() {
    if [[ ${1} ]]; then
        _resetTerminal
        error "${*}"
    fi
    exit 1
}

bye() {
    if [[ ${1} ]]; then
        printRed "${@}"
        exit 1
    fi
    exit 0
}

init_core_base() {
    assertBashVersion 5
}

declare -grx _tempDirectory="$(mktemp -d)" || fail "could not create temp directory"
