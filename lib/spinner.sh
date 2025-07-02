#!/usr/bin/env bash
# shellcheck disable=SC2120,SC2155

# Library supporting progress spinner
# Intended for use via: require 'rayvn/spinner'

require 'rayvn/core' 'rayvn/terminal'

_init_rayvn_spinner() {
    if (( terminalSupportsAnsi )); then
        declare -grx spinnerDefaultChars='◞◜◝◟◞◜◝◟◞◜◝◟' # other options see https://antofthy.gitlab.io/info/ascii/Spinners.txt
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

        configureSpinner
    fi
}

startSpinner() {
    if (( terminalSupportsAnsi )) && [[ ! ${spinnerPid} ]]; then
        _ensureStopOnExit
        _spinServerMain "${1}" &
        spinnerPid=${!}
    fi
}

restartSpinner() {
    if (( terminalSupportsAnsi )); then
        stopSpinner "${1}"
        startSpinner "${2}"
    fi
}

replaceSpinnerAndRestart() {
    if (( terminalSupportsAnsi )); then
        stopSpinner "${spinnerEraseLineCommand}" "${1}"
        startSpinner "${2}"
    fi
}

stopSpinnerAndEraseLine() {
    if (( terminalSupportsAnsi )); then
        stopSpinner "${spinnerEraseLineCommand}" "${1}"
    fi
}

stopSpinner() {
    if (( terminalSupportsAnsi )); then
        local command message
        if [[ ${1} =~ ${spinnerCommandPrefix} ]]; then
            command="${1}"
            message="${2}"
        else
            command="${spinnerEraseCommand}"
            message="${1}"
        fi
        _endSpin "${command}" "${message}"
    fi
}

failSpin() {
    if (( terminalSupportsAnsi )); then
       _spinExit
    fi
    fail "${@}"
}

# shellcheck disable=SC2120
configureSpinner() {
    if (( terminalSupportsAnsi )); then
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
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_ensureStopOnExit() {
    if [[ ! ${spinnerCleanupRegistered} ]]; then
        addExitHandler _spinExit
        spinnerCleanupRegistered=true
    fi
}

_init_Spinner() {
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
    cursorSave
    printf ' '
    _init_Spinner
}

_nextSpin() {
    if [[ ${spinnerForward} ]]; then
        if (( spinnerIndex < spinnerMaxIndex )); then
            spinnerIndex=$((spinnerIndex + 1))
            _printProgressChar
        else
            spinnerIndex=$((spinnerIndex - 1))
            spinnerForward=   # reverse direction
            printf '\b \b' # backup and erase 1 character
        fi
    elif (( spinnerIndex > 0 )); then
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
    cursorRestore
    case ${command} in
        "${spinnerEraseCommand}") eraseToEndOfLine ;;
        "${spinnerEraseLineCommand}") eraseCurrentLine ;;
        *) fail "unknown command: ${command}"
    esac
    tput cnorm
    [[ ${message} != '' ]] && echo "${message}"

    _killSpinner # TODO move above cursorRestore??
}

_spinServerMain() {
    local message="${1}"
    onServerExit() {
        exit 0
    }

    trap "onServerExit" INT

    _beginSpin "${message}"

    while true; do
        sleep .25
        _nextSpin
    done
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
        wait "${spinnerPid}" 2> /dev/null  # Wait for the process to exit
        spinnerPid=
    fi
}

_testSpinner() {
    local punctuation='.'
    local doneCheck="${_greenCheckMark}"
    local periodCheck="${punctuation} ${doneCheck}"
    startSpinner "Working 1"
    sleep 2
    stopSpinner "${periodCheck}"

    startSpinner "Working 2"
    sleep 2
    replaceSpinnerAndRestart "Work completed ${doneCheck}" "Working 3"
    sleep 2
    stopSpinner "${punctuation}"

    startSpinner "Working 4"
    sleep 2
    restartSpinner "${periodCheck}" "Working 5"
    sleep 2
    stopSpinner "${punctuation}"
}
