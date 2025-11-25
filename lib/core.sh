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

assertInTerminal() {
    (( inTerminal )) || assertionFailed "must be run in a terminal"
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
    echo "${EPOCHREALTIME}"
}

# pass start time captured from ${EPOCHREALTIME}
elapsedEpochSeconds() {
    local startTime="${1}"
    echo "${ awk "BEGIN {printf \"%.6f\", ${EPOCHREALTIME} - ${startTime}}"; }"
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

executeWithCleanVars() {
   env "${_unsetChildVars[@]}" "${@}"
}

# Enhanced echo function supporting text color and styles in addition to standard echo
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

    local options=()
    if [[ ${1} == -* ]]; then
        options+=("${1}"); shift
        while (( $# )) && [[ ${1} == -* ]]; do
            options+=("${1}"); shift
        done
    fi

    local output='' currentFormat='' addSpace=0
    while (( $# )); do
        if [[ -n ${1} ]]; then
            if [[ -v _textFormats[${1}] ]]; then
                currentFormat+=${_textFormats[${1}]}
            elif [[ -z "${1//[0-9]/}" ]] && (( ${1} <= 255 )) && (( terminalColorBits >= 8 )); then
                currentFormat+=$'\033[38;5;'"${1}m"    # 256 color
            elif [[ ${1} == RGB ]] && (( $# >=2 )) && (( terminalColorBits >= 24 )); then
                shift; currentFormat+=$'\e[38;2;'"${1//:/;}m" # truecolor
            else
                (( addSpace )) && output+=' '
                output+=${currentFormat}${1}
                currentFormat=''
                addSpace=1
            fi
        fi
        shift
    done
    echo "${options[@]}" "${output}"$'\e[0m'
}

repeat() {
    local str=${1}
    local count=${2}
    local result
    printf -v result "%*s" "${count}" ""
    result=${result// /${str}}
    echo -n "${result}"
}

warn() {
    show warning "⚠️ ${1}" "${@:2}" >&2
}

error() {
    show error "🔺 ${1}" "${@:2}" >&2
}

fail() {
    stackTrace "${@}"
    exit 1
}

redStream() {
    local error
    while read error; do
        show red "${error}"
    done
}

assertionFailed() {
    stackTrace "${@}"
    exit 1
}

bye() {
    (( $# )) && show red "${1}" "${@:2}"
    debugStack
    exit 0
}

stackTrace() {
    local message=("${@}")
    local caller=${FUNCNAME[1]}
    declare -i start=1
    declare -i depth=${#FUNCNAME[@]}

    (( ${#message[@]} )) && error "${@}"

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

    # Did we already do this in a parent process?

    if (( _rayvnCoreInitialized )); then

        # Yes, so just instantiate our "exported" maps

        eval "${_rayvnCoreMapExports}"
        return 0
    fi

    # Setup exit handling

    declare -g _rayvnExitTasks=()
    trap '_onRayvnExit' EXIT
    trap '_onRayvnTerm' TERM
    trap '_onRayvnHup' HUP
    trap '_onRayvnInt' INT

    # Try to ensure UTF-8

    declare -grx LC_ALL=en_US.UTF-8
    declare -grx LANG=en_US.UTF-8
    if [[ "${LC_ALL:-${LANG}}" =~ UTF-8 ]]; then
        declare -grx _hasUTF8=1
    else
        echo "Warning: UTF-8 locale not detected. Unicode may not render correctly." >&2
        declare -grx _hasUTF8=0
    fi

    # We need to set ${terminal} so that it can be used as a redirect.
    # Are stdout and stderr both terminals?

    if [[ -t 1 && -t 2 ]]; then

        # Yes, so set terminal to the tty and remember that we are in a terminal

        declare -grx terminal="/dev/tty"
        declare -grxi inTerminal=1

        # Determine the # of bits of color supported

        local bits=0
        if [[ "${COLORTERM}" == "truecolor" ]] || [[ "${COLORTERM}" == "24bit" ]]; then
            bits=24
        elif [[ "${TERM_PROGRAM}" =~ ^(iTerm\.app|vscode|Hyper|WezTerm|Alacritty|Kitty)$ ]]; then
            bits=24
        elif [[ "${TERM}" =~ 256col ]]; then
            bits=8
        elif [[ "${TERM_PROGRAM}" == "Apple_Terminal" ]]; then
            bits=8
        elif [[ "${TERM}" =~ color ]]; then
            bits=4
        fi
        declare -grxi terminalColorBits=${bits}

    else

        # No. Ensure FD 3 exists and points to original stdout, then set terminal
        # to use it and remember we are not in a terminal.

        [[ -t 3 ]] || exec 3>&1
        declare -grx terminal="&3"
        declare -grxi inTerminal=0

        # Unless a special flag is set, turn off colors

        if (( forceRayvn24BitColor )); then
            declare -grxi terminalColorBits=24
        else
            declare -grxi terminalColorBits=0
        fi
    fi

    # Set some constants

    declare -grx osName="${ uname; }"
    declare -grxi onMacOS=$(( osName == "Darwin" ))
    declare -grxi onLinux=$(( osName == "Linux" ))
    declare -grx rayvnRootDir="${ realpath "${BASH_SOURCE%/*}/.."; }"
    declare -grx rayvnConfigDirPath="${HOME}/.rayvn"
    declare -grx _checkMark='✔'
    declare -grx _crossMark='✗'
    declare -gxi _debug=0

    # Set color/style constants if terminal supports them

    if (( inTerminal )); then
        if (( terminalColorBits >= 4 )); then
            _init_colors
        else
            _init_noColors
        fi
    elif (( forceRayvn24BitColor )); then
        _init_colors
    else
        _init_noColors
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

    # Collect the names of all existing lowercase and underscore prefixed vars if we have not already done so.
    # This allows executeWithCleanVars to exclude all vars set by rayvn.up and core, which ensures that those
    # run as if started from the command line.

    local var unsetVars=()
    IFS=$'\n'
    for var in ${ compgen -v | grep -E '^([a-z]|_[^_])'; }; do
        unsetVars+=("-u")
        unsetVars+=("${var}")
    done
    declare -gax _unsetChildVars=("${unsetVars[@]}")

    # Remove our init helper functions. The current function will be removed by rayvn.up

    unset _init_currentTheme _init_colors _init_noColors

    # Since maps (associative arrays) cannot be exported to child processes, save them so we
    # can restore in children. Note that we must force them to be restored as globals.

    local declareOutput="${ declare -p _textFormats; }"  # Can append multiple ; separated declarations
    declare -grx _rayvnCoreMapExports="${declareOutput//declare -A/declare -gA}"

    # Remember that we've completed this initialization

    declare -grx _rayvnCoreInitialized=1
}

_init_currentTheme() {
    local theme
    if (( terminalColorBits >= 24 )); then
        # TODO THEME load from ~/rayvn/theme.sh
        theme=(
            "Material Design"
            $'\e[38;2;76;175;80m'
            $'\e[38;2;244;67;54m'
            $'\e[38;2;255;193;7m'
            $'\e[38;2;33;100;255m'
            $'\e[38;2;128;108;108m'
            $'\e[38;2;156;39;176m'
            $'\e[38;2;0;188;252m'
            $'\e[38;2;255;152;0m'
        )
    else
        # TODO THEME have both theme4 and theme24 in theme.sh?
        theme=('Basic' '\e[92m' $'\e[91m' $'\e[93m' $'\e[34m' $'\e[36m' $'\e[2m' $'\e[35m' $'\e[96m') # bright-green, bright-red, bright-yellow, blue, cyan, dim, magenta bright-cyan
    fi
    declare -grax _currentThemeName=("${theme[@]}")
}

_init_colors() {
    _init_currentTheme

    declare -grA _textFormats=(

       # Effects on

        ['bold']=$'\e[1m'
        ['dim']=$'\e[2m'
        ['italic']=$'\e[3m'
        ['underline']=$'\e[4m'
        ['blink']=$'\e[5m'
        ['reverse']=$'\e[7m'
        ['strikethrough']='' # $'\e[9m' often not supported

        # Effects off

        ['!bold']=$'\e[22m'
        ['!dim']=$'\e[22m'
        ['!italic']=$'\e[23m'
        ['!underline']=$'\e[24m'
        ['!blink']=$'\e[25m'
        ['!reverse']=$'\e[27m'
        ['!strikethrough']='' # $'\e[29m' often not supported

        # Basic Foreground Colors

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

        # Basic Background Colors

        ['bg-black']=$'\e[40m'
        ['bg-red']=$'\e[41m'
        ['bg-green']=$'\e[42m'
        ['bg-yellow']=$'\e[43m'
        ['bg-blue']=$'\e[44m'
        ['bg-magenta']=$'\e[45m'
        ['bg-cyan']=$'\e[46m'
        ['bg-white']=$'\e[47m'
        ['bg-bright-black']=$'\e[100m'
        ['bg-bright-red']=$'\e[101m'
        ['bg-bright-green']=$'\e[102m'
        ['bg-bright-yellow']=$'\e[103m'
        ['bg-bright-blue']=$'\e[104m'
        ['bg-bright-magenta']=$'\e[105m'
        ['bg-bright-cyan']=$'\e[106m'
        ['bg-bright-white']=$'\e[107m'

        # Theme colors

        ['success']=${_currentThemeName[1]}
        ['error']=${_currentThemeName[2]}
        ['warning']=${_currentThemeName[3]}
        ['info']=${_currentThemeName[4]}
        ['accent']=${_currentThemeName[5]}
        ['muted']=${_currentThemeName[6]}
        ['primary']=${_currentThemeName[7]}
        ['secondary']=${_currentThemeName[8]}

        # Turn off all formats

        ['plain']=$'\e[0m'

        # TODO: these are not formats, so should be elsewhere

        # Vertical line variants (UTF-8)

        ['v-line']="│"          # U+2502 Box drawings light vertical
        ['v-line-heavy']="┃"    # U+2503 Box drawings heavy vertical
        ['v-line-2']="║"        # U+2551 Box drawings double vertical
        ['v-dash-2']="╎"        # U+254E Box drawings light double dash vertical
        ['v-dash-2-heavy']="╏"  # U+254F Box drawings heavy double dash vertical
        ['v-dash-3']="┆"        # U+2506 Box drawings light triple dash vertical
        ['v-dash-3-heavy']="┇"  # U+2507 Box drawings heavy triple dash vertical
        ['v-dash-4']="┊"        # U+250A Box drawings light quadruple dash vertical
        ['v-dash-4-heavy']="┋"  # U+250B Box drawings heavy quadruple dash vertical

        # Block elements (solid)

        ['block-full']="█"      # U+2588 Full block
        ['block-left']="▌"      # U+258C Left half block
        ['block-right']="▐"     # U+2590 Right half block
    )
}

_init_noColors() {
    declare -grA _textFormats=(

        # Effects on

        ['bold']=''
        ['dim']=''
        ['italic']=''
        ['underline']=''
        ['blink']=''
        ['reverse']=''
        ['strikethrough']=''

        # Effects off

        ['!bold']=''
        ['!dim']=''
        ['!italic']=''
        ['!underline']=''
        ['!blink']=''
        ['!reverse']=''
        ['!strikethrough']=''

        # Basic Foreground Colors

        ['black']=''
        ['red']=''
        ['green']=''
        ['yellow']=''
        ['blue']=''
        ['magenta']=''
        ['cyan']=''
        ['white']=''
        ['bright-black']=''
        ['bright-red']=''
        ['bright-green']=''
        ['bright-yellow']=''
        ['bright-blue']=''
        ['bright-magenta']=''
        ['bright-cyan']=''
        ['bright-white']=''

        # Basic Background Colors

        ['bg-black']=''
        ['bg-red']=''
        ['bg-green']=''
        ['bg-yellow']=''
        ['bg-blue']=''
        ['bg-magenta']=''
        ['bg-cyan']=''
        ['bg-white']=''
        ['bg-bright-black']=''
        ['bg-bright-red']=''
        ['bg-bright-green']=''
        ['bg-bright-yellow']=''
        ['bg-bright-blue']=''
        ['bg-bright-magenta']=''
        ['bg-bright-cyan']=''
        ['bg-bright-white']=''

        # Theme colors

        ['success']=''
        ['error']=''
        ['warning']=''
        ['info']=''
        ['accent']=''
        ['muted']=''
        ['primary']=''
        ['secondary']=''

        # Turn off all formats

        ['plain']=''
    )

    declare -grx _greenCheckMark="${_checkMark}"
    declare -grx _redCrossMark="${_crossMark}"
}

_restoreTerminal() {
    if (( inTerminal )); then
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
