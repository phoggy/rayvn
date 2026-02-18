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

    oldUmask="${ umask; }"
    umask "${newUmask}"

    # execute the command and save the status

    "${@}"
    status=${?}

    # Restore the original umask and return command status
    umask "${oldUmask}"
    return "${status}"
}

binaryPath() {
    local name="${1}"
    local errMsg="${2:-"'${name}' not found"}"
    type -p "${name}" || fail "${errMsg}"
}

rootDirPath() {
    echo "${rayvnRootDir}/${1}"
}

tempDirPath() {
    _ensureRayvnTempDir
    local fileName="${1:-}"
    [[ ${fileName} ]] && echo "${_rayvnTempDir}/${fileName}" || echo "${_rayvnTempDir}"
}

_ensureRayvnTempDir() {
    if [[ ! -n ${_rayvnTempDir} ]]; then
        declare -grx _rayvnTempDir="${ withUmask 0077 mktemp -d; }" || fail "could not create temp directory"
        chmod 700 "${_rayvnTempDir}" || fail "chmod failed on temp dir"
    fi
}

makeTempFile() {
    _ensureRayvnTempDir
    local file="${ mktemp "${_rayvnTempDir}/${1:-XXXXXX}"; }" # random file name if not passed
    echo "${file}"
}

makeTempFifo() {
    _ensureRayvnTempDir
    local name="${1:-XXXXXX}" hex
    replaceRandomHex X name
    while [[ -e ${_rayvnTempDir}/${name} ]]; do
        randomHexChar hex
        name+=${hex}
    done
    local fifoPath="${_rayvnTempDir}/${name}"
    mkfifo "${fifoPath}" || fail "could not create fifo ${fifoPath}"
    echo "${fifoPath}"
}

makeTempDir() {
    _ensureRayvnTempDir
    local directory="${ mktemp -d "${_rayvnTempDir}/${1:-XXXXXX}"; }"  # random dir name if not passed
    echo "${directory}"
}

