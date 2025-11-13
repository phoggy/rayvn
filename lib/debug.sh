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

debug() {
    (( _debug )) && _debugEcho "${@}" >&3; return 0
}

debugEnabled() {
    (( _debug )) && return 0 || return 1
}

debugDir() {
    (( _debug )) && _debugEcho "${_debugDir}"; return 0
}

debugStatus() {
    if (( _debug )); then
        local prefix=
        local suffix=
        prefix="${ show "${_debugPrefixColor}" italic 'debug ⮕ '; }"
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

debugBinary() {
    if (( _debug )); then
        local prompt="${1}"
        local binary="${2}"
        _debugEchoNoNewline "${prompt}"
        for (( i=0; i < ${#binary}; i++ )); do
            printf '%02X ' "'${binary:i:1}" >&3
        done
        echo >&3
    fi
}

debugVar() {
    if (( _debug )); then
        _debugEchoNoNewline
        declare -p "${@}" >&3 2> /dev/null;
    fi
    return 0
}

debugVarIsSet() {
    if (( _debug )); then
        local var="${1}"
        local prefix="${2}"
        [[ ${prefix} ]] && prefix="${ show cyan "${prefix} and" ;} "
        (
            _debugEchoNoNewline "${prefix}${ show blue "expect '${var}' is set ->" ;} "
            if _varIsSet ${var}; then
                declare -p ${var}
            else
                show red "NOT SET!"
                printStack
                echo
            fi
        ) >&3
    fi
}

debugVarIsNotSet() {
    if (( _debug )); then
        local var="${1}"
        local prefix="${2}"
        [[ ${prefix} ]] && prefix="${ show cyan "${prefix} and" ;} "
        (
            local var="${1}"
            _debugEchoNoNewline "${prefix}${ show blue "expect '${var}' is not set ->" ;} "
            if _varIsSet ${var}; then
                show red "=${!var}"
                printStack
                echo
            else
                echo "not set"
            fi
        ) >&3
    fi
}

debugFile() {
    if (( _debug )); then
        local sourceFile="${1}"
        local fileName="${2:-$(baseName ${sourceFile})}"
        local destFile="${_debugDir}/${fileName}"
        cp "${sourceFile}" "${destFile}"
        debug "Added file ${destFile}"
    fi
}

debugJson() {
    if (( _debug )); then
        local -n json="${1}"
        local fileName="${2}"
        local destFile="${_debugDir}/${fileName}.json"
        debug "created ${destFile}"
        echo "${json}" > "${destFile}"
    fi
}

debugStack() {
    if (( _debug )); then
        _debugEcho
        printStack >&3
    fi
}

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

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/debug' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

declare -gx _debugOut=
declare -gx _debugPrefix=
declare -gx _debugShowLogOnExit=0
declare -gx _debugPrefixColor="magenta"
declare -gx _debugRemote=0

_init_rayvn_debug() {

    # Make our public functions readonly since rayvn.up treats these as a special case.

    declare -rf debug debugEnabled debugDir debugStatus debugBinary debugVar debugVarIsSet debugVarIsNotSet \
                debugFile debugJson debugStack debugEnvironment
}

_debugEcho() {
    echo "${_debugPrefix}${*}" >&3
}

_debugEchoNoNewline() {
    echo -n "${_debugPrefix}${*}" >&3
}

_setDebug() {
    (( _debug)) && {
        debug '_setDebug(), but called previously.'
        printStack
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

    if [[ -n ${_debugOut} ]]; then
        exec 3>> "${_debugOut}"
        if ((inTerminal)); then
            _debugPrefix="${ show ${_debugPrefixColor} 'debug: ';}"
        else
            _debugPrefix="debug: "
        fi

        if [[ ${_debugOut} != "${terminal}" && ${_debugOut} =~ tty ]]; then
            _debugRemote=1
            echo -n $'\e[2J\e[H' > ${_debugOut} # clear remote terminal
            show -e bold green "BEGIN" blue "debug output from pid ${BASHPID} ----------------------------------\n"  > ${_debugOut}
        fi
    else
        _prepareLogFile ${clearLog}
    fi

    addExitHandler _debugExit

    (( status )) && debugStatus
}

_varIsSet() {
    declare -p "${1}" &> /dev/null
}

_prepareLogFile() {
    local clearLog=${1}
    configDir="$(configDirPath)" || fail
    declare -grx _debugDir="${configDir}/debug"
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

    _debugStartLine=$(wc -l < "${_debugLogFile}")

    exec 3>> "${_debugLogFile}"

    printf "___ rayvn log $(date) _________________________________\n\n" >&3
}

_debugExit() {
    exec 3>&- # close it
    (( _debugShowLogOnExit )) && _printDebugLog
    if (( _debugRemote )); then
        show -e bold green "\nEND   " blue "debug output from pid ${BASHPID} ----------------------------------\n"  > ${_debugOut}
    fi
}

_printDebugLog() {
    local startLine
    local endLine

    # did we log anything?

    endLine=$(wc -l < "${_debugLogFile}")
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
            startLine="$(tail -n +${_debugStartLine} "${_debugLogFile}" | head -n 1)"
            show bold blue "${startLine}"

            # print remaining lines

            (( _debugStartLine++ ))
            tail -n +${_debugStartLine} "${_debugLogFile}" #| head -n 1

            # print a closing line

            show bold blue "____________________________________________________________________________"
            printf "${closing}\n"
        }
    fi
}
