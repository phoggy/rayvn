#!/usr/bin/env bash

# Library supporting debug logging.
# Intended for use via: require 'rayvn/debug'

require 'rayvn/core'

init_rayvn_debug() {
    declare -grx _debug=true
    declare -grx _debugDir="${HOME}/.rayvn"
    declare -grx _debugLogFile="${_debugDir}/debug.log"
    declare -gxi _debugStartLine

    if [[ ! -e ${_debugDir} ]]; then
        mkdir -p "${_debugDir}" || fail
    fi

    if [[ -e "${_debugLogFile}" ]]; then
        echo >> "${_debugLogFile}"
    fi

    _debugStartLine=$(wc -l < "${_debugLogFile}")

    exec 3>> "${_debugLogFile}"
    addExitHandler _debugExit

    printf "___ rayvn log $(date) _________________________________\n\n" >&3
}

_debugExit() {
    exec 3>&- # close it

    local startLine
    declare -i endLine

    # did we log anything?

    endLine=$(wc -l < "${_debugLogFile}")
    if  (( endLine - _debugStartLine > 2 )); then

        # yes, so dump what we added
        {
            local closing
            if (( _debugStartLine > 0 )); then
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
    [[ ${_debug} ]] && echo "Debug enabled, log at $(ansi blue ${_debugLogFile}) ${_greenCheckMark}"
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
