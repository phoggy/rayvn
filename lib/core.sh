#!/usr/bin/env bash
# shellcheck disable=SC2155

# Common core.
# Use via: require 'rayvn/core'

# ──────────────────────────────────────────────────────────────────────────────
# OUTPUT & ERROR FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Enhanced echo with text colors, styles, and standard echo options.
#   Each FORMAT token applies to the immediately following TEXT arg only, then resets.
#   Multiple FORMAT tokens before a TEXT arg accumulate for that one TEXT arg.
#
# · USAGE
#
#   show [-n] [-e|-E] [FORMAT|TEXT]...
#
#   -n                 No trailing newline.
#   -e                 Enable backslash escape interpretation.
#   -E                 Suppress backslash escape interpretation.
#   [FORMAT] (string)  A format token (see NOTES); applies to the next [TEXT] arg.
#   [TEXT] (string)    A string to print with accumulated formats applied, then reset.
#
# · NOTES
#
#   Available formats:
#
#   - **Theme** `success` `error` `warning` `info` `accent` `muted`
#   - **Style** `bold` `dim` `italic` `underline` `blink` `reverse` `strikethrough`
#   - **Foreground** `black` `red` `green` `yellow` `blue` `magenta` `cyan` `white` (and `bright-*` variants)
#   - **Background** `bg-black` `bg-red` `bg-green` `bg-yellow` `bg-blue` `bg-magenta` `bg-cyan` `bg-white` (and `bg-bright-*` variants)
#   - **256-color** `IDX` \<0-255\>
#   - **true-color** `RGB` \<R:G:B\>
#   - **Special** `nl` (insert newline), `glue` (suppress space before next arg)
#
#   While most modern terminals support 256-color or true-color (24 bit), stick to theme colors
#   if compatibility is a concern — they automatically fall back to 16-color. Some terminals may
#   not support strikethrough.
#
# · EXAMPLE
#
#   show blue "blue text"
#   show bold red "bold red"
#   show -n yellow "no trailing newline"
#   show success "done"
#   show warning "check this"
#   show error "failed"
#   show italic underline green "italic underline green"
#   show bold blue "heading" "body text"                      # heading resets; body is plain
#   show cyan "colored" dim "dim, no color"                   # each arg gets its own format
#   show "Line 1" nl "Line 2"                                 # newline between args
#   show bg-blue white "white on blue"
#   show IDX 42 "256-color #42" RGB 52:208:88 "truecolor"
#   show "(default:" blue "${configDir}" glue ")."            # suppress space before closing paren
#   result="${ show bold green "ok"; }"                       # in command substitution

