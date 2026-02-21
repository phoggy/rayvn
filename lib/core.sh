#!/usr/bin/env bash
# shellcheck disable=SC2155

# Core library.
# Intended for use via: require 'rayvn/core'

# Set umask to 0077 so that all new files and directories are accessible only by the current user.
allNewFilesUserOnly() {
    # Ensure that all new files are accessible by the current user only
    umask 0077
}

# Execute a command with umask 0022 (files readable by all, writable only by owner).
# Args: command [args...]
withDefaultUmask() {
    withUmask 0022 "${@}"
}

# Execute a command with a temporary umask, then restore the original umask.
# Args: newUmask command [args...]
#
#   newUmask - the umask to set (e.g. 0077, 0022)
#   command  - command and arguments to execute under the new umask
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

# Return the path to a binary, failing with an error if not found.
# Args: name [errMsg]
#
#   name   - name of the binary to locate in PATH
#   errMsg - optional custom error message (default: "'name' not found")
binaryPath() {
    local name="${1}"
    local errMsg="${2:-"'${name}' not found"}"
    type -p "${name}" || fail "${errMsg}"
}

# Return a path rooted at the rayvn project root directory.
# Args: relativePath
#
#   relativePath - path relative to the rayvn root
rootDirPath() {
    echo "${rayvnRootDir}/${1}"
}

# Return the path to the session temp directory, optionally joined with a file name.
# Args: [fileName]
#
#   fileName - optional file name to append to the temp directory path
tempDirPath() {
    _ensureRayvnTempDir
    local fileName="${1:-}"
    [[ ${fileName} ]] && echo "${_rayvnTempDir}/${fileName}" || echo "${_rayvnTempDir}"
}

# Create a temp file in the session temp directory and return its path.
# Args: [nameTemplate]
#
#   nameTemplate - optional mktemp name template with X placeholders (default: XXXXXX)
makeTempFile() {
    _ensureRayvnTempDir
    local file="${ mktemp "${_rayvnTempDir}/${1:-XXXXXX}"; }" # random file name if not passed
    echo "${file}"
}

# Create a named pipe (FIFO) in the session temp directory and return its path.
# Args: [nameTemplate]
#
#   nameTemplate - optional name template with X placeholders (default: XXXXXX)
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

# Create a temp directory in the session temp directory and return its path.
# Args: [nameTemplate]
#
#   nameTemplate - optional mktemp name template with X placeholders (default: XXXXXX)
makeTempDir() {
    _ensureRayvnTempDir
    local directory="${ mktemp -d "${_rayvnTempDir}/${1:-XXXXXX}"; }"  # random dir name if not passed
    echo "${directory}"
}

# Return the path to the current project's config directory, optionally joined with a file name.
# Creates the config directory if it does not exist.
# Args: [fileName]
#
#   fileName - optional file name to append to the config directory path
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

# Create the directory if it does not already exist. Silently succeeds if already present.
# Args: dir
#
#   dir - path of the directory to create
ensureDir() {
    local dir="${1}"
    if [[ ! -d ${dir} ]]; then
        makeDir "${dir}" >/dev/null
    fi
}

# Create a directory (and any missing parents) and return its path. Fails if creation fails.
# Args: dir [subDir]
#
#   dir    - base directory path
#   subDir - optional subdirectory name to append before creating
makeDir() {
    local dir="${1}"
    local subDir="${2:-}"
    [[ -z ${subDir} ]] || dir="${dir}/${subDir}"
    mkdir -p "${dir}" || fail "could not create directory ${dir}"
    echo "${dir}"
}

# Fail with an error if not running interactively.
assertIsInteractive() {
    (( isInteractive )) || fail "must be run interactively"
}

# Register a command to be executed at exit. Commands run in registration order.
# Args: command
#
#   command - shell command string to execute on exit
addExitHandler() {
    _rayvnExitTasks+=("${1}")
}

# Return the directory component of a path (equivalent to dirname).
# Args: path
#
#   path - file or directory path
dirName() {
    local path=${1%/}
    echo "${path%/*}"
}

# Return the final component of a path (equivalent to basename).
# Args: path
#
#   path - file or directory path
baseName() {
    local path=${1%/}
    echo "${path##*/}"
}

