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
    declare -grx pinEntryProgram="${rayvnRootDir}/bin/rayvn-pinentry"
    declare -grx rayvnPackageFileName="rayvn.pkg"

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

rootDirPath() {
    echo "${rayvnRootDir}/${1}"
}

packageFile() {
    local project="${1}"
    echo "${rayvnConfigPkgDir}/${project}.pkg"
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

version() {
    local projectDir="${1}"
    local verbose="${2:-}"
    local projectName="$(basename ${projectDir})"
    local pkgFile="${projectDir}/rayvn.pkg"
    (
        sourceEnvFile "${pkgFile}"
        if [[ ${projectReleaseDate} ]]; then
            [[ ${verbose} ]] && description=" (released ${projectReleaseDate})"
        else
            [[ ${verbose} ]] && description=" (pre-release)"
        fi
        echo "${projectName} v${projectVersion}${description}"
    )
}

assertMinimumVersion() {
    local minimum="${1}"
    local version="${2}"
    local targetName="${3}"
    local errorSuffix="${4}"
    local lowest=$(printf '%s\n%s\n' "$version" "$minimum" | sort -V | head -n 1)
    [[ "${lowest}" != "${minimum}" ]] && assertionFailed "requires ${targetName} version >= ${minimum}, found ${lowest} ${errorSuffix}"
    return 0
}

assertBashVersion() {
    local minVersion="${1:-5}"
    assertMinimumVersion "${minVersion}" "${BASH_VERSINFO:-0}" "bash" "at ${BASH} (update PATH to fix)"
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

sourceEnvFile() {
    local envFile="${1}"
    assertFileExists "${envFile}"
    # strip anything that isn't env var declarations and source that
    local strippedEnvFile=$(_stripEnvFile "${envFile}")
    source <(echo ${strippedEnvFile})
}

_stripEnvFile() {
    local envFile="${1}"
    cat "${envFile}" | grep '^[_[:alpha:]][_[:alpha:][:digit:]]*[=].*$'


# TODO: debug this!
#    local inMultiline=0
#    local multilineVar=''
#
#    # Process the script line by line
#    while IFS= read -r line; do
#        # Remove leading and trailing whitespace
#        line=$(echo "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
#
#        # Skip lines that are empty or comments
#        if [[ -z "${line}" || "${line}" =~ ^# ]]; then
#            continue
#        fi
#
#        # Check if it's a multi-line variable assignment (e.g., arrays or multiline values)
#        if [[ "${line}" =~ [^#]*=\(.*\) ]]; then
#            inMultiline=1
#            multilineVar="${line}"
#            continue
#        fi
#
#        # If we're already in a multi-line variable, continue appending
#        if [[ ${inMultiline} -eq 1 ]]; then
#            multilineVar="${multilineVar}${line}"
#            # Check if the multi-line ends
#            if [[ "${line}" =~ \)$ ]]; then
#                echo "${multilineVar}"
#                inMultiline=0
#                multilineVar=""
#            fi
#            continue
#        fi
#
#        # Otherwise, it's a single-line variable declaration (camelCase)
#        if [[ "${line}" =~ ^[A-Za-z][A-Za-z0-9]*=[^#]*$ ]]; then
#            echo "${line}"
#        fi
#    done < "${envFile}"
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
    local file="$(realpath "${2}")"
    local description="${3}"
    local isDir="${4}"
    [[ ${file} ]] || assertionFailed "${description} path is required"
    [[ -e ${file} ]] || assertionFailed "${file} not found"
    if [[ ${isDir} == true ]]; then
        [[ -d ${file} ]] || assertionFailed "${file} is not a directory"
    else
        [[ -f ${file} ]] || assretFailed "${file} is not a file"
    fi
    resultVar="${file}"
}

useRayvnPinEntry() {
    declare -gx PINENTRY_PROGRAM="${pinEntryProgram}"
}

disableRayvnPinEntry() {
    unset PINENTRY_PROGRAM
}

timeStamp() {
    date "+%Y-%m-%d_%H.%M.%S_%Z"
}

epochSeconds() {
    date +%s
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

printVar() {
    while ((${#} > 0)); do
        echo "${1}: '${!1}'" > ${terminal}
        shift
    done
}

printFormatted() {
    printf "${1}\n" "${@:2}" > ${terminal}
}

print() {
    echo -e "${*}" > ${terminal}
}

warn() {
    print "⚠️ $(ansi yellow "${*}")"
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

printStack() {
    local start=1
    local caller=${FUNCNAME[1]}
    local start=1
    [[ ${caller} == "assertionFailed" ]] && start=2

    for ((i = ${start}; i < ${#FUNCNAME[@]} - 1; i++)); do
        local function="${FUNCNAME[${i}]}"
        local line=${BASH_LINENO[${i} - 1]}
        local called=${FUNCNAME[${i} - 1]}
        local script=${BASH_SOURCE[${i}]}
        echo "   ${function}() line ${line} [in ${script}] --> ${called}()"
    done
}

logEnvironment() {
    local envName="${1}"
    local file="${2}"
    (
        printf "%s\n\n" "#!/usr/bin/env bash"
        printf "# %s\n\n" "Environment: ${envName}. @ $(timeStamp)"
        printf "# %s\n\n" '--- VARIABLES --------------'
        declare -p
        printf "\n\n# %s\n\n" '--- FUNCTIONS ---------------'
        declare -f
    ) > "${file}"
}

assertionFailed() {
    if [[ ${1} ]]; then
        _resetTerminal
        error "${*}"
        echo
        printStack
    fi
    exit 1
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

init_rayvn_core() {
    assertBashVersion 5
}

declare -grx _tempDirectory="$(mktemp -d)" || fail "could not create temp directory"
