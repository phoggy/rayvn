#!/usr/bin/env bash
# shellcheck disable=SC2155

# Core library.
# Intended for use via: require 'rayvn/core'

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
        makeDir "${dir}" >/dev/null
    fi
}

makeDir() {
    local dir="${1}"
    local subDir="${2:-}"
    [[ -z ${subDir} ]] || dir="${dir}/${subDir}"
    mkdir -p "${dir}" || fail "could not create directory ${dir}"
    echo "${dir}"
}

assertAnsiSupported() {
    ((terminalSupportsAnsi)) || assertionFailed "must be run in a terminal"
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
    value="${value#"${value%%[![:space:]]*}"}" # remove leading whitespace
    value="${value%"${value##*[![:space:]]}"}" # remove trailing whitespace
    echo "${value}"
}

projectVersion() {
    local projectName="${1}"
    local verbose="${2:-}"
    local pkgFile="${_rayvnProjects[${projectName}${_projectRootSuffix}]}/rayvn.pkg"
    assertFileExists "${pkgFile}"
    (
        require 'rayvn/config'
        sourceConfigFile "${pkgFile}" project
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

assertPathWithinDirectory() {
    local filePath=${1}
    local dirPath=${2}
    local absoluteFile absoluteDir
    absoluteFile=${ realpath "${filePath}" 2>/dev/null;} || fail
    absoluteDir=${ realpath "${dirPath}" 2>/dev/null;} || fail
    [[ "${absoluteFile}" == ${absoluteDir}/* ]] || assertionFailed "${filePath} is not within ${dirPath}"
}

assertValidFileName() {
    local name="${1}"

    # Reject empty, ".", or ".."
    [[ -z ${name} || ${name} == "." || ${name} == ".." ]] &&
        fail "Invalid filename: '${name}' is reserved or empty"

    # Reject slash
    [[ ${name} == *"/"* ]] &&
        fail "Invalid filename: '${name}' contains forbidden character '/'"

    # Reject control characters
    [[ ${name} =~ [[:cntrl:]] ]] &&
        fail "Invalid filename: '${name}' contains control characters"

    # Reject reserved characters (Windows-unsafe or problematic cross-platform)
    [[ ${name} =~ [\<\>\:\"\\\|\?\*] ]] &&
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
    local realFile="$(realpath "${file}" 2>/dev/null)"
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
    while ((${#} > 0)); do
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

# New invocation model:         echo "${ ansi bold Some bold text!; }"
# TODO explore costs of a more flexible model, e.g. nesting (from my Helidon code)?
ansi() {
    local color="ansi_${1}"
    shift
    ((terminalSupportsAnsi)) && echo -ne "${!color}${*}${ansi_normal}" || echo -ne "${*}"
}

# TODO load from ~/rayvn/theme.sh

_theme_name='Ocean'
_theme_colors=($'\e[38;2;52;208;88m' $'\e[38;2;215;58;73m' $'\e[38;2;251;188;5m' $'\e[38;2;13;122;219m' $'\e[38;2;138;43;226m' $'\e[38;2;139;148;158m')

# MacOS Terminal Compatibility
#
#  Terminal TERM=xterm-color256 COLORTERM=(not set) -> RGB & strikethrough not supported
#  iTerm2   TERM=xterm-color256 COLORTERM=truecolor -> all supported
#  Warp     TERM=xterm-color256 COLORTERM=truecolor -> all supported
#  IntelliJ TERM=xterm-color256 COLORTERM=(not set) -> RGB IS supported, no strikethrough


declare -grAx formats=(

    # Turn off previous formats

    ['plain']=$'\e[0m'

    # Theme

    ['success']=${_theme_colors[0]}
    ['error']=${_theme_colors[1]}
    ['warning']=${_theme_colors[2]}
    ['info']=${_theme_colors[3]}
    ['accent']=${_theme_colors[4]}
    ['muted']=${_theme_colors[5]}

    # Effects on

    ['bold']=$'\e[1m'
    ['dim']=$'\e[2m'
    ['italic']=$'\e[3m'
    ['underline']=$'\e[4m'
    ['blink']=$'\e[5m'
    ['reverse']=$'\e[7m'
   # often not supported ['strikethrough']=$'\e[9m'

    # Effects off

    ['!bold']=$'\e[22m'
    ['!dim']=$'\e[22m'
    ['!italic']=$'\e[23m'
    ['!underline']=$'\e[24m'
    ['!blink']=$'\e[25m'
    ['!reverse']=$'\e[27m'
    # often not supported ['!strikethrough']=$'\e[29m'

    # Basic Colors

    ['black']=$'\e[30m'
    ['red']=$'\e[31m'
    ['green']=$'\e[32m'
    ['yellow']=$'\e[33m'
    ['blue']=$'\e[34m'
    ['magenta']=$'\e[35m'
    ['cyan']=$'\e[36m'
    ['white']=$'\e[37m'
    ['bright-black']=$'\e[90m'
    ['bright-red']=$'\e[91m'
    ['bright-green']=$'\e[92m'
    ['bright-yellow']=$'\e[93m'
    ['bright-blue']=$'\e[94m'
    ['bright-magenta']=$'\e[95m'
    ['bright-cyan']=$'\e[96m'
    ['bright-white']=$'\e[97m'
)

# Enhanced echo function supporting text color and styles along in addition to standard echo
# options (-n, -e, -E). Formats can appear at any argument position and affect the subsequent
# arguments until another format occurs. Styles accumulate and persist (e.g., bold remains
# bold across subsequent arguments), while colors replace previous colors. Use 'plain' to
# reset all formatting. IMPORTANT: When transitioning from colored text to style-only text,
# use 'plain' first to reset the color, then apply the style. See examples below.
#
# Automatically resets formatting to plain after text to prevent color bleed.
#
# USAGE:
#   show [-neE] [[FORMAT [FORMAT]...] [TEXT]...]
#
# Options:
#
#   -n do not append a newline
#   -e enable interpretation of backslash escapes (see help echo for list)
#   -E explicitly suppress interpretation of backslash escapes
#
# EXAMPLES:
#   show blue "This is blue text"
#   show bold red "Bold red text"
#   show -n yellow "Yellow text with no newline"
#   show success "Operation completed"
#   show italic underline green "Italic underline green text"
#   show "Plain text" italic bold blue "italic bold blue text" red "italic bold red" plain blue "blue text" # style continuation
#   show italic 62 "italic 256 color #62 text" plain red "plain red text" # style continuation
#   show RGB 52:208:88 "rgb 52 208 88 colored text"
#
#   # IMPORTANT: Use 'plain' to reset colors BEFORE applying styles-only
#   show cyan "colored text" plain dim "dim text (no color)"
#
#   # Reset after combining color+style before continuing
#   show bold green "Note" plain "Regular text continues here"
#
#   # Transitioning between different color+style combinations
#   show bold blue "heading" plain "text" italic "emphasis"
#
#   # In command substitution (bash 5.3+)
#   prompt "${ show bold green "Proceed?" ;}" yes no reply
#
# COMMON PATTERNS:
#
#   Applying color only:
#     show blue "text"
#
#   Applying style only:
#     show bold "text"
#
#   Combining color and style:
#     show bold blue "text"
#
#   Resetting after color/style combination:
#     show bold green "styled" plain "back to normal"
#
#   Transitioning from color to style-only (IMPORTANT):
#     show cyan "colored" plain dim "dimmed, not colored"
#     # NOT: show cyan "colored" dim "dimmed" - dim inherits cyan!
#
#   Style continuation (styles persist):
#     show italic "starts italic" blue "still italic, now blue"
#
#   Color replacement (colors don't persist):
#     show blue "blue" red "red (replaces blue)"
#
#   In command substitution:
#     message="${ show bold "text" ;}"
#     stopSpinner ": ${ show green "success" ;}"
#
# AVAILABLE FORMATS:
#
#   Theme Colors (semantic):
#     success, error, warning, info, accent, muted
#
#   Text Styles:
#     bold, dim, italic, underline, blink, reverse, strikethrough
#
#   Basic Colors:
#     black, red, green, yellow, blue, magenta, cyan, white
#     bright-black, bright-red, bright-green, bright-yellow,
#     bright-blue, bright-magenta, bright-cyan, bright-white
#
#   256 Colors:
#     0-255
#
#   RGB Colors ('truecolor':
#     RGB 0-255 0-255 0-255
#
#   Reset:
#     plain
#
show() {
    if (( ! $# )); then
        echo
        return
    fi

    local options=''
    if [[ ${1} == -* ]]; then
        options=${1}; shift
        while (( $# )) && [[ ${1} == -* ]]; do
            options="${options} ${1}"; shift
        done
    fi

    local output='' currentFormat='' addSpace=0
    while (( $# )); do
        if [[ -n ${1} ]]; then
            if [[ -v formats[${1}] ]]; then
                currentFormat+=${formats[${1}]}
            elif [[ -z "${1//[0-9]/}" ]] && (( ${1} <= 255 )); then
                currentFormat+=$'\033[38;5;'"${1}m"    # 256 color
            elif [[ ${1} == RGB ]] && (( $# >=2 )); then
                shift
                currentFormat+=$'\e[38;2;'"${1//:/;}m" # truecolor
            else
                if ((addSpace)); then
                    output+=' '
                fi
                output+=${currentFormat}${1}
                currentFormat=''
                addSpace=1
            fi
        fi
        shift
    done
    echo ${options} "${output}"$'\e[0m'
}

printRepeat() {
    local str=${1}
    local count=${2}
    local result
    printf -v result "%*s" "${count}" ""
    result=${result// /${str}}
    echo "${result}"
}

printVars() {
    (
        while ((${#} > 0)); do
            local var=${1}
            if declare -p ${var} &>/dev/null; then
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

warn() {
    show yellow "⚠️ ${*}" >&2
}

error() {
    show red "🔺 ${*}" >&2
}

redStream() {
    local error
    while read error; do
        show red "${error}"
    done
}

printStack() {
    local message="${1}"
    local caller=${FUNCNAME[1]}
    declare -i start=1
    declare -i depth=${#FUNCNAME[@]}

    [[ -n ${message} ]] && error "${*}"

    if ((depth > 2)); then
        [[ ${caller} == "assertionFailed" || ${caller} == "fail" || ${caller} == "bye" ]] && start=2
    fi

    for ((i = start; i < depth; i++)); do
        local function="${FUNCNAME[${i}]}"
        local line="${ show bold blue "${BASH_LINENO[${i} - 1]}" ;}"
        local arrow="${ show cyan "->" ;}"
        local called=${FUNCNAME[${i} - 1]}
        local script="${ show dim "${BASH_SOURCE[${i}]}" ;}"
        ((i == start)) && function="${ show red "${function}()" ;}" || function="${ show blue "${function}()" ;}"
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
    (( $# )) && show red "${*}"
    debugStack
    exit 0
}

# Debug control functions

isDebug() {
    ((_debug))
}

setDebug() {
    require 'rayvn/debug'
    _setDebug "${@}"
}

# Placeholder debug functions, replaced in setDebug()

debug() { :; }
debugEnabled() { return 1; }
debugDir() { :; }
debugStatus() { echo 'debug disabled'; }
debugBinary() { :; }
debugVar() { :; }
debugVarIsSet() { :; }
debugVarIsNotSet() { :; }
debugFile() { :; }
debugJson() { :; }
debugStack() { :; }
debugEnvironment() { :; }

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/core' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_core() {

    ((_rayvnCoreInitialized)) && return 0 # Should not occur, but... just in case

    # Setup exit handling

    declare -g _rayvnExitTasks=()
    trap '_onRayvnExit' EXIT
    trap '_onRayvnTerm' TERM
    trap '_onRayvnHup' HUP
    trap '_onRayvnInt' INT

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
    declare -grxi onMacOS=$((osName == "Darwin"))
    declare -grxi onLinux=$((osName == "Linux"))
    declare -grx rayvnRootDir="$(realpath "${BASH_SOURCE%/*}/..")"
    declare -grx rayvnConfigDirPath="${HOME}/.rayvn"
    declare -grx _checkMark='✔'
    declare -grx _crossMark='✗'
    declare -gxi _debug=0

    # Set ANSI related constants

    if ((terminalSupportsAnsi)); then

        # Set ANSI colors if terminal supports them

        # TODO theme
        # See themes.sh showColor() and showFormatting
        # and the colors, bgColors, formats hash tables.
        #
        # Note that there are 16 colors, not 8, because bright versions
        # are included!
        #
        # Also, note that show256Colors() shows how to map the 16 colors
        # to RGB: "\e[48;5;${i}m  %3d  \e[0m", where i = 0-15

        if (($(tput colors) >= 8)); then
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

        if command -v brew >/dev/null; then
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

    # Force these readonly since we have to handle them specially in rayvn.up

    declare -fr fail printStack

    declare -grx _rayvnCoreInitialized=1
}

_restoreTerminal() {
    if ((terminalSupportsAnsi)); then
        stty sane
        printf '\e[0K\e[?25h' # Clear to end of line and show cursor in case sane does not
    fi
}

_onRayvnTerm() {
    _restoreTerminal
    show italic red "🔺 killed"
    exit 1
}

_onRayvnHup() {
    _restoreTerminal
    show italic red "🔺 killed (SIGHUP)"
    exit 1
}

_onRayvnInt() {
    _restoreTerminal
    show italic red "🔺 exiting (ctrl-c)"
    exit 1
}

_onRayvnExit() {
    _restoreTerminal

    # Add a line unless disabled

    [[ -n ${noEchoOnExit} ]] && echo

    # Delete temp dir if we created it

    if [[ ${_rayvnTempDir} ]]; then
        rm -rf -- "${_rayvnTempDir}" &>/dev/null
    fi

    # Run any added tasks

    for task in "${_rayvnExitTasks[@]}"; do
        eval "${task}"
    done
}