configDirPath() {
    local fileName="${1:-}"
    local configDir="${_systemConfigDir}/${currentProjectName}"

    # Make sure we create the directory if needed. Do it only once by using a global variable

    local configVarName="_${currentProjectName//-/_}ConfigDir" # convert hyphens to underscores
    local -n configRef="${configVarName}"
    if [[ -z ${configRef:-} ]]; then
        configRef="${configDir}"
        withUmask 0077 ensureDir "${configDir}"
    fi

    # Return the path

    [[ -n ${fileName} ]] && echo "${configDir}/${fileName}" || echo "${configDir}"
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

assertIsInteractive() {
    (( isInteractive )) || fail "must be run interactively"
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

numericPlaces() {
    local maxValue="${1}"
    local startValue="${2:-0}"

    [[ -z "${maxValue}" ]] && fail "numericPlaces: max value required"
    (( maxValue == 0 )) && fail "numericPlaces: max value must be at least 1"
    [[ ! "${maxValue}" =~ ^[0-9]+$ ]] && fail "numericPlaces: max value must be a positive integer"
    [[ ! "${startValue}" =~ ^[0-1]$ ]] && fail "numericPlaces: start value must be 0 or 1"
    local maxValue=$(( maxValue + (startValue - 1) )) # adjust count by -1 if startValue == 0 and by 0 if startValue == 1
    echo "${#maxValue}" # return count of digits
}

printNumber() {
    local number="${1}"
    local places=${2-:1}
    printf '%*s' "${places}" "${number}"
}

projectVersion() {
    local projectName="${1}"
    local verbose="${2:-}"
    local -n projectHome="${projectName//-/_}Home"
    local pkgFile="${projectHome}/rayvn.pkg"
    assertFileExists "${pkgFile}"
    (
        require 'rayvn/config'
        sourceConfigFile "${pkgFile}" project
        if [[ ${projectReleaseDate} ]]; then
            [[ ${verbose} ]] && description=" (released ${projectReleaseDate})"
        else
            [[ ${verbose} ]] && description=" (development)"
        fi
        echo "${projectName} ${projectVersion}${description}"
    )
}

varIsDefined() {
    declare -p "${1}" &> /dev/null
}

assertVarDefined() {
    varIsDefined "${1}" || fail "var ${1} not defined"
}

assertFileExists() {
    [[ -e ${1} ]] || fail "${1} not found"
}

assertFile() {
    local file="${1}"
    local description="${2:-file}"
    assertFileExists "${file}"
    [[ -f ${1} ]] || fail "${1} is not an ${description}"
}

assertDirectory() {
    assertFileExists "${1}"
    [[ -d ${1} ]] || fail "${1} is not a directory"
}

assertFileDoesNotExist() {
    [[ -e "${1}" ]] && fail "${1} already exists"
}

assertPathWithinDirectory() {
    local filePath=${1}
    local dirPath=${2}
    local absoluteFile absoluteDir
    absoluteFile=${ realpath "${filePath}" 2>/dev/null;} || fail
    absoluteDir=${ realpath "${dirPath}" 2>/dev/null;} || fail
    [[ "${absoluteFile}" == ${absoluteDir}/* ]] || fail "${filePath} is not within ${dirPath}"
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

    return 0
}

# Run a command and fail if it fails (or produces stderr with --stderr).
# Stdout passes through, so this works with command substitution.
#
# Usage:
#   assertCommand [options] command [args...]
#   result="${ assertCommand some-command; }"
#
# Options:
#   --error "msg"     Custom error message (default: generic failure message)
#   --quiet           Don't include stderr in failure message
#   --stderr          Also fail if command produces stderr output
#   --strip-brackets  Filter out lines matching [text] and trailing blank lines
#
# Examples:
#   assertCommand git commit -m "message"
#   session="${ assertCommand --stderr --error "Failed to unlock" bw unlock --raw; }"
#
#   # For pipelines, use eval with a quoted string:
#   assertCommand --stderr --error "Failed to encrypt" \
#       eval 'tar cz "${dir}" | rage "${recipients[@]}" > "${file}"'

assertCommand() {
    local stripBrackets=0 quiet=0 noStderr=0 message=""

    while [[ "${1}" == --* ]]; do
        case "${1}" in
            --strip-brackets) stripBrackets=1; shift ;;
            --quiet) quiet=1; shift ;;
            --stderr) noStderr=1; shift ;;
            --error) message="${2}"; shift 2 ;;
            *) break ;;
        esac
    done

    local stderrFile="${ makeTempFile 'stderr-XXXXXX'; }"
    "${@}" 2> "${stderrFile}"
    local result=$?

    local stderr=""
    if [[ -s "${stderrFile}" ]]; then
        stderr="${ cat "${stderrFile}"; }"
        if (( stripBrackets )); then
            # Remove bracket-only lines and trailing blank lines
            stderr="${ echo "${stderr}" | grep -v '^\[.*\]$' | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}'; }"
        fi
    fi

    # Fail if command failed, or if --stderr and stderr has content
    local shouldFail=0
    if (( result != 0 )); then
        shouldFail=1
    elif (( noStderr )) && [[ -n "${stderr}" ]]; then
        shouldFail=1
    fi

    if (( shouldFail )); then
        if [[ -n "${message}" ]]; then
            if (( quiet )) || [[ -z "${stderr}" ]]; then
                fail "${message}"
            else
                fail "${message}: ${stderr}"
            fi
        elif [[ -n "${stderr}" ]]; then
            fail "${stderr}"
        else
            fail "command failed with exit code ${result}"
        fi
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
    local realFile="${ realpath "${file}" 2>/dev/null; }"
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

openUrl() {
    local url="${1}"

    case "${OSTYPE}" in
        darwin*)
            open "${url}" || fail "failed to open URL"
            ;;
        linux*)
            if command -v xdg-open > /dev/null 2>&1; then
                xdg-open "${url}" || fail "failed to open URL"
            else
                fail "xdg-open not found - install xdg-utils package"
            fi
            ;;
        *)
            fail "unsupported operating system: ${OSTYPE}"
            ;;
    esac
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
#   show italic IDX 62 "italic 256 color #62 text" plain red "plain red text" # style continuation
#   show IDX 42 "Display 256 color #42"
#   show RGB 52:208:88 "rgb 52 208 88 colored text"
#   show "The answer is" bold 42 "not a color code" # numeric values display normally
#   show "Line 1" nl "Line 2" # insert newline between text
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
#     stopSpinner spinnerId ": ${ show green "success" ;}"
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
#   256 Colors ('indexed' colors):
#     IDX 0-255
#
#   RGB Colors ('truecolor'):
#     RGB 0-255:0-255:0-255
#
#   Special:
#     nl - inserts a newline character
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
            elif [[ ${1} == IDX ]] && (( $# >= 2 )) && (( terminalColorBits >= 8 )); then
                shift
                if [[ -z "${1//[0-9]/}" ]] && (( ${1} <= 255 )); then
                    currentFormat+=$'\033[38;5;'"${1}m"    # 256 color
                else
                    # Invalid color value, treat IDX and value as text
                    (( addSpace )) && output+=' '
                    output+=${currentFormat}"IDX ${1}"
                    currentFormat=''
                    addSpace=1
                fi
            elif [[ ${1} == RGB ]] && (( $# >= 2 )) && (( terminalColorBits >= 24 )); then
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

header() {
    local index=0
    local maxIndex=${#_headerColors[@]}
    if [[ -z "${1//[0-9]/}" ]]; then
        index="${1}"
        (( index > maxIndex )) && index=${maxIndex}
        (( index-=1 ))
        shift
    fi

    local header="${1^^}"
    local color="${_headerColors[${index}]}"
    echo
    show bold primary "┃┃" plain "${color}" "${header[@]}"
    if (( $# > 1 )); then
        shift
        show primary "┃┃" plain "${color}" "${@}"
    fi
    echo
}

# Returns a random integer via nameref
# Args: resultVar [maxValue]
#
# Scalar var names, array index and associative arrays can be passed, e.g. myRandom, 'myArray[$i]', 'myMap[foo]'
# If no maxValue, returns full 32-bit range: 0 to 4294967295

randomInteger() {
    local -n _intResult="${1}"
    local maxValue="${2:-}"

    if (( maxValue )); then
        _intResult=$(( SRANDOM % (maxValue + 1) ))
    else
        _intResult="${SRANDOM}"
    fi
}

randomHexChar() {
    local -n _hexResult="${1}"
    local _hexIndex
    randomInteger _hexIndex 15
    _hexResult=${_hexChars[_hexIndex]}
}

replaceRandomHex() {
    local replaceChar="${1}"
    local -n replaceRef="${2}"
    local hex
    while [[ ${replaceRef} == *${replaceChar}* ]]; do
        randomHexChar hex
        replaceRef="${replaceRef/${replaceChar}/${hex}}"
    done
}

copyMap() {
    local -n src="${1}"
    local -n dest="${2}"
    for key in "${!src[@]}"; do
        dest[${key}]="${src[${key}]}"
    done
}

stripAnsi() {
    echo -n "${1}" | sed 's/\x1b\[[0-9;]*m//g'
}

containsAnsi() {
    [[ "${1}" =~ $'\e[' ]]
}

repeat() {
    local str=${1}
    local count=${2}
    local result
    printf -v result "%*s" "${count}" ""
    result=${result// /${str}}
    echo -n "${result}"
}

indexOf() {
    local item="${1}"
    local -n arrayRef="${2}"
    local max="${#arrayRef[@]}"
    local i
    for (( i=0; i < max; i++ )); do
        if [[ ${arrayRef[${i}]} == "${item}" ]]; then
            echo ${i}; return 0
        fi
    done
    echo -1
    return 1
}

isMemberOf() {
    indexOf "${1}" "${2}" > /dev/null
}

maxArrayElementLength() {
    local -n arrayRef="${1}"
    local max=0 len element
    for element in "${arrayRef[@]}"; do
        len="${#element}"
        (( len > max )) && max=${len}
    done
    echo -n "${max}"
}

padString() {
    local string="${1}"
    local width="${2}"
    local position="${3:-after}"

    local strippedString="${ stripAnsi "${string}"; }"
    local currentLength=${#strippedString}
    local paddingNeeded=$((width - currentLength))

    (( paddingNeeded <= 0 )) && echo -n "${string}" && return 0

    case "${position}" in
        before|right) printf '%*s' "${width}" "${string}" ;;
        after|left)   printf '%-*s' "${width}" "${string}" ;;
        center)
            local leftPad=$((paddingNeeded / 2))
            local rightPad=$((paddingNeeded - leftPad))
            printf '%*s%s%*s' "${leftPad}" '' "${string}" "${rightPad}" ''
            ;;
        *) fail "Invalid position: ${position}" ;;
    esac
}

warn() {
    show warning "⚠️ ${1}" "${@:2}" > ${terminalErr}
}

error() {
    show error "🔺 ${1}" "${@:2}" > ${terminalErr}
}

invalidArgs() {
    fail --trace "${@}"
}

fail() {

    # Determine if we should generate a stack trace

    local trace=0
    if [[ $1 == '--trace' ]]; then
        trace=1; shift
    elif (( _debug || rayvnTest_TraceFail )); then
        trace=1
    fi

    # If spinner is running, stop it

    if varIsDefined _spinnerServerPid; then
        local inRayvnFail=1
        _spinnerExit
    fi

    # Write trace and/or error

    (( trace )) && stackTrace "${@}" > "${terminalErr}" || error "${@}"

    # See ya

    exit 1
}

redStream() {
    local error
    {
        while read error; do
            show red "${error}"
        done
    } > "${terminalErr}"
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
        [[ ${caller} == "fail" || ${caller} == "bye" ]] && start=2
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

# Turn on debug mode

setDebug() {
    require 'rayvn/debug'
    _setDebug "${@}"
}

# Placeholder debug functions, replaced in setDebug()

debug() { :; }
debugEnabled() { return 0; }
debugDir() { :; }
debugStatus() { echo 'debug disabled'; }
debugBinary() { :; }
debugVar() { :; }
debugVars() { :; }
debugVarIsSet() { :; }
debugVarIsNotSet() { :; }
debugFile() { :; }
debugJson() { :; }
debugStack() { :; }
debugTraceOn() { :; }
debugTraceOff() { :; }
debugEscapes() { :; }
debugEnvironment() { :; }
debugFileDescriptors() { :; }

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/core' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_core() {

    # Did we already do this in a parent process?

    if (( _rayvnCoreInitialized )); then

        # Yes, so just instantiate our "exported" maps

        eval "${_rayvnCoreMapExports}"
        return 0
    fi

    # Ensure we are being invoked from rayvn.up

    if ! (( onMacOS || onLinux )); then
        echo -e "\033[0;31m🔺 Run 'source rayvn.up' to initialize rayvn\033[0m"; exit 1
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
    # Are stdout and stderr both terminals AND the NonInteractive flag is not set?

    if [[ -t 1 && -t 2 ]] && (( ! rayvnTest_NonInteractive )); then

        # Yes, so set terminal to the tty and remember that we are interactive

        declare -grx terminal="/dev/tty"
        declare -grx terminalErr="/dev/tty"
        declare -grxi isInteractive=1

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

        # No. Discard terminal output in non-interactive mode.

        declare -grx terminal="/dev/null"
        declare -grx terminalErr="/dev/stderr"
        declare -grxi isInteractive=0

        # Unless a special flag is set, turn off colors

        if (( rayvnTest_Force24BitColor )); then
            declare -grxi terminalColorBits=24
        else
            declare -grxi terminalColorBits=0
        fi
    fi

    # Set some global vars and constants

    declare -gxi _debug=0
    declare -grx rayvnRootDir="${ realpath "${BASH_SOURCE%/*}/.."; }"
    declare -grx _checkMark='✔' # U+2714 Check mark
    declare -grx _crossMark='✘' # U+2718 Heavy ballot X
    declare -grx _hexChars=( '0' '1' '2' '3' '4' '5' '6' '7' '8' '9' 'a' 'b' 'c' 'd' 'e' 'f' )

    declare -garx _headerColors=('bold' 'accent' 'secondary' 'warning' 'success' 'muted')
    declare -grx inContainer=${ [[ -f /.dockerenv || -f /run/.containerenv ]] && echo 1 || echo 0; }
    declare -grx inNix=${ [[ ${rayvnHome} == /nix/store/* ]] && echo 1 || echo 0; }

    #    declare -gArx _symbols=(
#
#        # Vertical line variants (UTF-8)
#
#        ['v-line']="│"          # U+2502 Box drawings light vertical
#        ['v-line-heavy']="┃"    # U+2503 Box drawings heavy vertical
#        ['v-line-2']="║"        # U+2551 Box drawings double vertical
#        ['v-dash-2']="╎"        # U+254E Box drawings light double dash vertical
#        ['v-dash-2-heavy']="╏"  # U+254F Box drawings heavy double dash vertical
#        ['v-dash-3']="┆"        # U+2506 Box drawings light triple dash vertical
#        ['v-dash-3-heavy']="┇"  # U+2507 Box drawings heavy triple dash vertical
#        ['v-dash-4']="┊"        # U+250A Box drawings light quadruple dash vertical
#        ['v-dash-4-heavy']="┋"  # U+250B Box drawings heavy quadruple dash vertical
#
#        # Block elements (solid)
#
#        ['block-full']="█"      # U+2588 Full block
#        ['block-left']="▌"      # U+258C Left half block
#        ['block-right']="▐"     # U+2590 Right half block
#    )

    # Ensure system and rayvn config dirs set to valid directories

    declare -grx _systemConfigDir="${HOME}/.config"
    declare -grx _rayvnConfigDir="${_systemConfigDir}/rayvn"
    [[ -d ${_systemConfigDir} ]] || withUmask 0077 ensureDir "${_systemConfigDir}"
    [[ -d ${_rayvnConfigDir} ]] || withUmask 0077 ensureDir "${_rayvnConfigDir}"

    # Set color/style constants if terminal supports them

    if (( isInteractive )); then
        if (( terminalColorBits >= 4 )); then
            _init_colors
        else
            _init_noColors
        fi
    elif (( rayvnTest_Force24BitColor )); then
        _init_colors
    else
        _init_noColors
    fi

    # Create 'success' check mark and 'error' cross mark

    declare -grx _greenCheckMark="${ show success ${_checkMark}; }"
    declare -grx _redCrossMark="${ show error ${_crossMark}; }"

    # Is this a mac?

    if (( onMacOS )); then

        # Yes, remember if brew is available

        if command -v brew >/dev/null; then
            declare -grxi _brewIsInstalled=1
        fi
    fi

    # Force these readonly since we have to handle them specially in rayvn.up

    (( _rayvnReadOnlyFunctions )) && declare -fr fail printStack

    # Collect the names of all existing lowercase and underscore prefixed vars if we have not already done so.
    # This allows executeWithCleanVars to exclude all vars set by rayvn.up and core, which ensures that those
    # run as if started from the command line. Manually add vars that are created lazily after init.

    local var unsetVars=('-u' '_rayvnCoreInitialized' '-u' '_rayvnTempDir')
    IFS=$'\n'
    for var in ${ compgen -v | grep -E '^([a-z]|_[^_])'; }; do
        unsetVars+=("-u")
        unsetVars+=("${var}")
    done
    declare -gax _unsetChildVars=("${unsetVars[@]}")

    # Remove our init helper functions. The current function will be removed by rayvn.up

    unset _init_theme _init_colors _init_noColors

    # Since maps (associative arrays) cannot be exported to child processes, save them so we
    # can restore in children. Note that we must force them to be restored as globals.

    local declareOutput="${ declare -p _textFormats; }"  # Can append multiple ; separated declarations
    declare -grx _rayvnCoreMapExports="${declareOutput//declare -A/declare -gA}"

    # Remember that we've completed this initialization

    declare -grx _rayvnCoreInitialized=1
}

_init_theme() {
    declare -grx _themeConfigFile="${_rayvnConfigDir}/current.theme"
    local index=0

    # load theme config file if it exists

    if [[ -e "${_themeConfigFile}" ]]; then
        require 'rayvn/config'
        sourceConfigFile "${_themeConfigFile}" theme
    fi

    # create it if theme var not defined

    if [[ ! -v theme ]]; then
        require 'rayvn/theme'
        if (( terminalColorBits < 24 )); then
            index=0  # Basic
        else
            index=1  # Dark Material Design
        fi
        _setTheme ${index}
        echo -e "\nNOTE: Using default theme '${_themeNames[${index}]}'. Run 'rayvn themes' to change.\n"
    else
        index=${theme[1]}
    fi

    declare -grx _currentThemeIndex=${index}
}

_init_colors() {
    _init_theme

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

        ['success']=${theme[2]}
        ['error']=${theme[3]}
        ['warning']=${theme[4]}
        ['info']=${theme[5]}
        ['muted']=${theme[6]}
        ['accent']=${theme[7]}
        ['primary']=${theme[8]}
        ['secondary']=${theme[9]}

        # Turn off all formats

        ['plain']=$'\e[0m'

        # Special formats

        ['nl']=$'\n'
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

        # Special formats

        ['nl']=$'\n'
    )
}

_restoreTerminal() {
    if (( isInteractive )); then
        stty sane 2> /dev/null
        printf '\e[0K\e[?25h' > ${terminal} # Clear to end of line and show cursor in case sane does not
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
    [[ -v rayvnNoExitOnCtrlC ]] && return
    show italic red "🔺 exiting (ctrl-c)"
    exit 1
}

_onRayvnExit() {
    _restoreTerminal

    # Add a line unless disabled

    (( rayvnTest_NoEchoOnExit )) || echo

    # Delete temp dir if we created it

    if [[ ${_rayvnTempDir} ]]; then
        rm -rf -- "${_rayvnTempDir}" &>/dev/null
    fi

    # Run any added tasks

    for task in "${_rayvnExitTasks[@]}"; do
        eval "${task}"
    done
}
