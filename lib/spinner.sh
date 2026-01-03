#!/usr/bin/env bash
# shellcheck disable=SC2120,SC2155

# Library supporting progress spinner
# Intended for use via: require 'rayvn/spinner'

startSpinner() {
    (( isInteractive )) || return 0  # No-op when not interactive
    _initSpinner "${@}"
    if [[ ! ${_spinnerPid} ]]; then
        _ensureStopOnExit
        _spinServerMain "${message}" "${framesIndex}" &
        _spinnerPid=${!}
    fi
}

restartSpinner() {
    ((isInteractive)) || return 0  # No-op when not interactive
    stopSpinner "${1}"
    startSpinner "${2}"
}

replaceSpinnerAndRestart() {
    ((isInteractive)) || return 0  # No-op when not interactive
    stopSpinner "${_spinnerEraseLineCommand}" "${1}"
    startSpinner "${2}"
}

stopSpinnerAndEraseLine() {
    ((isInteractive)) || return 0  # No-op when not interactive
    stopSpinner "${_spinnerEraseLineCommand}" "${1}"
}

stopSpinner() {
    ((isInteractive)) || return 0  # No-op when not interactive
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

_initSpinner() {
    _spinnerMessage="${1:-''}"
    local frameType="${2:-snake}"
    local frameColors=("${@:3}")

    # Validate type

    isMemberOf "${frameType}" _frameTypes || fail "unknown spinner type '${frameType}', choices are ${_frameTypes[*]}"

    # Generate frame var names

    local frameVarName="_${frameType}Frames"
    local colorsVarName="_${frameType}Colors"

    # Update colors if none passed

    if (( ${#frameColors[@]} == 0 )); then
        local -n colorsRef="${colorsVarName}"
        frameColors=("${colorsRef[@]}")
    fi

    # Generate frames only if type or colors differ from last time

    if [[ ${frameType} != "${_frameType}"  || ${frameColors[*]} != "${_frameColors[*]}" ]]; then
        _generateSpinnerFrames "${frameVarName}"  "${frameColors[@]}"
    fi

    # Save args for next time

    _frameType="${frameType}"
    _frameColors=("${frameColors[@]}")

    # Make sure that pid is not set

    unset _spinnerPid
}

# shellcheck disable=SC2120
_generateSpinnerFrames() {
    IFS=' ' # TODO WHY does this need to be fixed here?
    local -n framesRef="${1}"
    local colors=("${@:2}")
    local i

    # Generate the frames

    _framesCount="${#framesRef[@]}"
    for (( i=0; i < _framesCount; i++ )); do
        _frames["${i}"]="${ show "${colors[@]}" "${framesRef["${i}"]}"; }"
    done
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/spinner' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_spinner() {
    require 'rayvn/core' 'rayvn/terminal' 'rayvn/process'
}

# Spinner arguments

declare -g _spinnerMessage=
declare -g _frameType=
declare -gax _frameColors=()

# Spinner state

declare -gax _frames=()
declare _gx _framesCount=0
declare -g _frameIndex=0
declare -g _spinnerPid=
declare -gi _spinnerCleanupRegistered=0

# Spinner types (see https://github.com/sindresorhus/cli-spinners/blob/main/spinners.json for ideas)

declare -grax _snakeFrames=(
    "◞           "
    "◞◜          "
    "◞◜◝         "
    "◞◜◝◟        "
    "◞◜◝◟◞       "
    "◞◜◝◟◞◜      "
    "◞◜◝◟◞◜◝     "
    "◞◜◝◟◞◜◝◟    "
    "◞◜◝◟◞◜◝◟◞   "
    "◞◜◝◟◞◜◝◟◞◜  "
    "◞◜◝◟◞◜◝◟◞◜◝ "
    "◞◜◝◟◞◜◝◟◞◜◝◟"
    "◞◜◝◟◞◜◝◟◞◜◝ "
    "◞◜◝◟◞◜◝◟◞◜  "
    "◞◜◝◟◞◜◝◟◞   "
    "◞◜◝◟◞◜◝◟    "
    "◞◜◝◟◞◜◝     "
    "◞◜◝◟◞◜      "
    "◞◜◝◟        "
    "◞◜◝         "
    "◞◜          "
)

declare -grax _snakeColors=(primary)

declare -grax _starFrames=('✴' '❈' '❀' '❁' '❂' '❃' '❄' '❆' '❈' '✦' '✧' '✱' '✲' '✳' '✴' '✵' '✶' '✷' '✸' '✹' '✺' '✻' '✼' '✽' '✾' '✿')
declare -grax _starColors=(secondary)

declare -grax _frameTypes=( 'snake' 'star')

declare -grx _spinnerCommandPrefix="::"
declare -grx _spinnerEraseCommand="${_spinnerCommandPrefix}eraseSpinner"
declare -grx _spinnerEraseLineCommand="${_spinnerCommandPrefix}eraseLine"
declare -grx _spinnerDelayInterval='0.25'


_ensureStopOnExit() {
    if (( ! _spinnerCleanupRegistered )); then
        addExitHandler _spinExit
        _spinnerCleanupRegistered=1
    fi
}

_printProgressChar() {
    echo -n "${_spinnerArray[${_spinnerIndex}]}"
}

_spinServerMain() {
    local message="${1}"
    local spinnerIndex="${2}"

    onServerExit() {
        exit 0
    }

    trap "onServerExit" TERM INT HUP

    _beginSpin

    while true; do
        _updateFrame
        sleep "${_spinnerDelayInterval}"
    done
}

_beginSpin() {

    # Show the message then save the resulting cursor position

    echo -n "${_spinnerMessage}"
    cursorSave

    # Configure terminal

    tput civis

    # Init the frame index

    _frameIndex=0
}

_updateFrame() {
    cursorRestore
    echo -n " ${_frames[${_frameIndex}]}"
    (( _frameIndex++ ))
    (( _frameIndex > _framesCount )) && _frameIndex=0 # wrap
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
    local framesIndex="${2}"

    onServerExit() {
        exit 0
    }

    trap "onServerExit" TERM INT HUP

    _beginSpin "${message}" "${framesIndex}"

    while true; do
        _updateFrame
        sleep "${_spinnerDelayInterval}"
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

    startSpinner "Star (default color)" star
    sleep 5
    stopSpinner "${periodCheck}"

    echo
    startSpinner "Default type & color, expect '${periodCheck}' after 5 seconds"
    sleep 5
    stopSpinner "${periodCheck}"

    echo
    startSpinner "Snake (bold success), expect REPLACEMENT with 'Work completed ${doneCheck}' after 4 seconds" snake bold success
    sleep 4
    replaceSpinnerAndRestart "Work completed ${doneCheck}" "Working 3, expect '${punctuation}' after 2 seconds"
    sleep 2
    stopSpinner "${punctuation}"

    echo
    startSpinner "Star (bold accent), expect '${periodCheck}' after 2 seconds" star bold accent
    sleep 2
    restartSpinner "${periodCheck}" "Working 5, expect '${punctuation}' after 2 seconds"
    sleep 2
    stopSpinner "${punctuation}"
}
