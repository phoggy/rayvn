#!/usr/bin/env bash
# shellcheck disable=SC2120,SC2155

# Library supporting progress spinner
# Intended for use via: require 'rayvn/spinner'

startSpinner() {
    if [[ ! ${_spinnerPid} ]]; then
        _ensureStopOnExit
        _spinServerMain "${1}" &
        _spinnerPid=${!}
    fi
}

restartSpinner() {
    stopSpinner "${1}"
    startSpinner "${2}"
}

replaceSpinnerAndRestart() {
    stopSpinner "${_spinnerEraseLineCommand}" "${1}"
    startSpinner "${2}"
}

stopSpinnerAndEraseLine() {
    stopSpinner "${_spinnerEraseLineCommand}" "${1}"
}

stopSpinner() {
    local command message
    if [[ ${1} =~ ${_spinnerCommandPrefix} ]]; then
        command="${1}"
        message="${2}"
    else
        command="${_spinnerEraseCommand}"
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
    local color="${1:-${_spinnerDefaultCharsColor}}"
    local chars="${2:-${_spinnerDefaultChars}}"
    local count="${#chars}"
    local i c
    _spinnerArray=()
    for ((i = 0; i < ${count}; i++)); do
        c="${chars:i:1}"
        c="${ show ${color} "${chars:${i}:1}" ;}"
        _spinnerArray[${i}]="${c}"
    done
    _spinnerArraySize=${count}
    _spinnerMaxIndex=$((${count} - 1))
    unset _spinnerPid
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/spinner' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_spinner() {
    require 'rayvn/core' 'rayvn/terminal' 'rayvn/process'
    configureSpinner
}

declare -grx _spinnerDefaultChars='◞◜◝◟◞◜◝◟◞◜◝◟' # other options see https://antofthy.gitlab.io/info/ascii/Spinners.txt
declare -grx _spinnerDefaultCharsColor='bold_blue'
declare -grx _spinnerCommandPrefix="::"
declare -grx _spinnerEraseCommand="${_spinnerCommandPrefix}eraseSpinner"
declare -grx _spinnerEraseLineCommand="${_spinnerCommandPrefix}eraseLine"
declare -grx _spinnerDelayInterval='0.25'

declare -ga _spinnerArray=
declare -g _spinnerArraySize=
declare -g _spinnerMaxIndex=
declare -g _spinnerIndex=
declare -g _spinnerForward=
declare -g _spinnerPid=
declare -gi _spinnerCleanupRegistered=0

_ensureStopOnExit() {
    if (( ! _spinnerCleanupRegistered )); then
        addExitHandler _spinExit
        _spinnerCleanupRegistered=1
    fi
}

_printProgressChar() {
    echo -n "${_spinnerArray[${_spinnerIndex}]}"
}

_beginSpin() {
    [[ ${1} ]] && echo -n "${1}"
    cursorSave
    printf ' '
    [[ ${_spinnerArraySize} ]] || configureSpinner
    tput civis
    _spinnerIndex=0
    _spinnerForward=true
    _printProgressChar
}

_nextSpin() {
    if [[ ${_spinnerForward} ]]; then
        if ((_spinnerIndex < _spinnerMaxIndex)); then
            _spinnerIndex=$((_spinnerIndex + 1))
            _printProgressChar
        else
            _spinnerIndex=$((_spinnerIndex - 1))
            _spinnerForward= # reverse direction
            printf '\b \b'   # backup and erase 1 character
        fi
    elif ((_spinnerIndex > 0)); then
        _spinnerIndex=$((_spinnerIndex - 1))
        printf '\b \b' # backup 1 character
    else
        _spinnerIndex=0
        _spinnerForward=true # reverse
        printf '\b \b'       # backup 1 character
        _printProgressChar
    fi
}

_endSpin() {
    local command="${1}"
    local message="${2}"
    _stopSpinner
    cursorRestore
    case ${command} in
    "${_spinnerEraseCommand}") eraseToEndOfLine ;;
    "${_spinnerEraseLineCommand}") eraseCurrentLine ;;
    *) fail "unknown command: ${command}" ;;
    esac
    tput cnorm
    [[ ${message} != '' ]] && echo "${message}"
}

_spinServerMain() {
    local message="${1}"
    onServerExit() {
        exit 0
    }

    trap "onServerExit" TERM INT HUP

    _beginSpin "${message}"

    while true; do
        sleep .25
        _nextSpin
    done
}

_spinExit() {
    if [[ ${_spinnerPid} ]]; then
        # Abnormal exit, clean up
        stopSpinnerAndEraseLine
        _stopSpinner
    fi
}

_stopSpinner() {
    if [[ ${_spinnerPid} ]]; then
        kill -INT "${_spinnerPid}" 2> /dev/null

        # Wait for exit with 4 second total timeout, checking every 10ms, with
        # 500ms between TERM and KILL.

        if ! waitForProcessExit ${_spinnerPid} 4000 10 500; then
            fail "spinner process didn't respond to signals"
        fi
        _spinnerPid=
    fi
}

_testSpinner() {
    local punctuation='.'
    local doneCheck="${_greenCheckMark}"
    local periodCheck="${punctuation} ${doneCheck}"
    startSpinner "Working 1, expect '${periodCheck}' after 10 seconds"
    sleep 10
    stopSpinner "${periodCheck}"

    startSpinner "Working 2, expect REPLACEMENT with 'Work completed ${doneCheck}' after 4 seconds"
    sleep 4
    replaceSpinnerAndRestart "Work completed ${doneCheck}" "Working 3, expect '${punctuation}' after 2 seconds"
    sleep 2
    stopSpinner "${punctuation}"

    startSpinner "Working 4, expect '${periodCheck}' after 2 seconds"
    sleep 2
    restartSpinner "${periodCheck}" "Working 5, expect '${punctuation}' after 2 seconds"
    sleep 2
    stopSpinner "${punctuation}"
}
