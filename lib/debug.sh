#!/usr/bin/env bash

# Library supporting debug logging.
# Intended for use via: require 'rayvn/debug'

# IMPORTANT!
#
# Each of the following public functions MUST have a corresponding NO-OP declaration
# within core. If you add a new function here:
#
#    1. add it to the list in _init_rayvn_debug below
#    2. add a NO-OP function at the bottom of core.sh
#    3. add it to _rayvnFunctionSources in rayvn.up

# Write a message to debug output if debug mode is enabled. No-op otherwise.
# Args: message [args...]
#
#   message - text to write; additional args are appended space-separated
debug() {
    (( _debug )) && _debugEcho "${@}" >&${_debugFd}; return 0
}

# Return 0 if debug mode is currently enabled, 1 otherwise.
debugEnabled() {
    return ${_debug}
}

# Write the path to the debug output directory to debug output if debug mode is enabled.
debugDir() {
    (( _debug )) && _debugEcho "${_debugDir}"; return 0
}

# Print the current debug configuration (log file path or output target) if debug is enabled.
debugStatus() {
    if (( _debug )); then
        local prefix=
        local suffix=
        prefix="${ show accent italic 'debug ⮕ '; }"
        if [[ -n ${_debugLogFile} ]]; then
            local show=
            [[ ${_debugShowLogOnExit} ]] && show=" ${ show dim "[show on exit]"; }"
            suffix="${ show bold blue "${_debugLogFile}" ;}${show}"
        elif [[ ${_debugOut} == "${terminal}" ]]; then
            suffix="${ show bold blue "terminal"; }"
        else
            suffix="${ show bold blue "${_debugOut}"; }"
        fi
        echo "${prefix} ${suffix}"
        echo
    fi
}

