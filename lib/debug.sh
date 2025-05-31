#!/usr/bin/env bash

# Library supporting debug logging.
# Intended for use via: require 'rayvn/debug'

require 'rayvn/core'

# IMPORTANT!
#
# Each of the following public functions MUST have a corresponding NO-OP declaration
# within core. If you add a new function here, add a NO-OP at the bottom of core.sh

debug() {
    (( _debug )) && echo "${@}" >&3; return 0
}

debugDir() {
    (( _debug )) && echo "${_debugDir}"; return 0
}

debugStatus() {
    if (( _debug )); then
        if [[ ${_debugOut} == log ]]; then
            local show=
            [[ ${_showLogOnExit} ]] && show=" $(ansi dim [show on exit])"
            echo "$(ansi italic_cyan debug enabled) -> $(ansi blue "${_debugLogFile}")${show}"
        else
            echo "$(ansi italic_cyan debug enabled) -> terminal"
        fi
    fi
}

debugVars() {
    (( _debug )) && declare -p "${@}" >&3 2> /dev/null; return 0
}

debugVarIsSet() {
    if (( _debug )); then
        local var="${1}"
        local prefix="${2}"
        [[ ${prefix} ]] && prefix="$(ansi cyan ${prefix} and) "
        (
            echo -n "${prefix}$(ansi blue expect \'${var}\' is set -\>) "
            if _varIsSet ${var}; then
                declare -p ${var}
            else
                echo "$(ansi red NOT SET!)"
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
        [[ ${prefix} ]] && prefix="$(ansi cyan ${prefix} and) "
        (
            local var="${1}"
            echo -n "${prefix}$(ansi blue expect \'${var}\' is not set -\>) "
            if _varIsSet ${var}; then
                echo "$(ansi red=${!var})"
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
        debug "Wrote ${fileName} to ${destFile}"
    fi
}

## private data and functions ----------------------------------------

declare -gx _debugOut=log
declare -gx _showLogOnExit=false

_setDebug() {
    local clearLog=false
    local status=true

    _debug=1

    while (( ${#} > 0 )); do
        case "${1}" in
            noLog) _debugOut=terminal ;;
            showOnExit) _showLogOnExit=true ;;
            clearLog) clearLog=true ;;
            noStatus) status=false ;;
            *) fail "Unknown setDebug() option: ${1}" ;;
        esac
        shift
    done

    if [[ ${_debugOut} == terminal ]]; then
        exec 3>> "${terminal}"
    else
        _prepareLogFile "${clearLog}"
    fi

    addExitHandler _debugExit

    [[ ${status} == true ]] && debugStatus
}

_varIsSet() {
    declare -p "${1}" &> /dev/null
}

_prepareLogFile() {
    local clearLog="${1}" configDir
    configDir="$(configDirPath)" || fail
    declare -grx _debugDir="${configDir}/debug"
    declare -grx _debugLogFile="${_debugDir}/debug.log"
    declare -gxi _debugStartLine

    if [[ ! -e ${_debugDir} ]]; then
        mkdir -p "${_debugDir}" || fail
    fi

    if [[ -e "${_debugLogFile}" ]]; then
        if [[ ${clearLog} == true ]]; then
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
    [[ ${_showLogOnExit} == true ]] && _printDebugLog
}

_printDebugLog() {
    local startLine
    declare -i endLine

    # did we log anything?

    endLine=$(wc -l < "${_debugLogFile}")
    if  (( endLine - _debugStartLine > 2 )); then

        # yes, so dump what we added
        {
            local closing
            if (( _debugStartLine > 1 )); then
                closing="$(ansi italic \(skipped ${_debugStartLine} preexisting lines in \'${_debugLogFile}\'))\n"
            fi
            echo

            # print start line in color

            (( _debugStartLine++ ))
            startLine="$(tail -n +${_debugStartLine} "${_debugLogFile}" | head -n 1)"
            echo "$(ansi bold_blue ${startLine})"

            # print remaining lines

            (( _debugStartLine++ ))
            tail -n +${_debugStartLine} "${_debugLogFile}" #| head -n 1

            # print a closing line

            echo "$(ansi bold_blue ____________________________________________________________________________)"
            printf "${closing}\n"
        } > ${terminal}
    fi
}
