#!/usr/bin/env bash
# shellcheck disable=SC2120,SC2155

# Library supporting progress spinner
# Intended for use via: require 'rayvn/spinner'

startSpinner() {
    ((isInteractive)) || return 0  # No-op when not interactive
    local message="${1}"
    local framesIndex="${2:-0}"

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

configureSpinner() {
    local spinnerIndex=${1:-0}
    local colorsVarName=${2:-_spinnerDefaultCharsColor}

    (( ${#spinnerIndex} < ${#_frameNames} )) || fail "spinner index must be >= 0 and < ${#_frameNames}"
    _configuredSpinnerIndex="${spinnerIndex}"
    local frameVarName="_${_frameNames[${spinnerIndex}]}Frames" # generate var name

    _createSpinnerFrames "${frameVarName}"  "${colorsVarName}"
}

# shellcheck disable=SC2120
_createSpinnerFrames() {
    IFS=' ' # TODO WHY does this need to be fixed here?
    local -n framesRef="${1}"
    local -n colorsRef="${2}"
    local -a colors=("${colorsRef[@]}")
    local i
    _framesCount="${#framesRef[@]}"

    unset _spinnerPid

    # Generate the frames

    for (( i=0; i < _framesCount; i++ )); do
        _frames["${i}"]="${ show "${colors[@]}" "${framesRef["${i}"]}"; }"
    done
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/spinner' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_spinner() {
    require 'rayvn/core' 'rayvn/terminal' 'rayvn/process'
   # configureSpinner
}

# TODO: rename to waiting?

# spinner ideas
#   - https://github.com/sindresorhus/cli-spinners/blob/main/spinners.json
#   - https://antofthy.gitlab.io/info/ascii/Spinners.txt

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

declare -grax _starFrames=('❀' '❁' '❂' '❃' '❄' '❅' '❆' '❇' '❈' '✦' '✧' '✱' '✲' '✳' '✴' '✵' '✶' '✷' '✸' '✹' '✺' '✻' '✼' '✽' '✾' '✿')

declare -grax _frameNames=( 'snake' 'star')
declare -gax _frames=()
declare _gx _framesCount=0
declare -g _frameIndex=0
declare -gx _configuredSpinnerIndex=

# https://medium.com/@kyletmartinez/reverse-engineering-claudes-ascii-spinner-animation-eec2804626e0

#  · (middle dot / bullet)
#  ✻ (teardrop-spoked asterisk)
#  ✽ (heavy teardrop-spoked asterisk)
#  ✶ (six pointed black star)
#  ✳ (eight spoked asterisk)
#  ✢ (four balloon-spoked asterisk)

#declare -grx _throbDefaultChars='❀❁❂❃❄❅❆❇❈✦✧✱✲✳✴✵✶✷✸✹✺✻✼✽✾✿' # '✦✧✱✲✳✴✵✶✷✸'

declare -grax _spinnerDefaultCharsColor=(bold blue)
declare -grx _spinnerCommandPrefix="::"
declare -grx _spinnerEraseCommand="${_spinnerCommandPrefix}eraseSpinner"
declare -grx _spinnerEraseLineCommand="${_spinnerCommandPrefix}eraseLine"
declare -grx _spinnerDelayInterval='0.25'

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

_spinServerMain() {
    local message="${1}"
    local spinnerIndex="${2}"

    onServerExit() {
        exit 0
    }

    trap "onServerExit" TERM INT HUP

    _beginSpin "${message}" "${spinnerIndex}"

    while true; do
        _updateFrame
        sleep "${_spinnerDelayInterval}"
    done
}

_beginSpin() {
    local message="${1}"
    local spinnerIndex="${2}"

    echo -n "${1}"  # show message
    cursorSave

    # Make sure we are configured

    (( _framesCount == 0 || spinnerIndex != _configuredSpinnerIndex)) && configureSpinner "${spinnerIndex}"

    # Configure terminal

    tput civis
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

    startSpinner "Throb" 1
    sleep 5
    stopSpinner "${periodCheck}"

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
