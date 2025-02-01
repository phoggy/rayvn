#!/usr/bin/env bash

# Library supporting progress spinner
# Intended for use via: require 'core/spinner'

require 'core/base'

init_core_spinner() {
    configureSpinner
}

declare -grx spinnerDefaultChars='◞◜◝◟◞◜◝◟◞◜◝◟'
declare -grx spinnerDefaultCharsColor='bold_blue'
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
        _startSpinner
        _runBackgroundSpinner &
        spinnerPid=${!}
    fi
}

stopSpinner() {
    local eraseLine="${1}"
    if [[ ${spinnerPid} ]]; then
        kill SIGINT ${spinnerPid}  2> /dev/null
        spinnerPid=
    fi
    _endSpinner
    [[ ${eraseLine} == true ]] && eraseCurrentLine
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

_ensureStopOnExit() {
    if [[ ! ${spinnerCleanupRegistered} ]]; then
        addExitHandler _spinExit
        spinnerCleanupRegistered=true
    fi
}

_spinExit() {
    [[ ${spinnerPid} ]] && stopSpinner true
}

_startSpinner() {
    [[ ${spinnerArraySize} ]] || configureSpinner
    saveCursor
    tput civis
    spinnerIndex=0
    spinnerForward=true
    _printProgressChar
}

_printProgressChar() {
    printf "${spinnerArray[${spinnerIndex}]}"
}

_updateSpinner() {
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

_endSpinner() {
    restoreCursor
    eraseToEndOfLine
    tput cnorm
}

_runBackgroundSpinner() {
    while true; do
        sleep .25
        _updateSpinner
    done
}

SpinnerTest() {
#    echo "maxSpin: ${maxProgressIndex}"
#    echo -n "         "
#    for (( i=0; i < ${progressArraySize}; i++ )); do printf ${progressArray[i]}; done
#    echo
#    echo -n "         "
#    for (( i=0; i < ${progressArraySize}; i++ )); do printf ${i}; done
#    echo
    echo -n "Working "
    _startSpinner
    for i in {1..30}; do
        sleep .25
        #read -s -n 1 key
        _updateSpinner
    done
    _endSpinner
    eraseCurrentLine
}

backgroundSpinnerTest() {
    [[ ${1} ]] || fail "tty required for foreground work output"
    local output=${1}
    echo -n "Testing "
    startSpinner
    echo > ${output}
    echo "START foreground work" > ${output}
    for i in {1..10}; do
        echo "working ${i}" > ${output}
        sleep 1
    done
    echo "END foreground work"  > ${output}
    stopSpinner
    eraseCurrentLine
}