# Write a binary string as hex bytes to debug output if debug mode is enabled.
# Args: prompt binary
#
#   prompt - label printed before the hex bytes
#   binary - the binary string to display as hex
debugBinary() {
    if (( _debug )); then
        local prompt="${1}"
        local binary="${2}"
        _debugEchoNoNewline "${prompt}"
        for (( i=0; i < ${#binary}; i++ )); do
            printf '%02X ' "'${binary:i:1}" >&${_debugFd}
        done
        echo >&${_debugFd}
    fi
}

# Write the declaration of a single variable to debug output if debug mode is enabled.
# Args: varName
#
#   varName - name of the variable to inspect
debugVar() {
    debugVars "${@}"
}

# Write the declarations of one or more variables to debug output if debug mode is enabled.
# Args: varName [varName...]
#
#   varName - name of a variable to inspect; reports "not defined" if undefined
debugVars() {
    if (( _debug )); then
        local line
        while (( $# )); do
            line="${ declare -p "${1}" 2> /dev/null; }"
            [[ -n "${line}" ]] && _debugEcho "${line}" || _debugEcho "${1} not defined"
            shift
        done
    fi
    return 0
}

# Assert and log that a variable is set; prints a stack trace to debug output if it is not.
# Args: varName [prefix]
#
#   varName - name of the variable expected to be set
#   prefix  - optional label to prepend to the assertion message
debugVarIsSet() {
    if (( _debug )); then
        local var="${1}"
        local prefix="${2}"
        [[ ${prefix} ]] && prefix="${ show accent "${prefix} and" ;} "
        (
            _debugEchoNoNewline "${prefix}${ show primary "expect '${var}' is set ->" ;} "
            if varIsDefined ${var}; then
                declare -p ${var}
            else
                show red "NOT SET!"
                stackTrace
                echo
            fi
        ) >&${_debugFd}
    fi
}

# Assert and log that a variable is NOT set; prints a stack trace to debug output if it is.
# Args: varName [prefix]
#
#   varName - name of the variable expected to be unset
#   prefix  - optional label to prepend to the assertion message
debugVarIsNotSet() {
    if (( _debug )); then
        local var="${1}"
        local prefix="${2}"
        [[ ${prefix} ]] && prefix="${ show accent "${prefix} and" ;} "
        (
            local var="${1}"
            _debugEchoNoNewline "${prefix}${ show primary "expect '${var}' is not set ->" ;} "
            if varIsDefined ${var}; then
                show red "=${!var}"
                stackTrace
                echo
            else
                echo "not set"
            fi
        ) >&${_debugFd}
    fi
}

# Copy a file into the debug directory for inspection, if debug mode is enabled.
# Args: sourceFile [fileName]
#
#   sourceFile - path to the file to copy
#   fileName   - optional name for the copy in the debug directory (default: basename of sourceFile)
debugFile() {
    if (( _debug )); then
        local sourceFile="${1}"
        local fileName="${2:-${ baseName ${sourceFile}; }}"
        local destFile="${_debugDir}/${fileName}"
        cp "${sourceFile}" "${destFile}"
        debug "Added file ${destFile}"
    fi
}

# Write the contents of a variable as a JSON file in the debug directory, if debug is enabled.
# Args: jsonVar fileName
#
#   jsonVar  - name of the variable holding the JSON content
#   fileName - base name for the output file (written as fileName.json in the debug directory)
debugJson() {
    if (( _debug )); then
        local -n json="${1}"
        local fileName="${2}"
        local destFile="${_debugDir}/${fileName}.json"
        debug "created ${destFile}"
        echo "${json}" > "${destFile}"
    fi
}

# Write a stack trace to debug output if debug mode is enabled.
# Args: [message [args...]]
#
#   message - optional message to include before the stack trace
debugStack() {
    if (( _debug )); then
        _debugEcho
        stackTrace "${@}" >&${_debugFd}
    fi
}

# Enable bash xtrace (set -x) with output directed to debug output.
# Args: [message [args...]]
#
#   message - optional message to log before enabling the trace
debugTraceOn() {
    (( $# )) && debug "${@}"
    debug "${ show secondary "BEGIN CODE TRACE ----------------------------------"; }"
    exec {_debugTraceFd}>> "${_debugOut}"
    export BASH_XTRACEFD=${_debugTraceFd}
    set -x
}

# Disable bash xtrace (set +x) previously enabled by debugTraceOn.
# Args: [message [args...]]
#
#   message - optional message to log after disabling the trace
debugTraceOff() {
    set +x
    unset BASH_XTRACEFD
    exec {_debugTraceFd}>&-
    unset _debugTraceFd
    debug "${ show secondary "END CODE TRACE ------------------------------------"; }"
    (( $# )) && debug "${@}"
}

# Print each argument in its shell-quoted (printf %q) form to debug output if debug is enabled.
# Args: value [value...]
#
#   value - one or more values to print in quoted form
debugEscapes() {
    (( _debug )) && printf '%q ' "${@}"
}

# Write the complete process environment (variables and functions) to a file in the debug directory.
# Args: fileName
#
#   fileName - base name for the output file (written as fileName.env in the debug directory)
debugEnvironment() {
    if (( _debug )); then
        local fileName="${1}.env"
        local destFile="${_debugDir}/${fileName}"
        (
            printf "%s\n\n" '--- VARIABLES --------------'
            declare -p
            printf "\n\n%s\n\n" '--- FUNCTIONS ---------------'
            declare -f
        ) > "${destFile}"
        debug "Wrote process environment to ${destFile}"
    fi
}

# Log the open/closed status and mode of one or more file descriptors to debug output.
# Args: fdVar [fdVar...]
#
#   fdVar - either a numeric fd number, or the name of a variable that holds an fd number
debugFileDescriptors() {
    (( _debug )) || return 0
    while (( $# )); do
        local fd description status mode
        if [[ $1 =~ ^[0-9]+$ ]]; then
            fd=$1
            description="fd ${fd} (pid ${BASHPID})"
        else
            local -n fileDescriptor="$1"
            fd=${fileDescriptor}
            description="fd ${fd} in $1 (pid ${BASHPID})"
        fi

        mode=${ lsof -a -p ${BASHPID} -d ${fd} -F a 2>/dev/null; }
        mode=${ echo ${mode} | cut -d' ' -f3; }

        if [[ -z "${mode}" ]]; then
            status="not open"
        elif [[ "${mode}" =~ u ]]; then
            status="open read-write"
        elif [[ "${mode}" =~ r ]]; then
            status="open read-only"
        elif [[ "${mode}" =~ w ]]; then
            status="open write-only"
        else
            status="open but not readable or writable"
        fi
        debug "${description} is ${status}"
        shift
    done
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/debug' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_debug() {

    # Make our public functions readonly since rayvn.up treats these as a special case.

    if (( _rayvnReadOnlyFunctions )); then
        declare -rf debug debugEnabled debugDir debugStatus debugBinary debugVars debugVarIsSet debugVarIsNotSet \
                    debugFile debugJson debugStack debugTraceOn debugTraceOff debugEscapes debugEnvironment \
                    debugFileDescriptors
    fi

    declare -gx _debug=0
    declare -gx _debugFd=
    declare -gx _debugOut=
    declare -gx _debugPrefix=
    declare -gx _debugShowLogOnExit=0
    declare -gx _debugRemote=0
}

_debugEcho() {
    if (( _debugRemote )); then
        printf '%s\r\n' "${_debugPrefix}${*}" >&${_debugFd}
    else
        echo "${_debugPrefix}${*}" >&${_debugFd}
    fi
}

_debugEchoNoNewline() {
    echo -n "${_debugPrefix}${*}" >&${_debugFd}
}

_setDebug() {
    (( _debug )) && {
        debug '_setDebug(), but called previously.'
        stackTrace
        return 0
    }

    local clearLog=0
    local status=1

    _debug=1

    while (( ${#} > 0 )); do
        case "${1}" in
            tty) shift; _debugOut="${1}";;
            showOnExit) _debugShowLogOnExit=1 ;;
            clearLog) clearLog=1 ;;
            noStatus) status=0 ;;
            *) fail "Unknown setDebug() option: ${1}" ;;
        esac
        shift
    done

    if [[ ${_debugOut} == '.' ]]; then
        local ttyFile
        ttyFile="${HOME}/.debug.tty"
        assertFileExists "${ttyFile}"
        _debugOut="${ cat "${ttyFile}"; }"
    fi

    if [[ -n ${_debugOut} ]]; then
        exec {_debugFd}>> "${_debugOut}"
        if ((isInteractive)); then
            _debugPrefix="${ show accent 'debug: ';}"
        else
            _debugPrefix="debug: "
        fi

        if [[ ${_debugOut} != "${terminal}" && ${_debugOut} =~ tty ]]; then
            _debugRemote=1
            clear >&${_debugFd} # clear remote terminal
            show -e bold green "BEGIN" primary "debug output from pid ${BASHPID} ----------------------------------\r\n"  > ${_debugOut}
        fi
    else
        _prepareLogFile ${clearLog}
    fi

    addExitHandler _debugExit

    (( status )) && debugStatus
}

_prepareLogFile() {
    local clearLog=${1}
    declare -grx _debugDir="${_rayvnConfigDir}/debug"
    declare -grx _debugLogFile="${_debugDir}/debug.log"
    declare -gxi _debugStartLine

    if [[ ! -e ${_debugDir} ]]; then
        mkdir -p "${_debugDir}" || fail
    fi

    if [[ -e "${_debugLogFile}" ]]; then
        if (( clearLog )); then
            echo > "${_debugLogFile}"
        else
            echo >> "${_debugLogFile}"
        fi
    else
        touch "${_debugLogFile}"
    fi

    _debugStartLine=${ wc -l < "${_debugLogFile}"; }

    exec {_debugFd}>> "${_debugLogFile}"

    printf "___ rayvn log ${ date; } _________________________________\n\n" >&${_debugFd}
}

_debugExit() {
    exec {_debugFd}>&- # close it
    (( _debugShowLogOnExit )) && _printDebugLog
    if (( _debugRemote )); then
        show -e bold green "\r\nEND" primary "debug output from pid ${BASHPID} ----------------------------------\r\n"  > ${_debugOut}
    fi
}

_printDebugLog() {
    local startLine
    local endLine

    # did we log anything?

    endLine=${ wc -l < "${_debugLogFile}"; }
    if  (( endLine - _debugStartLine > 2 )); then

        # yes, so dump what we added
        {
            local closing
            if (( _debugStartLine > 1 )); then
                closing="${ show italic "(skipped ${_debugStartLine} preexisting lines in '${_debugLogFile}')" ;}\n"
            fi
            echo

            # print start line in color

            (( _debugStartLine++ ))
            startLine="${ tail -n +${_debugStartLine} "${_debugLogFile}" | head -n 1; }"
            show bold primary "${startLine}"

            # print remaining lines

            (( _debugStartLine++ ))
            tail -n +${_debugStartLine} "${_debugLogFile}" #| head -n 1

            # print a closing line

            show bold primary "____________________________________________________________________________"
            printf "${closing}\n"
        }
    fi
}