# Remove leading and trailing whitespace from a string.
# Args: value
#
#   value - the string to trim
trim() {
    local value="${1}"
    value="${value#"${value%%[![:space:]]*}"}" # remove leading whitespace
    value="${value%"${value##*[![:space:]]}"}" # remove trailing whitespace
    echo "${value}"
}

# Return the number of decimal digits needed to represent values up to maxValue.
# Useful for formatting aligned numeric output.
# Args: maxValue [startValue]
#
#   maxValue   - the largest value to be displayed (must be a positive integer)
#   startValue - 0 (zero-indexed, default) or 1 (one-indexed)
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

# Print a number right-aligned within a fixed-width field.
# Args: number places
#
#   number - the number to print
#   places - minimum field width (right-aligned with spaces)
printNumber() {
    local number="${1}"
    local places=${2-:1}
    printf '%*s' "${places}" "${number}"
}

# Return the version string for a rayvn project (reads its rayvn.pkg file).
# Args: projectName [verbose]
#
#   projectName - name of the project (e.g. 'rayvn', 'valt')
#   verbose     - if non-empty, include release date or "(development)" in the output
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

# Check if an argument matches an expected value and set a result variable via nameref.
# Returns 0 if matched, 1 if not. Used for parsing optional flag-style arguments.
# Args: argMatch argValue resultVar [resultValue]
#
#   argMatch    - the expected argument value to match against (e.g. '-n')
#   argValue    - the actual argument value to test
#   resultVar   - nameref variable to set to resultValue if matched, or '' if not
#   resultValue - value to assign on match (default: argMatch)
parseOptionalArg() {
    local _argMatch=$1
    local _argValue=$2
    local -n _argResultRef=$3
    local _argResultValue="${4:-${_argMatch}}"
    if [[ ${_argValue} == "${_argMatch}" ]]; then
        _argResultRef=${_argResultValue}
        return 0
    else
        _argResultRef=''
        return 1
    fi
}

# Return 0 if a variable with the given name is defined (including empty or null-value vars).
# Args: varName
#
#   varName - name of the variable to check
varIsDefined() {
    declare -p "${1}" &> /dev/null
}

# Fail if a variable with the given name is not defined.
# Args: varName
#
#   varName - name of the variable that must be defined
assertVarDefined() {
    varIsDefined "${1}" || fail "var ${1} not defined"
}

# Fail if the given path does not exist (as any filesystem entry type).
# Args: path
#
#   path - path to check for existence
assertFileExists() {
    [[ -e ${1} ]] || fail "${1} not found"
}

# Fail if the given path does not exist or is not a regular file.
# Args: file [description]
#
#   file        - path that must exist and be a regular file
#   description - optional label for the error message (default: 'file')
assertFile() {
    local file="${1}"
    local description="${2:-file}"
    assertFileExists "${file}"
    [[ -f ${1} ]] || fail "${1} is not an ${description}"
}

# Fail if the given path does not exist or is not a directory.
# Args: dir
#
#   dir - path that must exist and be a directory
assertDirectory() {
    assertFileExists "${1}"
    [[ -d ${1} ]] || fail "${1} is not a directory"
}

# Fail if the given path already exists.
# Args: path
#
#   path - path that must not exist
assertFileDoesNotExist() {
    [[ -e "${1}" ]] && fail "${1} already exists"
}

# Fail if filePath is not located within dirPath (resolves symlinks before checking).
# Args: filePath dirPath
#
#   filePath - the path to verify
#   dirPath  - the directory that must contain filePath
assertPathWithinDirectory() {
    local filePath=${1}
    local dirPath=${2}
    local absoluteFile absoluteDir
    absoluteFile=${ realpath "${filePath}" 2>/dev/null;} || fail
    absoluteDir=${ realpath "${dirPath}" 2>/dev/null;} || fail
    [[ "${absoluteFile}" == ${absoluteDir}/* ]] || fail "${filePath} is not within ${dirPath}"
}

# Fail if the given name is not a valid cross-platform filename component.
# Rejects empty strings, ".", "..", paths with slashes, control characters, and reserved characters.
# Args: name
#
#   name - the filename component to validate (not a full path)
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

# Append a value to an exported variable, space-separated.
# Args: varName value
#
#   varName - name of the variable to append to
#   value   - value to append (prepended with a space if variable is non-empty)
appendVar() {
    export ${1}="${!1:+${!1} }${2}"
}

# Set a nameref variable to the realpath of a file, failing if the path is not a regular file.
# Args: resultVar filePath description
#
#   resultVar   - nameref variable to receive the resolved file path
#   filePath    - path to the file (must exist and be a regular file)
#   description - label used in error messages
setFileVar() {
    _setFileSystemVar "${1}" "${2}" "${3}" false
}

# Set a nameref variable to the realpath of a directory, failing if the path is not a directory.
# Args: resultVar dirPath description
#
#   resultVar   - nameref variable to receive the resolved directory path
#   dirPath     - path to the directory (must exist and be a directory)
#   description - label used in error messages
setDirVar() {
    _setFileSystemVar "${1}" "${2}" "${3}" true
}

# Return the current timestamp as a sortable string: YYYY-MM-DD_HH.MM.SS_TZ
timeStamp() {
    date "+%Y-%m-%d_%H.%M.%S_%Z"
}

# Return the current epoch time with microsecond precision (from EPOCHREALTIME).
epochSeconds() {
    echo "${EPOCHREALTIME}"
}

# Return the elapsed seconds since a previously captured epoch time (6 decimal places).
# Args: startTime
#
#   startTime - start time value captured from ${EPOCHREALTIME}
elapsedEpochSeconds() {
    local startTime="${1}"
    echo "${ awk "BEGIN {printf \"%.6f\", ${EPOCHREALTIME} - ${startTime}}"; }"
}

# Overwrite and unset one or more variables containing sensitive data.
# Each variable's contents are overwritten with spaces before being unset.
# Args: varName [varName...]
#
#   varName - name of a variable to securely erase; silently ignored if not defined
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

# Open a URL in the default browser (macOS: open; Linux: xdg-open).
# Args: url
#
#   url - the URL to open
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

# Execute a command with all rayvn-internal variables unset, simulating a clean environment.
# Args: command [args...]
#
#   command - command and arguments to execute in the clean environment
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

# Print a styled section header with optional sub-text. An optional numeric index selects the color.
# Args: [index] title [subtitle...]
#
#   index    - optional 1-based color index from the header color list (default: 1)
#   title    - header text (printed in uppercase bold)
#   subtitle - optional additional lines printed below the header
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

# Set a variable to a random non-negative integer via nameref.
# Args: resultVar [maxValue]
#
#   resultVar - nameref variable to receive the result; accepts scalars, 'array[i]', or 'map[key]'
#   maxValue  - optional upper bound (inclusive); if omitted, returns full 32-bit range 0..4294967295
randomInteger() {
    local -n _intResult="${1}"
    local maxValue="${2:-}"

    if (( maxValue )); then
        _intResult=$(( SRANDOM % (maxValue + 1) ))
    else
        _intResult="${SRANDOM}"
    fi
}

# Set a variable to a random hex character (0-9, a-f) via nameref.
# Args: resultVar
#
#   resultVar - nameref variable to receive a single hex character
randomHexChar() {
    local -n _hexResult="${1}"
    local _hexIndex
    randomInteger _hexIndex 15
    _hexResult=${_hexChars[_hexIndex]}
}

# Replace every occurrence of a placeholder character in a string with random hex characters.
# Args: replaceChar stringVar
#
#   replaceChar - the character to replace (e.g. 'X')
#   stringVar   - nameref variable containing the string to modify in-place
replaceRandomHex() {
    local replaceChar="${1}"
    local -n replaceRef="${2}"
    local hex
    while [[ ${replaceRef} == *${replaceChar}* ]]; do
        randomHexChar hex
        replaceRef="${replaceRef/${replaceChar}/${hex}}"
    done
}

# Copy all key-value pairs from one associative array to another.
# Args: srcVar destVar
#
#   srcVar  - name of the source associative array
#   destVar - name of the destination associative array (must already be declared as -A)
copyMap() {
    local -n src="${1}"
    local -n dest="${2}"
    for key in "${!src[@]}"; do
        dest[${key}]="${src[${key}]}"
    done
}

# Remove all ANSI escape sequences from a string and print the result.
# Args: string
#
#   string - the string to strip
stripAnsi() {
    echo -n "${1}" | sed 's/\x1b\[[0-9;]*m//g'
}

# Return 0 if a string contains ANSI escape sequences, 1 otherwise.
# Args: string
#
#   string - the string to test
containsAnsi() {
    [[ "${1}" =~ $'\e[' ]]
}

# Repeat a string a given number of times and print the result (no trailing newline).
# Args: str count
#
#   str   - string to repeat
#   count - number of times to repeat the string
repeat() {
    local str=${1}
    local count=${2}
    local result
    printf -v result "%*s" "${count}" ""
    result=${result// /${str}}
    echo -n "${result}"
}

# Return the 0-based index of an item in an array, or -1 if not found.
# Exits 0 if found, 1 if not found.
# Args: item arrayVar
#
#   item     - the value to search for
#   arrayVar - name of the indexed array to search
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

# Return 0 if an item is a member of an array, 1 otherwise.
# Args: item arrayVar
#
#   item     - the value to search for
#   arrayVar - name of the indexed array to search
isMemberOf() {
    indexOf "${1}" "${2}" > /dev/null
}

# Return the length of the longest string in an array (ANSI escape codes not stripped).
# Args: arrayVar
#
#   arrayVar - name of the indexed array to measure
maxArrayElementLength() {
    local -n arrayRef="${1}"
    local max=0 len element
    for element in "${arrayRef[@]}"; do
        len="${#element}"
        (( len > max )) && max=${len}
    done
    echo -n "${max}"
}

# Pad a string to a minimum width, stripping ANSI codes when measuring the visible length.
# Args: string width [position]
#
#   string   - the string to pad
#   width    - minimum total visible character width
#   position - where to add padding: 'after'/'left' (default), 'before'/'right', or 'center'
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

# Print a warning message to the terminal error stream with a warning prefix.
# Args: message [args...]
#
#   message - warning text; additional args are passed as extra show() arguments
warn() {
    show warning "⚠️ ${1}" "${@:2}" > ${terminalErr}
}

# Print an error message to the terminal error stream with an error prefix.
# Args: message [args...]
#
#   message - error text; additional args are passed as extra show() arguments
error() {
    show error "🔺 ${1}" "${@:2}" > ${terminalErr}
}

# Fail with a stack trace. Shorthand for fail --trace when invalid arguments are passed.
# Args: message [args...]
#
#   message - error message describing the invalid arguments
invalidArgs() {
    fail --trace "${@}"
}

# Print an error message (or stack trace in debug mode) and exit with status 1.
# Args: [--trace] message [args...]
#
#   --trace - force a stack trace even outside debug mode
#   message - error message to display
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

# Read lines from stdin and print each one in red to the terminal error stream.
# Intended for use as a pipe consumer, e.g.: someCmd 2>&1 | redStream
redStream() {
    local error
    {
        while read error; do
            show red "${error}"
        done
    } > "${terminalErr}"
}

# Print an optional red message and exit with status 0. Used for clean but early exits.
# Args: [message [args...]]
#
#   message - optional message to display in red before exiting
bye() {
    (( $# )) && show red "${1}" "${@:2}"
    debugStack
    exit 0
}

# Print a formatted call stack, optionally preceded by an error message.
# Args: [message [args...]]
#
#   message - optional error message to display before the stack trace
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

# Enable debug mode, loading the rayvn/debug library and configuring debug output.
# See rayvn/debug for full usage documentation.
# Args: [tty path] [showOnExit] [clearLog] [noStatus]
#
#   tty path   - 'tty <path>' sends debug output to a terminal device; '.' reads ~/.debug.tty
#   showOnExit - 'showOnExit' dumps the debug log to the terminal on exit
#   clearLog   - 'clearLog' clears the log file before writing
#   noStatus   - 'noStatus' suppresses the initial debug status message
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

    # Misc global vars and constants

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

_ensureRayvnTempDir() {
    if [[ ! -n ${_rayvnTempDir} ]]; then
        declare -grx _rayvnTempDir="${ withUmask 0077 mktemp -d; }" || fail "could not create temp directory"
        chmod 700 "${_rayvnTempDir}" || fail "chmod failed on temp dir"
    fi
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
