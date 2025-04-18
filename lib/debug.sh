#!/usr/bin/env bash

# Library supporting debug logging.
# Intended for use via: require 'rayvn/debug'

require 'rayvn/core'

setDebug() {
    declare -grx _debug=true
    declare -gx _debugOut=log
    declare -gx _showLogOnExit=false
    local clearLog=false
    local status=true

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

_prepareLogFile() {
    local clearLog="${1}"
    declare -grx _debugDir="${HOME}/.rayvn"
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

debugStatus() {
    if [[ ${_debug} ]]; then
        if [[ ${_debugOut} == log ]]; then
            local show=
            [[ ${_showLogOnExit} ]] && show=" $(ansi dim [show on exit])"
            echo "$(ansi italic_cyan debug enabled) -> $(ansi blue ${_debugLogFile})${show}"
        else
            echo "$(ansi italic_cyan debug enabled) -> terminal"
        fi
    fi
}

debug() {
    [[ ${_debug} ]] && echo "${@}" >&3
}

debugVars() {
    if [[ ${_debug} ]]; then
        declare -p "${@}" >&3
    fi
}

debugFile() {
    if [[ ${_debug} ]]; then
        local sourceFile="${1}"
        local fileName="${2:-$(baseName ${sourceFile})}"
        local destFile="${_debugDir}/${fileName}"
        cp "${sourceFile}" "${destFile}"
        debug "Added file ${destFile}"
    fi
}

debugJson() {
    if [[ ${_debug} ]]; then
        local -n json="${1}"
        local fileName="${2}"
        local destFile="${_debugDir}/${fileName}.json"
        debug "created ${destFile}"
        echo "${json}" > "${destFile}"
    fi
}

debugEnvironment() {
    if [[ ${_debug} ]]; then
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

