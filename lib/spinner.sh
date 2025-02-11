#!/usr/bin/env bash
# shellcheck disable=SC2120,SC2155

# Library supporting progress spinner
# Intended for use via: require 'core/spinner'

require 'core/base'

init_core_spinner() {
    configureSpinner
}

declare -grx spinnerDefaultChars='◞◜◝◟◞◜◝◟◞◜◝◟'
declare -grx spinnerDefaultCharsColor='bold_blue'
declare -grx spinnerCommandPrefix="::"
declare -grx spinnerEraseCommand="${spinnerCommandPrefix}eraseSpinner"
declare -grx spinnerEraseLineCommand="${spinnerCommandPrefix}eraseLine"

declare -ga spinnerArray=
declare -g spinnerArraySize=
declare -g spinnerMaxIndex=
declare -g spinnerIndex=
declare -g spinnerForward=
declare -g spinnerPid=
declare -g spinnerCleanupRegistered

startSpinner() {
    if [[ ! ${spinnerPid} ]]; then
        _ensureStopOnExit
        _spinServerMain "${1}" &
        spinnerPid=${!}
    fi
}

stopSpinnerAndEraseLine() {
    stopSpinner "${spinnerEraseLineCommand}" "${1}"
}
stopSpinner() {
    local command message
    if [[ ${1} =~ ${spinnerCommandPrefix} ]]; then
        command="${1}"
        message="${2}"
    else
        command="${spinnerEraseCommand}"
        message="${1}"
    fi
    _endSpin "${command}" "${message}"
}

failSpin() {
    _spinExit
    fail "${@}"
}

# shellcheck disable=SC2120
configureSpinner() {
    local color="${1:-${spinnerDefaultCharsColor}}"
    local chars="${2:-${spinnerDefaultChars}}"
    local count="${#chars}"
    local i c
    spinnerArray=()
    for (( i=0; i < ${count}; i++ )); do
        c="${chars:i:1}"
        c="$(printf "$(ansi ${color} ${chars:${i}:1})${ansi_normal}")"
        spinnerArray[${i}]="${c}"
    done
    spinnerArraySize=${count}
    spinnerMaxIndex=$(( ${count} -1))
    unset spinnerPid
}

## Implementation only below -----------------------------------

_ensureStopOnExit() {
    if [[ ! ${spinnerCleanupRegistered} ]]; then
        addExitHandler _spinExit
        spinnerCleanupRegistered=true
    fi
}

_initSpinner() {
    [[ ${spinnerArraySize} ]] || configureSpinner
    tput civis
    spinnerIndex=0
    spinnerForward=true
    _printProgressChar
}

_printProgressChar() {
    printf "${spinnerArray[${spinnerIndex}]}"
}

_beginSpin() {
    [[ ${1} ]] && echo -n "${1}"
    saveCursor
    printf ' '
    _initSpinner
}

_nextSpin() {
    if [[ ${spinnerForward} ]]; then
        if ((${spinnerIndex} < ${spinnerMaxIndex})); then
            spinnerIndex=$((spinnerIndex + 1))
            _printProgressChar
        else
            spinnerIndex=$((spinnerIndex - 1))
            spinnerForward=   # reverse direction
            printf '\b \b' # backup and erase 1 character
        fi
    elif ((${spinnerIndex} > 0)); then
        spinnerIndex=$((spinnerIndex - 1))
        printf '\b \b' # backup 1 character
    else
        spinnerIndex=0
        spinnerForward=true # reverse
        printf '\b \b'   # backup 1 character
        _printProgressChar
    fi
}

_endSpin() {
    local command="${1}"
    local message="${2}"
    restoreCursor
    case ${command} in
        "${spinnerEraseCommand}") eraseToEndOfLine ;;
        "${spinnerEraseLineCommand}") eraseCurrentLine ;;
        *) fail "unknown command: ${command}"
    esac
    tput cnorm
    [[ ${message} != '' ]] && echo "${message}"

    _killSpinner
}

_spinExit() {
    if [[ ${spinnerPid} ]]; then
        # Abnormal exit, clean up
        stopSpinnerAndEraseLine
        _killSpinner
    fi
}

_killSpinner() {
    if [[ ${spinnerPid} ]]; then
        kill -INT ${spinnerPid} 2> /dev/null
        wait "${spinnerPid}"   # Wait for the process to exit
        spinnerPid=
    fi
}
_testSpinner() {
    startSpinner "Working 1"
    sleep 2
    stopSpinner ". ${_greenCheckMark}"

    startSpinner "Working 2"
    sleep 2
    stopSpinnerAndEraseLine "Work completed ${_greenCheckMark}"

    startSpinner "Working 3"
    sleep 2
    stopSpinner '.'
}


## Server main functions ----------------------------

_spinServerMain() {
    local message="${1}"
    onServerExit() {
       # restoreCursor
       # eraseCurrentLine
        exit 0
    }

    trap "onServerExit" INT

    _beginSpin "${message}"

    while true; do
        sleep .25
        _nextSpin
    done
}

#_spinServerNetcat() {  ## TODO this doesn't work correctly
#    local message="${1}"
#    declare -grx spinnerSocket="$(tempDirPath)/spinner.sock"
#    rm "${spinnerSocket}" 2> /dev/null
#
#    onServerExit() {
#        killNetcat
#        restoreCursor
#        eraseCurrentLine
#       # echo "NEW spin server exiting"
#        exit 0
#    }
#
#    killNetcat() {
#        [[ ${netcatPid} ]] && kill "${netcatPid}" 2> /dev/null
#        removeSocket
#    }
#
#    removeSocket() {
#        # Check if the socket file exists and is in use
#        if [[ -e "${spinnerSocket}" ]]; then
#            if lsof -U "${spinnerSocket}" >/dev/null 2>&1; then # Check if something is using it
#                pid=$(lsof -t -U "${spinnerSocket}")            # Get the PID
#                echo "Socket file '${spinnerSocket}' is in use by PID: ${pid}. Killing..."
#                if ! kill "${pid}"; then
#                    echo "Error killing process ${pid}."
#                fi
#            fi
#            rm -f "${spinnerSocket}" 2> /dev/null
#        fi
#    }
#
#    trap "onServerExit" INT
#    removeSocket
#    _beginSpin "${message}"
#
#    while true; do
#
#        # Run netcat in the background so we can receive commands
#
#        nc -l -U "${spinnerSocket}" | while read command; do
#            echo "Command received: ${command}"   # TODO!
#        done &
#        netcatPid="${!}"
#
#        # Update the spinner so long as netcat is alive
#
#        while [[ -f "${spinnerSocket}" ]]; do
#            _nextSpin
#            sleep 0.25
#        done
#
#        # Client disconnected, restart netcat
#
#        killNetcat
#
#    done
#}

updateSpinner() {   # TODO?
    echo "${1}" | nc -U "${spinnerSocket}"
}

## Example usage (mostly unchanged)
#spinSocket="/tmp/my_socket.sock"
#
#rm -f "${spinSocket}"
#
#server "${spinSocket}" &
#SERVER_PID="${!}"
#
#sleep 0.1 # Give server time to start
#
#client "${spinSocket}" "Hello from client 1"
#client "${spinSocket}" "Another message"
#
#sleep 2 # Let it run for a bit
#
#kill "${SERVER_PID}"
#rm "${spinSocket}"
#
#echo "Done."
