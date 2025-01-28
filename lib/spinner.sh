#!/usr/bin/env bash

# Library supporting progress meters
# Intended for use via: require 'core/progress'

require 'core/base'

init_core_spinner() {
    initSpinner
}

declare -grx defaultProgressChars='◞◜◝◟◞◜◝◟◞◜◝◟'
declare -grx defaultProgressCharsColor='bold_blue'
declare -ga progressArray=
declare -g progressArraySize=
declare -g maxProgressIndex=
declare -g progressIndex=
declare -g progressForward=

initSpinner() {
    local color="${1:-${defaultProgressCharsColor}}"
    local chars="${2:-${defaultProgressChars}}"
    local count="${#chars}"
    local i c
    progressArray=()
    for (( i=0; i < ${count}; i++ )); do
        c="${chars:i:1}"
        c="$(printf "$(ansi ${color} ${chars:${i}:1})${ansi_normal}")"
        progressArray[${i}]="${c}"
    done
    progressArraySize=${count}
    maxProgressIndex=$(( ${count} -1))
}

startSpinner() {
    [[ ${progressArraySize} ]] || initSpinner
    saveCursor
    tput civis
    progressIndex=0
    progressForward=true
    _printProgressChar
}

_printProgressChar() {
    printf "${progressArray[${progressIndex}]}"
}

updateSpinner() {
    if [[ ${progressForward} ]]; then
        if ((${progressIndex} < ${maxProgressIndex})); then
            progressIndex=$((progressIndex + 1))
            _printProgressChar
        else
            progressIndex=$((progressIndex - 1))
            progressForward=   # reverse direction
            printf '\b \b' # backup and erase 1 character
        fi
    elif ((${progressIndex} > 0)); then
        progressIndex=$((progressIndex - 1))
        printf '\b \b' # backup 1 character
    else
        progressIndex=0
        progressForward=true # reverse
        printf '\b \b'   # backup 1 character
        _printProgressChar
    fi
}

endSpinner() {
    restoreCursor
    eraseToEndOfLine
    tput cnorm
}

startBackgroundSpinner() {
    declare -g backgroundProgressPid
    startSpinner
    _runBackgroundSpinner &
    backgroundProgressPid=${!}
}

stopBackgroundSpinner() {
    local eraseLine="${1}"
    if [[ ${backgroundProgressPid} ]]; then
        kill SIGINT ${backgroundProgressPid}  2> /dev/null
        backgroundProgressPid=
    fi
    endSpinner
    [[ ${eraseLine} == true ]] && eraseCurrentLine
}

failSpin() {
    [[ ${backgroundProgressPid} ]] && stopBackgroundSpinner true
    fail "${@}"
}

_runBackgroundSpinner() {
    while true; do
        sleep .25
        updateSpinner
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
    startSpinner
    for i in {1..30}; do
        sleep .25
        #read -s -n 1 key
        updateSpinner
    done
    endSpinner
    eraseCurrentLine
}

backgroundSpinnerTest() {
    [[ ${1} ]] || fail "tty required for foreground work output"
    local output=${1}
    echo -n "Testing "
    startBackgroundSpinner
    echo > ${output}
    echo "START foreground work" > ${output}
    for i in {1..10}; do
        echo "working ${i}" > ${output}
        sleep 1
    done
    echo "END foreground work"  > ${output}
    stopBackgroundSpinner
    eraseCurrentLine
}
