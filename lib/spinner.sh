#!/usr/bin/env bash

# My library.
# Use via: require 'rayvn/spinner'

# IMPORTANT: While there are active spinners, the cursor is hidden globally. Before any
# foreground terminal interaction (prompts, user input, or other tput commands), you MUST
# stop all spinners. Otherwise, the user will be typing with an invisible cursor or
# terminal state may become inconsistent.

# spinnerTypes resultArrayVar
#
# Populates resultArrayVar with the names of all available spinner types.
# Available types: star, dots, line, circle, arrow, box, bounce, pulse, grow
#
# Example:
#   local types
#   spinnerTypes types
#   echo "Available: ${types[*]}"
spinnerTypes() {
    (( isInteractive )) || return 0  # No-op when not interactive

    local -n resultArray=$1
    resultArray=("${_spinnerNameList[@]}")
}

# startSpinner idVar [label] [type] [color]
#
# Starts a spinner at the current cursor position, storing its id in idVar.
# Pass idVar to stopSpinner to stop and replace it.
#
#   idVar   - variable name to receive the spinner id
#   label   - optional text printed immediately before the spinner (default: none)
#   type    - spinner animation style (default: 'star'); see spinnerTypes
#   color   - color name for the spinner (default: 'secondary')
#
# Example:
#   local spinnerId
#   startSpinner spinnerId "Loading " dots primary
#   doWork
#   stopSpinner spinnerId "Done"
startSpinner() {
    (( isInteractive )) || return 0  # No-op when not interactive

    local resultVarName=$1; shift
    if (( $# )); then
        echo -n "$1 " # Add space, will remove in stopSpinner
        shift
    fi
    local type=${1:-'star'} color=${2:-'secondary'} row col
    cursorPosition row col
    addSpinner ${resultVarName} ${type} ${row} ${col} ${color}
}

# stopSpinner [-n] idVar [replacement]
#
# Stops the spinner identified by idVar, replacing it with replacement text.
#
#   -n          - suppress the trailing newline after replacement
#   idVar       - variable name holding the spinner id (from startSpinner)
#   replacement - text to display in place of the spinner (default: space)
#
# Example:
#   stopSpinner spinnerId "Done"
#   stopSpinner -n spinnerId   # stop without newline
stopSpinner() {
    (( isInteractive )) || return 0  # No-op when not interactive

    local newline=true
    if [[ $1 == -n ]]; then
        newline=false; shift
    fi
    (( $# )) || invalidArgs "id varName required"
    local idVarName=$1; shift
    local replacement=' '
    (( $# )) && replacement="$*"
    removeSpinner ${idVarName} "${replacement}" ${newline} 1 # backup one char for space added in start
}

# addSpinner idVar type row col [color]
#
# Adds a spinner at the specified terminal position, storing its id in idVar.
# Prefer startSpinner for typical use; use this when you need explicit positioning.
#
#   idVar  - variable name to receive the spinner id
#   type   - spinner type; see spinnerTypes
#   row    - terminal row (1-based)
#   col    - terminal column (1-based)
#   color  - color name for the spinner (default: 'secondary')
addSpinner() {
    (( isInteractive )) || return 0  # No-op when not interactive

    (( $# )) || invalidArgs "result id varName required"

    local -n idRef=$1
    local type=$2 row=$3 col=$4 color=${5:-'secondary'} response=()
    [[ -n ${type} ]] || invalidArgs "type required"
    [[ -n ${row} ]] || invalidArgs "row required"
    [[ -n ${col} ]] || invalidArgs "col required"
    [[ -v _spinnerNameMap[${type}] ]] || invalidArgs "unknown type: ${type}"

    if _spinnerRequest add "${type}" "${color}" "${row}" "${col}"; then
        idRef=${response[1]}
    fi
}

# removeSpinner idVar [replacement] [newline] [backup]
#
# Removes the spinner identified by idVar. Prefer stopSpinner for typical use.
#
#   idVar       - variable name holding the spinner id (from addSpinner)
#   replacement - text to display in place of the spinner (default: space)
#   newline     - true to emit a newline after replacement, false to suppress (default: true)
#   backup      - number of characters to back up before writing replacement (default: 0)
removeSpinner() {
    (( isInteractive )) || return 0  # No-op when not interactive

    local idVarName=$1 replacement=${2:-' '} newline=${3:-true} backup=${4:-0} response=()

    [[ -n ${idVarName} ]] || invalidArgs "id varName required"
    local -n idRef=${idVarName}
    [[ ! "${idRef}" =~ ^[0-9]+$ ]] && invalidArgs "invalid id: must be a positive integer"

    _assertSpinnerServer # In case no other request has occurred
    _spinnerRequest remove "${idRef}" "${replacement}" ${newline} ${backup} > /dev/null
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/spinner' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_spinner() {
    require 'rayvn/core' 'rayvn/process' 'rayvn/terminal'
    local fifo type

    # Request and response fifos

    fifo="${ makeTempFifo; }"
    declare -gr _spinnerRequestFifo="${fifo}"
    fifo="${ makeTempFifo; }"
    declare -gr _spinnerResponseFifo="${fifo}"

    # Enable client/server init on first request

    declare -g _spinnerFirstRequest=1

    # Spinner type name list and map

    declare -gra _spinnerNameList=('star' 'dots' 'line' 'circle' 'arrow' 'box' 'bounce' 'pulse' 'grow')
    declare -gA _spinnerNameMap=()
    for type in "${_spinnerNameList[@]}"; do
        _spinnerNameMap+=([${type}]=1)
    done
    declare -grA _spinnerNameMap

    # Add shutdown handler

    addExitHandler _spinnerShutdown
}

_spinnerShutdown() {
    _shutdownSpinnerServer
}

_initSpinnerClient() {

    # Start the server in the background

    _spinnerServerMain &
    declare -g _spinnerServerPid=$!

    # Open our file descriptors

    declare -g _spinnerClientRequestFd=
    declare -g _spinnerClientResponseFd=

    exec {_spinnerClientRequestFd}>${_spinnerRequestFifo}
    exec {_spinnerClientResponseFd}<${_spinnerResponseFifo}

    # Normal response wait seconds

    declare -gr _spinnerMaxResponseWait=.25

    # Don't come back here again

    _spinnerFirstRequest=0
}

_initSpinnerServer() {

    # NOTE: This initialization is isolated so that all state is local to the server.
    #       Name collisions are not an issue, but the convention is followed for consistency.

    # Open fifos with fds assigned to fd vars.

    declare -g _spinnerServerRequestFd
    declare -g _spinnerServerResponseFd

    exec {_spinnerServerRequestFd}<${_spinnerRequestFifo}
    exec {_spinnerServerResponseFd}>${_spinnerResponseFifo}

    # Spinner state

    declare -gr _spinnerDelaySeconds=.25
    declare -g _spinnerTick=0
    declare -g _activeSpinnerCount=0
    declare -ga _spinnerIsActive=()
    declare -ga _spinnerFreeList=()

    # Spinner registry

    declare -ga _spinnerTypes=()
    declare -ga _spinnerColors=()
    declare -ga _spinnerRows=()
    declare -ga _spinnerCols=()

    # Spinners

    declare -gra _starSpinner=('✴' '❈' '❀' '❁' '❂' '❃' '❄' '❆' '❈' '✦' '✧' '✱' '✲' '✳' '✴' '✵' '✶' '✷' '✸' '✹' '✺' '✻' '✼' '✽' '✾' '✿')
    declare -gra _dotsSpinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    declare -gra _lineSpinner=('-' '\' '|' '/')
    declare -gra _circleSpinner=('◐' '◓' '◑' '◒')
    declare -gra _arrowSpinner=('←' '↖' '↑' '↗' '→' '↘' '↓' '↙')
    declare -gra _boxSpinner=('◰' '◳' '◲' '◱')
    declare -gra _bounceSpinner=('⠁' '⠂' '⠄' '⠂')
    declare -gra _pulseSpinner=('∙' '●' '◉' '●' '∙')
    declare -gra _growSpinner=('▁' '▃' '▅' '▇' '█' '▇' '▅' '▃')

    # Add exit handler

    trap "_stopSpinnerServer" TERM INT HUP
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ CLIENT ⚠️ )+---)++++---)++-)++-+------+-+--"

_assertSpinnerServer() {
    [[ -n  ${_spinnerServerPid}  ]] || invalidArgs "no spinners have been added"
}

_spinnerRequest() {
    local -n responseArrayRef=$1
    local delay=${_spinnerMaxResponseWait}
    local count

    # Initialize if first request

    if (( _spinnerFirstRequest )); then
        _initSpinnerClient
        delay=1 # wait a little longer on first request
    fi

    # Send the request

    printf "%d\n%s\n" $# "$*" >&${_spinnerClientRequestFd}

    # Read the response

    if read -t ${delay} count <&${_spinnerClientResponseFd}; then
        mapfile -t -n "${count}" response <&${_spinnerClientResponseFd}
    fi

    # Process the response

    if (( $? == 0 )); then
        if [[ ${response[0]} == "ok" ]]; then
            resopnseArrayRef=${response[1]}
            return 0
        else
            fail "${response[0]}"
        fi
    elif (( $? > 128 )); then
        fail "spinner request failed: response timeout"
    else
        fail "spinner request failed with exit $?"
    fi
}

_spinnerExit() {
    if (( _spinnerServerPid )); then
        # Abnormal exit, clean up
        _shutdownSpinnerServer
        echo > /dev/tty # Ensure not buffered in stdout
    fi
}

_shutdownSpinnerServer() {
    if (( _spinnerServerPid )); then
        {
            printf "%d\n%s\n" 1 'stop' >&${_spinnerClientRequestFd}
        } &> /dev/null

        if ! waitForProcessExit "${_spinnerServerPid}" 4000 10 500; then
            local errMsg="spinner process ${_spinnerServerPid} didn't exit"
            [[ -n "${inRayvnFail}" ]] && error "${errMsg}" || fail "${errMsg}"
        fi
    fi
    _spinnerServerPid=0
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ SERVER ⚠️ )+---)++++---)++-)++-+------+-+--"

_spinnerServerMain() {
    local request
    _initSpinnerServer
    while true; do
        request=()
        if _readSpinnerRequest; then
            case "${request[0]}" in
                add) _addSpinner "${request[1]}" "${request[2]}" "${request[3]}" "${request[4]}" ;;
                remove) _removeSpinner "${request[1]}" "${request[2]}" "${request[3]}" "${request[4]}";;
            esac
        fi
        _renderSpinners
    done
}

_readSpinnerRequest() {
    local count delay

    # Wait only for our spinner update delay if active, block on read if not active

    (( _activeSpinnerCount )) && delay="${_spinnerDelaySeconds}" || delay=100

    if read -t "${delay}" count <&${_spinnerServerRequestFd}; then
        if ! mapfile -t -n "${count}" request <&${_spinnerServerRequestFd}; then
            _spinnerResponse "read request parameters failed with $?, count=${count}"
            return 1
        fi
    elif (( $? <= 128 )); then
        _spinnerResponse "read request count failed with: $?"
        return 1
    elif (( $? > 128 )); then
        return $?
    fi
    return 0
}

_addSpinner() {
    local type=$1 color=$2 row=$3 col=$4
    local id

    _newSpinnerId id

    _spinnerActive[id]=1
    _spinnerTypes[id]="${type}"
    _spinnerColors[id]="${color}"
    _spinnerRows[id]="${row}"
    _spinnerCols[id]="${col}"
    _spinnerResponse 'ok' "${id}"

    # hide cursor of this is our first active spinner then increment

    (( _activeSpinnerCount )) || cursorHide
    (( _activeSpinnerCount++ ))
}

_removeSpinner() {
    local id=$1 replacement="$2" newline=$3 backupCount=$4 echoArg='' padding

    if (( _spinnerActive[id] )); then

        [[ ${newline} == false ]] && echoArg='-n'
        if (( backupCount )); then
            printf -v padding '%*s' "${backupCount}" ''
            replacement+="${padding}"
        fi

        cursorTo ${_spinnerRows[id]} $(( ${_spinnerCols[id]} - backupCount ))
        echo ${echoArg} "${replacement}" > /dev/tty
        freeList+=("${id}")
        _spinnerActive[id]=0
        _spinnerResponse 'ok'

        # decrement active counter and show cursor if we reach zero

        (( _activeSpinnerCount-- ))
        (( _activeSpinnerCount )) || cursorShow

    else
        _spinnerResponse "inactive id: ${id}"
    fi
}

_spinnerResponse() {
    printf "%d\n%s\n" $# "$*" >&${_spinnerServerResponseFd}
}

_stopSpinnerServer() {
    # erase any active spinners
    for (( i=0; i < ${#_spinnerTypes}; i++ )); do
        if (( _spinnerActive[i] )); then
            cursorTo "${_spinnerRows[i]}" "${_spinnerCols[i]}"
            echo -n ' ' > /dev/tty
        fi
    done
    exit 0
}

_renderSpinners() {
    local i spinnerIndex

    for (( i=0; i < ${#_spinnerActive[@]}; i++ )); do
        if (( _spinnerActive[i] )); then
            cursorTo "${_spinnerRows[i]}" "${_spinnerCols[i]}"
            local -n spinner="_${_spinnerTypes[i]}Spinner"
            spinnerIndex=$(( _spinnerTick % ${#spinner[@]} ))
            show -n "${_spinnerColors[i]}" "${spinner[spinnerIndex]}" > /dev/tty
        fi
    done

    (( _spinnerTick++ ))
}

_newSpinnerId() {
    local -n idRef=$1
    if (( ${#freeList[@]} )); then
        idRef="${freeList[-1]}"
        unset 'freeList[-1]'
    else
        idRef=${#_spinnerRows[@]}
    fi
}


