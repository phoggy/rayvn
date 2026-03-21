#!/usr/bin/env bash

# Debug logging.
# Use via: require 'rayvn/debug'

# IMPORTANT!
#
# Each of the following public functions MUST have a corresponding NO-OP declaration
# within core. If you add a new function here:
#
#    1. add it to the list in _init_rayvn_debug below
#    2. add a NO-OP function at the bottom of core.sh
#    3. add it to _rayvnFunctionSources in rayvn.up

# ◇ Return 0 if debug mode is enabled, non-zero otherwise.

isDebugEnabled() {
    return ${_debug}
}

# ◇ Log args. No-op if debug is not enabled.

debug() {
    (( _debug )) && _debugEcho "${@}" >&${_debugFd}; return 0
}

# ◇ Log the debug output directory path to debug output. No-op if debug is not enabled.

debugDir() {
    (( _debug )) && _debugEcho "${_debugDir}"; return 0
}

# ◇ Log a binary string as hex bytes. No-op if debug is not enabled.
#
# · ARGS
#
#   label (string)   Label logged before the hex bytes.
#   binary (string)  Binary string to display as hex.

debugBinary() {
    if (( _debug )); then
        local label="${1}"
        local binary="${2}"
        _debugEchoNoNewline "${label}"
        for (( i=0; i < ${#binary}; i++ )); do
            printf '%02X ' "'${binary:i:1}" >&${_debugFd}
        done
        echo >&${_debugFd}
    fi
}

# ◇ Log variable declaration(s). Convenience alias for debugVars. No-op if debug is not enabled.

debugVar() {
    debugVars "${@}"
}

# ◇ Log declarations of one or more variables. No-op if debug is not enabled.
#
# · ARGS
#
#   varName (stringRef)  Name of a variable to inspect; outputs "not defined" if undefined.

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

# ◇ Assert and log that a variable is set, logging a stack trace if not. No-op if debug is not enabled.
#
# · ARGS
#
#   varName (stringRef)  Name of the variable expected to be set.
#   prefix (string)      Optional label prepended to the assertion message.

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

# ◇ Assert and log that a variable is not set, logging a stack trace if it is. No-op if debug is not enabled.
#
# · ARGS
#
#   var (stringRef)  Name of the variable expected to be unset.
#   prefix (string)  Optional label prepended to the assertion message.

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

# ◇ Copy a file into the debug directory.
#
# · ARGS
#
#   sourceFile (string)  Path to the source file.
#   fileName (string)    Optional filename (default: basename of sourceFile).

debugFile() {
    if (( _debug )); then
        local sourceFile="${1}"
        local fileName="${2:-${ baseName ${sourceFile}; }}"
        local destFile="${_debugDir}/${fileName}"
        cp "${sourceFile}" "${destFile}"
        debug "Added file ${destFile}"
    fi
}

# ◇ Write a variable's JSON content as a file in the debug directory. No-op if debug is not enabled.
#
# · ARGS
#
#   jsonRef (stringRef)  Name of the variable holding the JSON string.
#   fileName (string)    Base name for the output file.

debugJson() {
    if (( _debug )); then
        local -n json="${1}"
        local fileName="${2}"
        local destFile="${_debugDir}/${fileName}.json"
        debug "created ${destFile}"
        echo "${json}" | jq > "${destFile}"
    fi
}

# ◇ Log a stack trace if enabled, with an optional message to log first. No-op if debug is not enabled.

debugStack() {
    if (( _debug )); then
        _debugEcho
        stackTrace "${@}" >&${_debugFd}
    fi
}

# ◇ Enable bash xtrace (set -x), directing output to the debug stream, with an optional message to log first.

debugTraceOn() {
    (( $# )) && debug "${@}"
    debug "${ show secondary "BEGIN CODE TRACE ----------------------------------"; }"
    exec {_debugTraceFd}>> "${_debugOut}"
    export BASH_XTRACEFD=${_debugTraceFd}
    set -x
}

# ◇ Disable bash xtrace (set +x) previously enabled by debugTraceOn, optionally logging a message afterward.
#   No-op if debug is not enabled.

debugTraceOff() {
    set +x
    unset BASH_XTRACEFD
    exec {_debugTraceFd}>&-
    unset _debugTraceFd
    debug "${ show secondary "END CODE TRACE ------------------------------------"; }"
    (( $# )) && debug "${@}"
}

# ◇ Log each argument shell-quoted via 'printf %q'. No-op if debug is not enabled.

debugEscapes() {
    (( _debug )) && printf '%q ' "${@}"
}

# ◇ Log the full process environment (variables and functions) to '<name>.env' in the debug directory.
#   No-op if debug is not enabled.
#
# · ARGS
#
#   name (string)  Base name for the output file.

debugEnvironment() {  # TODO: replace with full snapshot
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

# ◇ Log the open/closed status and mode of one or more file descriptors. No-op if debug is not enabled.
#
# · ARGS
#
#   fd | string  Numeric fd or nameref variable holding an fd; repeatable.

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
        declare -rf debug debugEnabled debugDir debugBinary debugVars debugVarIsSet debugVarIsNotSet \
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
            showLogOnExit) _debugShowLogOnExit=1 ;;
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
            show -e bold green "BEGIN" primary "debug output from ${currentProjectName}, pid ${BASHPID} ----------------------------------\r\n"  > ${_debugOut}
        fi
    else
        _prepareLogFile ${clearLog}
    fi

    addExitHandler _debugExit

    (( status )) && _debugStatus
}

_debugStatus() {
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
    { echo "${prefix} ${suffix}"; echo; } > ${terminal}
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
        show -e bold green "\r\nEND" primary "  debug output from ${currentProjectName}, pid ${BASHPID} ----------------------------------\r\n"  > ${_debugOut}
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