show() {
    if (( ! $# )); then
        echo
        return
    fi

    local options=()
    if [[ $1 == -* ]]; then
        options+=("$1"); shift
        while (( $# )) && [[ $1 == -* ]]; do
            options+=("$1"); shift
        done
    fi

    local output='' currentFormat='' addSpace=0
    while (( $# )); do
        if [[ -n $1 ]]; then
            if [[ -v _textFormats[$1] ]]; then
                currentFormat+=${_textFormats[$1]}
            elif [[ $1 == IDX ]] && (( $# >= 2 )) && (( terminalColorBits >= 8 )); then
                shift
                if [[ -z "${1//[0-9]/}" ]] && (( $1 <= 255 )); then
                    currentFormat+=$'\033[38;5;'"$1m"    # 256 color
                else
                    # Invalid color value, treat IDX and value as text
                    (( addSpace )) && output+=' '
                    output+=${currentFormat}"IDX $1"
                    [[ -n $currentFormat ]] && output+=$'\e[0m'
                    currentFormat=''
                    addSpace=1
                fi
            elif [[ $1 == RGB ]] && (( $# >= 2 )) && (( terminalColorBits >= 24 )); then
                shift; currentFormat+=$'\e[38;2;'"${1//:/;}m" # truecolor
            elif [[ $1 == 'glue' ]]; then
                addSpace=0
            else
                (( addSpace )) && output+=' '
                output+=${currentFormat}$1
                [[ -n $currentFormat ]] && output+=$'\e[0m'
                currentFormat=''
                addSpace=1
            fi
        fi
        shift
    done
    [[ -n $currentFormat ]] && output+=$currentFormat$'\e[0m'
    echo "${options[@]}" "${output}"
}

# ◇ Shadows the bash builtin echo. Routes to the terminal device when stdout is a TTY,
#   enabling tty capture in tests; see startTtyCapture(). Pass '-' as the first arg to
#   write to stdout directly (bypasses TTY routing, e.g. when redirecting to another fd).

echo() {
    if [[ $1 == '-' ]]; then
        shift; builtin echo "$@"
    elif [[ -t 1 ]]; then
        builtin echo "$@" >&${ttyFd}
    else
        builtin echo "$@"
    fi
}

# ◇ Print a styled section header with optional subtitle lines.
#
# · USAGE
#
#   header [-u] [colorIndex] title [subtitle [FORMAT|TEXT]...]
#
#   -u                   Convert title to uppercase.
#   colorIndex (int)     Color index, clamped to max (0=bold, 1=accent, 2=secondary, 3=warning, 4=success, 5=muted).
#   title (string)       Title text printed in bold.
#   [subtitle] (string)  First subtitle arg, printed in the header color.
#   [FORMAT] (string)    A show format token; applies to the next [TEXT] arg.
#   [TEXT] (string)      Text to print with the preceding format applied.

header() {
    local toUpper=0 colorIndex=0
    local maxIndex=$(( ${#_headerColors[@]} - 1 ))
    parseOptionalArg '-u' "$1" toUpper 1 && shift

    if [[ -z "${1//[0-9]/}" ]]; then
        colorIndex="$1"
        (( colorIndex > maxIndex )) && colorIndex=${maxIndex}
        shift
    fi
    local header="$1"
    (( toUpper )) && header="${header^^}"
    local color="${_headerColors[${colorIndex}]}"
    echo
    show bold primary "┃┃" "${color}" "${header[@]}"
    if (( $# > 1 )); then
        shift
        show primary "┃┃" "${color}" "$1" "${@:2}"
    fi
    echo
}

# ◇ Print a warning message to stderr with a ⚠️ prefix.
#
# · USAGE
#
#   warn message [FORMAT|TEXT]...
#
#   message (string)   Warning message text.
#   [FORMAT] (string)  A show format token; applies to the next [TEXT] arg.
#   [TEXT] (string)    Text to print with the preceding format applied.

warn() {
    local msg; msg=${ show warning "⚠️ $1" "${@:2}"; }
    builtin echo "${msg}" > ${terminalErr}
}

# ◇ Print an error message to stderr with a 🔺 prefix.
#
# · USAGE
#
#   error message [FORMAT|TEXT]...
#
#   message (string)   Error message text.
#   [FORMAT] (string)  A show format token; applies to the next [TEXT] arg.
#   [TEXT] (string)    Text to print with the preceding format applied.

error() {
    local msg; msg=${ show error "🔺 $1" "${@:2}"; }
    builtin echo "${msg}" > ${terminalErr}
}

# ◇ Fail with a stack trace. Shorthand for fail --trace on invalid arguments.
#
# · USAGE
#
#   invalidArgs message [FORMAT|TEXT]...
#
#   message (string)   Error message text.
#   [FORMAT] (string)  A show format token; applies to the next [TEXT] arg.
#   [TEXT] (string)    Text to print with the preceding format applied.

invalidArgs() {
    fail --trace "$@"
}

# ◇ Print an error and exit 1, optionally with a stack trace.
#
# · USAGE
#
#   fail [--trace] message [FORMAT|TEXT]...
#
#   --trace            Force a stack trace regardless of debug mode.
#   message (string)   Error message text.
#   [FORMAT] (string)  A show format token; applies to the next [TEXT] arg.
#   [TEXT] (string)    Text to print with the preceding format applied.

fail() {

    # Determine if we should generate a stack trace

    local trace=0
    if [[ $1 == '--trace' ]]; then
        trace=1; shift
    elif (( _debug || rayvnTest_TraceFail )); then
        trace=1
    fi

    # If spinner is running, stop it

    if varDefined _spinnerServerPid; then
        local inRayvnFail=1
        _spinnerExit
    fi

    # Write trace and/or error

    (( trace )) && stackTrace "$@" > "${terminalErr}" || error "$@"

    # See ya

    exit 1
}

# ◇ Print an optional exit message, show stack if in debug mode, and exit 0.
#
# · USAGE
#
#   bye [message [FORMAT|TEXT]...]
#
#   [message] (string)   Exit message text.
#   [FORMAT] (string)    A show format token; applies to the next [TEXT] arg.
#   [TEXT] (string)      Text to print with the preceding format applied.

bye() {
    (( $# )) && show error "$1" "${@:2}"
    debugStack
    exit 0
}

# ◇ Print a formatted call stack, optionally preceded by a message.
#
# · USAGE
#
#   stackTrace [message [FORMAT|TEXT]...]
#
#   [message] (string)   Message text.
#   [FORMAT] (string)    A show format token; applies to the next [TEXT] arg.
#   [TEXT] (string)      Text to print with the preceding format applied.

stackTrace() {
    local message=("$@")
    local caller=${FUNCNAME[1]}
    declare -i start=1
    declare -i depth=${#FUNCNAME[@]}

    (( ${#message[@]} )) && error "$@"
    if (( depth > 2 )); then
        [[ ${caller} == "fail" || ${caller} == "bye" ]] && start=2
    fi

    for (( i = start; i < depth; i++ )); do
        local function="${FUNCNAME[${i}]}"
        local line="${ show bold blue "${BASH_LINENO[${i} - 1]}" ;}"
        local arrow="${ show cyan "->" ;}"
        local called=${FUNCNAME[${i} - 1]}
        local script="${ show dim "${BASH_SOURCE[${i}]}" ;}"
        (( i == start )) && function="${ show red "${function}()" ;}" || function="${ show blue "${function}()" ;}"
        builtin echo "   ${function} ${script}:${line} ${arrow} ${called}()"
    done
}

# ◇ Print each line of a piped stream in error color to stderr.
#
# · EXAMPLE
#
#   someCommand 2> >( errorStream )

errorStream() {
    local error
    while read error; do
        local msg; msg=${ show red "${error}"; }
        builtin echo "${msg}"
    done
} > "${terminalErr}"


# ──────────────────────────────────────────────────────────────────────────────
# ARGUMENT & VARIABLE FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Check if an argument matches an expected value, setting a result var via nameref.
#
# · ARGS
#
#   argMatch (string)         Expected argument value to match against (e.g. -n).
#   argValue (string)         Actual argument value to test.
#   argResultRef (stringRef)  Name of var to set to argResultValue on match, or '' if not.
#   argResultValue (string)   Value to assign on match; defaults to ${argMatch}.
#
# · RETURNS
#
#   0  matched
#   1  not matched

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

# ◇ Maps a boolean argument to 1 for true, 0 for false so that it can subsequently be tested using (( flag )).
#   Converted to lower case to allow upper or mixed case true/false. An integer value >= 1 is true, <= 0 is false.
#
# · ARGS
#
#   arg (bool)            The boolean argument.
#   resultRef (stringRef) Name of var to set result.
#
# · EXAMPLE
#
#   local doX; booleanArgToInt "$1" doX           # Set doX
#   local doY; booleanArgToInt "${1:-true}" doY   # Set doY with default value.

booleanArgToInt() {
    local arg="${1,,}"
    local -n resultRef=$2
    if [[ ${arg} == 'true' ]] || [[ ${arg} =~ ^[1-9][0-9]*$ ]]; then
        resultRef=1
    elif [[ ${arg} == 'false' ]] || [[ ${arg} =~ ^-?[0-9]+$ ]]; then
        resultRef=0
    else
        fail "boolean argument required, got: $1"
    fi
}

# ◇ Return 0 if a variable with the given name is defined, including empty or null-value vars.

varDefined() {
    declare -p "$1" &> /dev/null
}

# ◇ Fail if a variable with the given name is not defined.

assertVarDefined() {
    varDefined "$1" || fail "var $1 not defined"
}

# ◇ Overwrite one or more security sensitive variables with spaces then unset.
#
# · ARGS
#
#   varName (stringRef)  Name of a variable to erase; may be repeated, silently ignored if unset.

eraseVars() {
    local varName value length
    while (( $# > 0 )); do
        varName="$1"
        if [[ -n ${!varName+x} ]]; then
            value="${!varName}"
            length="${#value}"
            printf -v "${varName}" '%*s' "${length}" ''
            unset "${varName}"
        fi
        shift
    done
}

# ◇ Register one or more associative arrays (passed by name) for export to child processes.
#   Bash cannot export associative arrays directly; this serializes them into an internal
#   exported variable. When a child process sources rayvn.up, the map(s) will be restored.
#   Needed when a script spawns a child process (e.g. via bash or exec) that sources rayvn.up
#   and calls functions that depend on the map. Not needed for subshells (${ } and $( )),
#   which inherit variables automatically. Call from a library _init function.
#
# · ARGS
#
#   varName (stringRef)  Name of an associative array to register; may be repeated.
#
# · EXAMPLE
#
#   # In 'myproject/mylib' _init_myproject_mylib(),  build a lookup table, then register it so that
#   # child processes launched by the user's script (e.g. bash myOtherScript) see the populated map.
#   declare -gA myLookup=([foo]=1 [bar]=2)
#   exportGlobalMaps myLookup

exportGlobalMaps() {
    [[ -v _rayvnGlobalMaps ]] || declare -gx _rayvnGlobalMaps=''

    while (( $# )); do
        local declaration="${ declare -p "$1"; }"
        # Normalize to 'declare -gA varname=(...)' — strips extra flags (-r, -x, -i, etc.)
        # so that _restoreGlobalMaps can use a simple fixed-format regex and eval.
        [[ "${declaration}" =~ ^declare[[:space:]]+-[a-zA-Z]*A[a-zA-Z]*([[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*)=(.*) ]] \
            || fail "'$1' is not a map (associative array)"
        _rayvnGlobalMaps+="declare -gA${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"$'\n'
        shift
    done
}


# ──────────────────────────────────────────────────────────────────────────────
# ASSERTION FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Fail with an error if not running interactively.

assertIsInteractive() {
    (( isInteractive )) || fail "must be run interactively"
}

# ◇ Fails if the given path does not exist.

assertFileExists() {
    [[ -e $1 ]] || fail "$1 not found"
}

# ◇ Fail if the given path does not exist or is not a regular file.
#
# · ARGS
#
#   file (string)         Path that must exist and be a regular file.
#   description (string)  Label used in the error message (default: "file").

assertFile() {
    local file="$1"
    local description="${2:-file}"
    assertFileExists "${file}"
    [[ -f $1 ]] || fail "$1 is not an ${description}"
}

# ◇ Fail if the given path does not exist or is not a directory.

assertDirectory() {
    assertFileExists "$1"
    [[ -d $1 ]] || fail "$1 is not a directory"
}

# ◇ Fail if the given path already exists.

assertFileDoesNotExist() {
    [[ ! -e "$1" ]] || fail "$1 already exists"
}

# ◇ Fails if filePath is not located within dirPath, resolving symlinks before checking.
#
# · ARGS
#
#   filePath (string)    Path to verify.
#   dirPath (string)     Directory that must contain filePath.

assertPathWithinDirectory() {
    local filePath=$1
    local dirPath=$2
    local absoluteFile absoluteDir
    absoluteFile=${ realpath "${filePath}" 2>/dev/null;} || fail
    absoluteDir=${ realpath "${dirPath}" 2>/dev/null;} || fail
    [[ "${absoluteFile}" == ${absoluteDir}/* ]] || fail "${filePath} is not within ${dirPath}"
}

# ◇ Fail if name is not a valid cross-platform filename component.
#
# · ARGS
#
#   name (string)  Filename component to validate (not a full path).
#
# · NOTES
#
#   Rejects: empty string, . .. / control characters <>:"\|?*

assertValidFileName() {
    local name="$1"

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

# ◇ Fail if the given directory (or PWD) is not within a git repository.
#
# · ARGS
#
#   dir (string)  Directory to check (default: ${PWD}).

assertGitRepo() {
    local dir="${1:-${PWD}}"
    git -C "${dir}" rev-parse --git-dir &> /dev/null || fail "${dir} is not a git repository"
}

# ◇ Run a command and fail if it exits non-zero, or if it produces stderr with --stderr.
#
# · USAGE
#
#   assertCommand [--strip-brackets] [--quiet] [--stderr] [--error MSG] command...
#
#   --strip-brackets       Strip lines matching '^\[.*\]$' and trailing blank lines from stderr.
#   --quiet                Suppress stderr content from the failure message.
#   --stderr               Also fail if the command produces any stderr output.
#   --error MSG (string)   Custom failure message (default: stderr output or generic exit code message).
#   ... (string)           The command and arguments to execute.
#
# · EXAMPLE
#
#   assertCommand git commit -m "message"
#
# · EXAMPLE
#
#   session="${ assertCommand --stderr --error "Failed to unlock" bw unlock --raw; }"
#
# · EXAMPLE
#
#   # For pipelines, wrap in eval:
#   assertCommand --stderr --error "Failed to encrypt" \
#       eval 'tar cz "${dir}" | rage "${recipients[@]}" > "${file}"'

assertCommand() {
    local stripBrackets=0 quiet=0 noStderr=0 message=""

    while [[ "$1" == --* ]]; do
        case "$1" in
            --strip-brackets) stripBrackets=1; shift ;;
            --quiet) quiet=1; shift ;;
            --stderr) noStderr=1; shift ;;
            --error) message="$2"; shift 2 ;;
            *) break ;;
        esac
    done

    local stderrFile="${ makeTempFile 'stderr-XXXXXX'; }"
    "$@" 2> "${stderrFile}"
    local result=$?

    local stderr=""
    if [[ -s "${stderrFile}" ]]; then
        stderr="${ cat "${stderrFile}"; }"
        if (( stripBrackets )); then
            # Remove bracket-only lines and trailing blank lines
            stderr="${ echo "${stderr}" | grep -v '^\[.*\]$' | gsed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}'; }"
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


# ──────────────────────────────────────────────────────────────────────────────
# STRING, ARRAY & MAP FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Outputs a string with leading and trailing whitespace removed.

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}" # remove leading whitespace
    value="${value%"${value##*[![:space:]]}"}" # remove trailing whitespace
    echo "${value}"
}

# ◇ Outputs a string repeated N times, without a trailing newline.
#
# · ARGS
#
#   str (string)  String to repeat.
#   count (int)   Number of repetitions.

repeat() {
    local str=$1
    local count=$2
    local result
    printf -v result "%*s" "${count}" ""
    result=${result// /${str}}
    echo -n "${result}"
}

# ◇ Outputs a string padded to a given width, measuring visible length by stripping ANSI codes.
#
# · ARGS
#
#   string (string)    Target string.
#   width (int)        Minimum visible character width.
#   position (string)  Padding side: 'after'/'left' (default), 'before'/'right', or 'center'.

padString() {
    local string="$1"
    local width="$2"
    local position="${3:-after}"

    local strippedString="${ stripAnsi "${string}"; }"
    local currentLength=${#strippedString}
    local paddingNeeded=$(( width - currentLength ))

    (( paddingNeeded <= 0 )) && echo -n "${string}" && return 0

    case "${position}" in
    before|right) printf '%*s' "${width}" "${string}" ;;
    after|left)   printf '%-*s' "${width}" "${string}" ;;
    center)
        local leftPad=$(( paddingNeeded / 2 ))
        local rightPad=$(( paddingNeeded - leftPad ))
        printf '%*s%s%*s' "${leftPad}" '' "${string}" "${rightPad}" ''
        ;;
    *) fail "Invalid position: ${position}" ;;
    esac
}

# ◇ Outputs a string with any ANSI escape sequences removed.

stripAnsi() {
    [[ "$1" =~ $'\e[' ]] && echo -n "$1" | gsed 's/\x1b\[[0-9;]*m//g' || echo -n "$1"
}

# ◇ Return 0 if a string contains ANSI escape sequences, 1 otherwise.

containsAnsi() {
    [[ "$1" =~ $'\e[' ]]
}

# ◇ Find the index of a matching element in an array, storing the result in resultRef (-1 if not found).
#
# · ARGS
#
#   match (string)         Match value; prefix with -p for prefix match, -s for suffix match, -r for regex.
#   arrayRef (arrayRef)    Name of the indexed array to search.
#   resultRef (stringRef)  Name of the variable to store the found index.
#
# · RETURNS
#
#   0  match found
#   1  no match found

indexOf() {
    local regex=0 _p _s _i
    case $1 in
        -p) shift; match="$1"; _s='*' ;;
        -s) shift; match="$1"; _p='*' ;;
        -r) shift; match="$1"; regex=1 ;;
        *) match="$1"
    esac
    local -n arrayRef=$2
    local -n resultRef=$3
    local max="${#arrayRef[@]}"
    for (( _i=0; _i < max; _i++ )); do
        if (( regex )); then
            if [[ ${arrayRef[_i]} =~ ${match} ]]; then
                resultRef=${_i}; return 0
            fi
        else
            if [[ ${arrayRef[_i]} == $_p"${match}"$_s ]]; then
                resultRef=${_i}; return 0
            fi
        fi
    done
    resultRef=-1; return 1
}

# ◇ Return 0 if item is a member of an array, 1 otherwise.
#
# · ARGS
#
#   item (string)        Value to search for.
#   arrayRef (arrayRef)  Name of the indexed array to search.

memberOf() {
    local index
    indexOf "$1" "$2" index
}

# ◇ Outputs the length of the longest element in an array.
#
# · ARGS
#
#   arrayRef (arrayRef)  Name of the indexed array to measure.

maxArrayElementLength() {
    local -n arrayRef="$1"
    local max=0 len element
    for element in "${arrayRef[@]}"; do
        len="${#element}"
        (( len > max )) && max=${len}
    done
    echo -n "${max}"
}

# ◇ Copy all key-value pairs from one associative array to another.
#
# · ARGS
#
#   src (mapRef)   Name of the source map.
#   dest (mapRef)  Name of the destination map (must already be declared with -A).

copyMap() {
    local -n srcRef="$1"
    local -n destRef="$2"
    for key in "${!srcRef[@]}"; do
        destRef[${key}]="${srcRef[${key}]}"
    done
}


# ──────────────────────────────────────────────────────────────────────────────
# NUMBER & RANDOM VALUE FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Outputs the number of decimal digits needed to represent integers up to maxValue.
#
# · ARGS
#
#   maxValue (int)  Largest value to represent; must be a positive integer.
#   startValue (int)  Index base: 0 (zero-indexed, default) or 1 (one-indexed).

numericPlaces() {
    local maxValue="$1"
    local startValue="${2:-0}"

    [[ -z "${maxValue}" ]] && fail "numericPlaces: max value required"
    (( maxValue == 0 )) && fail "numericPlaces: max value must be at least 1"
    [[ ! "${maxValue}" =~ ^[0-9]+$ ]] && fail "numericPlaces: max value must be a positive integer"
    [[ ! "${startValue}" =~ ^[0-1]$ ]] && fail "numericPlaces: start value must be 0 or 1"
    local maxValue=$(( maxValue + (startValue - 1) )) # adjust count by -1 if startValue == 0 and by 0 if startValue == 1
    echo "${#maxValue}" # return count of digits
}

# ◇ Outputs a number right-aligned within a fixed-width field.
#
# · ARGS
#
#   number (int)  Number to output.
#   places (int)  Minimum field width; defaults to 1.

printNumber() {
    local number="$1"
    local places=${2-:1}
    printf '%*s' "${places}" "${number}"
}

# ◇ Set a variable to a random integer, optionally capped at maxValue (inclusive).
#
# · ARGS
#
#   intResult (stringRef)  Variable to receive the result.
#   maxValue (int)  Optional inclusive upper bound; omits for full SRANDOM range.

randomInteger() {
    local -n _intResultRef="$1"
    local maxValue="${2:-}"

    if (( maxValue )); then
        _intResultRef=$(( SRANDOM % (maxValue + 1) ))
    else
        _intResultRef="${SRANDOM}"
    fi
}

# ◇ Set a random hex character (0–9, a–f) via nameref.
#
# · ARGS
#
#   _hexResultRef (stringRef)  Name of the variable to receive the result.

randomHexChar() {
    local -n _hexResultRef="$1"
    local _hexIndex
    randomInteger _hexIndex 15
    _hexResultRef=${_hexChars[_hexIndex]}
}

# ◇ Generate a random hex string of count characters, stored via name-ref.
#
# · ARGS
#
#   count (int)  Number of hex characters to generate.
#   _resultRef (stringRef)  Name of the variable to receive the result.

randomHexString() {
    local count=$1
    local -n _resultRef=$2
    local _hexChar _hexString _i
    for (( _i=0; _i < ${count}; _i++ )); do
        randomHexChar _hexChar
        _hexString+="${_hexChar}"
    done
    _resultRef=${_hexString}
}

# ◇ Replace every occurrence of a placeholder character in a string with random hex chars, in-place.
#
# · ARGS
#
#   replaceChar (string)    The placeholder character to replace.
#   replaceRef (stringRef)  Name of the variable to modify in-place.
#
# · EXAMPLE
#
#   myStr="XXXX-XXXX"
#   replaceRandomHex "X" myStr  # myStr becomes e.g. "3a7f-c209"

replaceRandomHex() {
    local replaceChar="$1"
    local -n replaceRef="$2"
    local hex
    while [[ ${replaceRef} == *${replaceChar}* ]]; do
        randomHexChar hex
        replaceRef="${replaceRef/${replaceChar}/${hex}}"
    done
}


# ──────────────────────────────────────────────────────────────────────────────
# TIME FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Outputs the current timestamp as a sortable string: YYYY-MM-DD_HH.MM.SS_TZ

timeStamp() {
    date "+%Y-%m-%d_%H.%M.%S_%Z"
}

# ◇ Outputs the current epoch time with microsecond precision via EPOCHREALTIME.

epochSeconds() {
    echo "${EPOCHREALTIME}"
}

# ◇ Outputs elapsed seconds since a previously captured EPOCHREALTIME value (6 decimal places).
#
# · ARGS
#
#   startTime (string)  Value previously captured from EPOCHREALTIME.

elapsedEpochSeconds() {
    local startTime="$1"
    echo "${ gawk "BEGIN {printf \"%.6f\", ${EPOCHREALTIME} - ${startTime}}"; }"
}


# ──────────────────────────────────────────────────────────────────────────────
# FILE SYSTEM FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Execute a command with umask 0022 (files readable by all, writable only by owner).

withDefaultUmask() {
    withUmask 0022 "$@"
}

# ◇ Execute a command with a temporary umask, restoring the original afterward.
#
# · ARGS
#
#   newUmask (string)  Umask to set for the duration (e.g. 0022, 0077).
#   command (string)   Command and arguments to execute.

withUmask() {
    local newUmask="$1"
    local oldUmask status
    shift

    # Save umask and set to new

    oldUmask="${ umask; }"
    umask "${newUmask}"

    # execute the command and save the status

    "$@"
    status=$?

    # Restore the original umask and return command status
    umask "${oldUmask}"
    return "${status}"
}

# ◇ Outputs the path to a binary, or fails with an optional custom error message if not found.
#
# · ARGS
#
#   name (string)    Name of the binary to locate in PATH.
#   errMsg (string)  Error message if not found; defaults to "'${name}' not found".

binaryPath() {
    local name="$1"
    local errMsg="${2:-"'${name}' not found"}"
    type -p "${name}" || fail "${errMsg}"
}

# ◇ Outputs the session temp directory path, optionally appended with a file name. Does not create the file or dir.
#
# · USAGE
#
#   tempDirPath [-r] [fileName]
#
#   -r                   Replace 'X' chars in fileName with random hex chars, or generate an 8-char hex name if
#                        fileName is omitted. Ensures that no name collisions occur, regenerating name up to 16
#                        times if required.
#   fileName (string)    Optional file name to append to the temp dir path.

tempDirPath() {
    _ensureRayvnTempDir
    if [[ $1 == '-r' ]]; then
        shift
        local template="${1:-}" fileName
        for i in {0..15}; do
            fileName="${template}"
            if [[ -n "${template}" ]]; then
                replaceRandomHex X fileName
            else
                randomHexString 8 fileName
            fi
            if [[ ! -e "${_rayvnTempDir}/${fileName}" ]]; then
                echo "${_rayvnTempDir}/${fileName}"
                return 0
            fi
        done
        fail "could not create unique random path in the session temp directory"

    elif [[ -n "$1" ]]; then
        echo "${_rayvnTempDir}/$1"
    else
        echo "${_rayvnTempDir}"
    fi
}

# ◇ Creates a unique temp file in the session temp dir, outputting its path.
#
# · ARGS
#
#   fileName (string)  Optional; see tempDirPath -r.

makeTempFile() {
    local filePath="${ tempDirPath -r "$1"; }"
    touch "${filePath}"
    chmod 600 "${filePath}"
    echo "${filePath}"
}

# ◇ Creates a unique named pipe (FIFO) in the session temp dir, outputting its path.
#
# · ARGS
#
#   fileName (string)  Optional; see tempDirPath -r.

makeTempFifo() {
    local fifoPath="${ tempDirPath -r "$1"; }"
    mkfifo -m 600 "${fifoPath}" || fail "could not create fifo: ${fifoPath}"
    echo "${fifoPath}"
}

# ◇ Create a unique temp directory in the session temp directory, outputting its path.
#
# · ARGS
#
#   dirName (string)  Optional; see tempDirPath -r.

makeTempDir() {
    local dirPath="${ tempDirPath -r "$1"; }"
    mkdir "${dirPath}" || fail "could not create directory: ${dirPath}"
    echo "${dirPath}"
}

# ◇ Outputs the config directory path for the current project, creating it if needed,
#   optionally joined with fileName.
#
# · ARGS
#
#   fileName (string)    Optional name of a file to append to the config dir path.

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

# ◇ Create directory if it does not already exist.

ensureDir() {
    local dir="$1"
    if [[ ! -d ${dir} ]]; then
        makeDir "${dir}" >/dev/null
    fi
}

# ◇ Create a directory (and any missing parents), outputting the final path.
#
# · ARGS
#
#   dir (string)     Base directory path.
#   subDir (string)  Optional subdirectory to append before creating.

makeDir() {
    local dir="$1"
    local subDir="${2:-}"
    [[ -z ${subDir} ]] || dir="${dir}/${subDir}"
    mkdir -p "${dir}" || fail "could not create directory ${dir}"
    echo "${dir}"
}

# ◇ Outputs the directory component of a path, equivalent to dirname.

dirName() {
    local path=${1%/}
    echo "${path%/*}"
}

# ◇ Outputs the final component of a path, equivalent to basename.

baseName() {
    local path=${1%/}
    echo "${path##*/}"
}

# ◇ Read the entire contents of a file into a variable, without forking a subprocess.
#   Trailing newlines are stripped, matching command substitution behavior.
#
# · USAGE
#
#   readFile [-p] file resultVar
#
#   -p                     Preserve trailing newlines instead of stripping them.
#   file (string)          Path to the file to read.
#   resultVar (stringRef)  Name of variable to receive the file contents.

readFile() {
    local _readFilePreserve=0
    [[ $1 == -p ]] && { _readFilePreserve=1; shift; }
    local _readFilePath="$1"
    local -n _readFileRef=$2
    assertFile "${_readFilePath}"
    IFS= read -r -d '' _readFileRef < "${_readFilePath}" || true
    if (( ! _readFilePreserve )); then
        while [[ "${_readFileRef}" == *$'\n' ]]; do
            _readFileRef="${_readFileRef%$'\n'}"
        done
    fi
}

# ◇ Set a nameref variable to the realpath of a file, failing if the path is not a regular file.
#
# · ARGS
#
#   resultVar (stringRef)  Name of variable to receive the resolved file path.
#   filePath (string)      Path to the file (must exist and be a regular file).
#   description (string)   Label used in error messages.

setFileVar() {
    _setFileSystemVar "$1" "$2" "$3" false
}

# ◇ Set a nameref variable to the realpath of a directory, failing if the path is not a directory.
#
# · ARGS
#
#   resultVar (stringRef)  Name of variable to receive the resolved directory path.
#   dirPath (string)       Path to the directory (must exist and be a directory).
#   description (string)   Label used in error messages.

setDirVar() {
    _setFileSystemVar "$1" "$2" "$3" true
}


# ──────────────────────────────────────────────────────────────────────────────
# PROCESS & ENVIRONMENT FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

# ◇ Push a new value onto the IFS stack and set IFS to that value.
#   Use popIFS to restore the previous value.
#
# · ARGS
#
#   newIFS (string)  The new IFS value.
#
# · EXAMPLE
#
#   pushIFS $'\n'
#   for item in ${list}; do ...
#   popIFS

pushIFS() {
    [[ -v IFS ]] && _ifsStack+=("${IFS}") || _ifsStack+=("${_ifsUnset}")
    IFS="$1"
}

# ◇ Pop a previously pushed IFS value, restoring IFS to its prior state.
#
# · EXAMPLE
#
#   pushIFS $'\n'
#   popIFS

popIFS() {
    (( ${#_ifsStack[@]} )) || invalidArgs "IFS stack underflow"
    local saved="${_ifsStack[-1]}"
    unset '_ifsStack[-1]'
    [[ "${saved}" == "${_ifsUnset}" ]] && unset IFS || IFS="${saved}"
}

# ◇ Register a shell command to be executed at exit, in registration order.

addExitHandler() {
    _rayvnExitTasks+=("$1")
}

# ◇ Outputs the version string for a rayvn project, reading its rayvn.pkg file.
#
# · ARGS
#
#   projectName (string)  Name of the project (e.g. 'rayvn', 'valt').
#   verbose (string)      If non-empty, appends release date or "(development)" to output.

projectVersion() {
    local projectName="$1"
    local verbose="${2:-}"
    local -n projectHomeRef="${projectName//-/_}Home"
    local pkgFile="${projectHomeRef}/rayvn.pkg"
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

# ◇ Open a URL in the default browser (macOS: open, Linux: xdg-open).
#
# · ARGS
#
#   url (string)  The URL to open.

openUrl() {
    local url="$1"

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

# ◇ Execute a command with rayvn internal variables unset, simulating a clean environment.

executeClean() {
    env "${_unsetVars[@]}" "$@"
}

# ◇ Enable debug mode.
#
# · USAGE
#
#   setDebug [--tty TTY|.] [--noStatus] [--clearLog] [--showLogOnExit]
#
#   --tty TTY (string)  Log debug messages to the TTY instead of the log file.
#   --tty .             Log debug messages to the TTY read from "${HOME}/.debug.tty".
#   --noStatus          Suppress debug status line display.
#   --clearLog          Clear the log file if not tty mode.
#   --showLogOnExit     Show the log file on exit if not tty mode.

setDebug() {
    require 'rayvn/debug'
    _setDebug "$@"
}

# Placeholder debug functions; replaced by rayvn/debug when debug mode is enabled.
debug() { :; }
debugEnabled() { return 0; }
debugDir() { :; }
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

    # Ensure we are being invoked from rayvn.up

    if ! (( onMacOS || onLinux )); then
        echo -e "\033[0;31m🔺 Run 'source rayvn.up' to initialize rayvn\033[0m"; exit 1
    fi

    # Restrict file creation permissions to owner only

    umask 0077

    # IFS stack for pushIFS/popIFS

    declare -ga _ifsStack=()
    declare -gr _ifsUnset=$'\x01'

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
        declare -gr _hasUTF8=1
    else
        echo "Warning: UTF-8 locale not detected. Unicode may not render correctly." >&2
        declare -gr _hasUTF8=0
    fi

    # We need to set ${terminal} so that it can be used as a redirect.
    # Are stdout and stderr both terminals AND the NonInteractive flag is not set?

    if [[ -t 1 && -t 2 ]] && (( ! rayvnTest_NonInteractive )); then

        # Yes, so set terminal to the tty and remember that we are interactive

        declare -gr terminal="/dev/tty"
        declare -gr terminalErr="/dev/tty"
        declare -gri isInteractive=1

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
        declare -gri terminalColorBits=${bits}

    else

        # No. Discard terminal output in non-interactive mode.

        declare -gr terminal="/dev/null"
        declare -gr terminalErr="/dev/stderr"
        declare -gri isInteractive=0

        # Turn off colors unless the test flag is set

        if (( rayvnTest_Force24BitColor )); then
            declare -gri terminalColorBits=24
        else
            declare -gri terminalColorBits=0
        fi
    fi

    # Open a pre-allocated fd for terminal I/O to avoid per-write open/close overhead

    exec {ttyFd}<>"${terminal}"
    declare -gr ttyFd

    exec {stdinFd}<&0
    declare -gr stdinFd

    # Misc global vars and constants

    declare -gi _debug=0
    declare -gr _checkMark='✔' # U+2714 Check mark
    declare -gr _crossMark='✘' # U+2718 Heavy ballot X
    declare -gr _hexChars=( '0' '1' '2' '3' '4' '5' '6' '7' '8' '9' 'a' 'b' 'c' 'd' 'e' 'f' )
    declare -gar _headerColors=('bold' 'accent' 'secondary' 'warning' 'success' 'muted')
    declare -gr inContainer=${ [[ -f /.dockerenv || -f /run/.containerenv ]] && echo 1 || echo 0; }
    declare -gr inNix=${ [[ ${rayvnHome} == /nix/store/* ]] && echo 1 || echo 0; }

    # Detect the best available RAM-backed temp storage strategy.
    # linux_shm:   /dev/shm (tmpfs, standard on Linux)
    # macos_tmpfs: user-mounted tmpfs (mount_tmpfs, macOS 10.15+)
    # secure_temp: regular mktemp with mode 600 (fallback)

    local _shmBase
    if (( onLinux )) && [[ -d /dev/shm && -w /dev/shm ]]; then
        declare -gr _secureTempStrategy='linux_shm'
        declare -gr _secureTempBase='/dev/shm'
    elif (( onMacOS )); then
        _shmBase="${RAYVN_SHM_PATH:-/private/var/rayvn-shm-${UID}}"
        if [[ -d "${_shmBase}" ]] && mount | grep -q " on ${_shmBase} (tmpfs"; then
            declare -gr _secureTempStrategy='macos_tmpfs'
            declare -gr _secureTempBase="${_shmBase}"
        else
            declare -gr _secureTempStrategy='secure_temp'
            declare -gr _secureTempBase=''
        fi
    else
        declare -gr _secureTempStrategy='secure_temp'
        declare -gr _secureTempBase=''
    fi

    # Ensure system and rayvn config dirs set to valid directories

    declare -gr _systemConfigDir="${HOME}/.config"
    declare -gr _rayvnConfigDir="${_systemConfigDir}/rayvn"
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

    # Create success check mark and error cross mark

    declare -gr successCheckMark="${ show success ${_checkMark}; }"
    declare -gr errorCrossMark="${ show error ${_crossMark}; }"

    # Force these functions readonly since we have to handle them specially in rayvn.up

    (( _rayvnReadOnlyFunctions )) && declare -fr fail printStack

    # Collect the names of all existing lowercase and underscore prefixed vars if we have not already done so.
    # This allows executeWithCleanVars to exclude all vars set by rayvn.up and core, which ensures that those
    # run as if started from the command line. Manually add vars that are created lazily after init.

    local var unsetVars=('-u' '_rayvnCoreInitialized' '-u' '_rayvnTempDir' '-u' 'rayvnIsUp' '-u' '_rayvnGlobalMaps' '-u' '_unsetChildVars')
    while IFS= read -r var; do
        unsetVars+=("-u")
        unsetVars+=("${var}")
    done < <(compgen -v | grep -E '^([a-z]|_[^_])')
    declare -ga _unsetVars=("${unsetVars[@]}")

    # Remove our init helper functions. The current function will be removed by rayvn.up

    unset _init_theme _init_colors _init_noColors

    # Since maps (associative arrays) cannot be exported to child processes, save them so we
    # can restore in children.

    exportGlobalMaps _textFormats

    # Remember that we've completed this initialization

    declare -gr _rayvnCoreInitialized=1
}

_init_theme() {
    declare -gr _themeConfigFile="${_rayvnConfigDir}/current.theme"
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

    declare -gr _currentThemeIndex=${index}
}

_init_colors() {
    _init_theme
    declare -gr _textReset=$'\e[0m'
    declare -grA _textFormats=(

       # Styles

        ['bold']=$'\e[1m'
        ['dim']=$'\e[2m'
        ['italic']=$'\e[3m'
        ['underline']=$'\e[4m'
        ['blink']=$'\e[5m'
        ['reverse']=$'\e[7m'
        ['strikethrough']=$'\e[9m' # often not supported!

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

        # Special formats

        ['nl']=$'\n'
    )
}

_init_noColors() {
    declare -gr _textReset=''
    declare -grA _textFormats=(

        # Styles

        ['bold']=''
        ['dim']=''
        ['italic']=''
        ['underline']=''
        ['blink']=''
        ['reverse']=''
        ['strikethrough']=''

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

        # Special formats

        ['nl']=$'\n'
    )
}

_setFileSystemVar() {
    local -n resultVarRef="$1"
    local file="$2"
    local description="$3"
    local isDir="$4"

    [[ ${file} ]] || fail "${description} path is required"
    [[ -e ${file} ]] || fail "${file} not found"
    if [[ ${isDir} == true ]]; then
        [[ -d ${file} ]] || fail "${file} is not a directory"
    else
        [[ -f ${file} ]] || fail "${file} is not a file"
    fi
    local realFile="${ realpath "${file}" 2>/dev/null; }"
    resultVarRef="${realFile}"
}

_ensureRayvnTempDir() {
    if [[ ! -n ${_rayvnTempDir} ]]; then
        local dir
        if [[ -n "${_secureTempBase}" ]]; then
            dir="${ withUmask 0077 mktemp -d "${_secureTempBase}/rayvn-XXXXXX"; }" || fail "could not create temp directory in ${_secureTempBase}"
        else
            dir="${ withUmask 0077 mktemp -d; }" || fail "could not create temp directory"
        fi
        declare -gr _rayvnTempDir="${dir}"
        declare -gr _rayvnTempDirOwner=${BASHPID}
        chmod 700 "${_rayvnTempDir}" || fail "chmod failed on temp dir"
    fi
}

_restoreTerminal() {
    if (( isInteractive )); then
        stty sane &> /dev/null
        printf '\e[0K\e[?25h' >&${ttyFd} # Clear to end of line and show cursor in case sane does not
    fi
}

_onRayvnTerm() {
    _restoreTerminal
    _rayvnExitMessage="${ show italic red "🔺 killed" ;}"
    exit 1
}

_onRayvnHup() {
    _restoreTerminal
    _rayvnExitMessage="${ show italic red "🔺 killed (SIGHUP)" ;}"
    exit 1
}

_onRayvnInt() {
    _restoreTerminal
    [[ -v rayvnNoExitOnCtrlC ]] && return
    _rayvnExitMessage="${ show italic red "🔺 exiting (ctrl-c)" ;}"
    exit 1
}

_onRayvnExit() {
    _restoreTerminal

    # Run any added tasks first (they may reposition the cursor and need the temp dir)

    for task in "${_rayvnExitTasks[@]}"; do
        eval "${task}"
    done

    # Add a line and any deferred signal message after exit tasks have repositioned the cursor

    (( rayvnTest_NoEchoOnExit )) || echo
    [[ -v _rayvnExitMessage ]] && echo "${_rayvnExitMessage}"

    # Delete temp dir if we created it

    if [[ ${_rayvnTempDir} ]] && (( BASHPID == _rayvnTempDirOwner )); then
        rm -rf -- "${_rayvnTempDir}" &>/dev/null
    fi
}
