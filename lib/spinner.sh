#!/usr/bin/env bash
# shellcheck disable=SC2120,SC2155

# Library supporting progress spinner
# Intended for use via: require 'rayvn/spinner'
#
# IMPORTANT: The spinner runs in a background process and uses 'tput civis' to hide
# the cursor globally. Before any foreground terminal interaction (prompts, user input,
# or other tput commands), you MUST call stopSpinner() first. Otherwise, the user will
# be typing with an invisible cursor or terminal state may become inconsistent.
#
# Example:
#   startSpinner "Processing..."
#   doWork
#   stopSpinner "Done"
#   prompt "Continue?" # Safe - cursor is now visible

startSpinner() {
    (( isInteractive )) || return 0  # No-op when not interactive
    _initSpinner "${@}"
    if [[ ! ${_spinnerPid} ]]; then
        _ensureStopOnExit

        # Show the message then save the resulting cursor position

        echo -n "${_spinnerMessage} "
        cursorPosition _spinnerRow _spinnerCol

        # Start the server in the background and save its PID

        _spinServerMain &
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

_initSpinner() {
    _spinnerMessage="${1:- }"
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

    if [[ ${frameType} != "${_spinnerFrameType}"  || ${frameColors[*]} != "${_spinnerFrameColors[*]}" ]]; then
        _generateSpinnerFrames "${frameVarName}"  "${frameColors[@]}"
    fi

    # Save args for next time

    _spinnerFrameType="${frameType}"
    _spinnerFrameColors=("${frameColors[@]}")

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

    _spinnerFramesCount="${#framesRef[@]}"
    for (( i=0; i < _spinnerFramesCount; i++ )); do
        _spinnerFrames["${i}"]="${ show "${colors[@]}" "${framesRef["${i}"]}"; }"
    done
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/spinner' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_spinner() {
    require 'rayvn/core' 'rayvn/terminal' 'rayvn/process'
}

# Spinner arguments

declare -g _spinnerMessage=
declare -g _spinnerFrameType=
declare -gax _spinnerFrameColors=()

# Spinner state

declare -gax _spinnerFrames=()
declare _gx _spinnerFramesCount=0
declare -g _spinnerFrameIndex=0
declare -g _spinnerPid=
declare -gi _spinnerCleanupRegistered=0
declare -g _spinnerRow
declare -g _spinnerCol

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

_beginSpin() {

    # Hide the cursor globally (affects all terminal output!)
    # See header documentation about stopping spinner before any user interaction.

    tput civis  # hide cursor

    # Init the frame index

    _spinnerFrameIndex=0
}

_updateFrame() {
    cursorTo ${_spinnerRow} ${_spinnerCol}
    echo -n "${_spinnerFrames[${_spinnerFrameIndex}]}"
    (( _spinnerFrameIndex++ ))
    (( _spinnerFrameIndex > _spinnerFramesCount)) && _spinnerFrameIndex=0 # wrap
}

_endSpin() {
    local command="${1}"
    local message="${2}"
    _stopSpinner

    # Restore cursor visibility

    tput cnorm

    # Move cursor back to start of spinner, with column adjusted for space added to message

    cursorTo ${_spinnerRow} $(( _spinnerCol - 1 ))

    # Erase the spinner
    case ${command} in
        "${_spinnerEraseCommand}") eraseToEndOfLine ;;
        "${_spinnerEraseLineCommand}") eraseCurrentLine ;;
        *) fail "unknown command: ${command}" ;;
    esac

    # If there's a message, print it.

    [[ -n "${message}" ]] && echo "${message}"
}

_spinServerMain() {

    onSpinServerExit() {
        exit 0
    }

    trap "onSpinServerExit" TERM INT HUP

    _beginSpin
    while true; do
        _updateFrame
        sleep "${_spinnerDelayInterval}"
    done
}

_spinExit() {
    if [[ ${_spinnerPid} ]]; then
        # Abnormal exit, clean up
        stopSpinner
        echo > /dev/tty # Ensure not buffered in stdout
    fi
}

_stopSpinner() {
    if [[ ${_spinnerPid} ]]; then
        kill -INT "${_spinnerPid}" 2> /dev/null

        # Wait for exit with 4 second total timeout, checking every 10ms, with
        # 500ms between TERM and KILL.

        if ! waitForProcessExit ${_spinnerPid} 4000 10 500; then
            local errMsg="spinner process ${_spinnerPid} didn't respond to signals"
            [[ -n "${inRayvnFail}" ]] && error "${errMsg}" || fail "${errMsg}"
        fi
        _spinnerPid=
    fi
}
