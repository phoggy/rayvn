#!/usr/bin/env bash

# My library.
# Use via: require 'rayvn/spinners'

spinnerTypes() {
    local -n resultArray=$1
    resultArray=("${!_spinnerNames[@]}")
}

addSpinner() {
    local type=$1 row=$2 col=$3 color=${4:-'secondary'} response=()
    [[ -n ${type} ]] || invalidArgs "type required"
    [[ -n ${row} ]] || invalidArgs "row required"
    [[ -n ${col} ]] || invalidArgs "col required"
    [[ -v _spinnerNames[${type}] ]] || invalidArgs "unknown type: ${type}"

    if _spinnerRequest add "${type}" "${color}" "${row}" "${col}"; then
        echo ${response[1]}
    fi
}

removeSpinner() {
    local id=$1 replacement=${2:-' '} response=()
    [[ -n ${id} ]] || invalidArgs "id required"

    _assertSpinnerServer # In case no other request has occurred
    _spinnerRequest remove "${id}" "${replacement}" > /dev/null
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/spinners' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_spinners() {
    require 'rayvn/core' 'rayvn/process'

    # Request and response fifos

    local fifo
    fifo="${ makeTempFifo; }"
    declare -gr _spinnerRequestFifo="${fifo}"
    fifo="${ makeTempFifo; }"
    declare -gr _spinnerResponseFifo="${fifo}"

    # Response error message prefix

    declare -gr _spinnerErrorPrefix="!!"

    # Client state

    declare -gr _spinnerMaxResponseWait=.25
    declare -grA _spinnerNames=(['star']=1 ['dots']=1 ['line']=1 ['circle']=1 ['arrow']=1 ['box']=1 ['bounce']=1 ['pulse']=1 ['grow']=1)
    declare -g _spinnerServerPid=0
    declare -g _firstSpinnerRequest=1

    # Add shutdown handler

    _spinnerShutdown() {
        _shutdownSpinnerServer
    }

    addExitHandler _spinnerShutdown
}

_initSpinnerClient() {
    _firstSpinnerRequest=0

    # Start the server

    _startSpinnerServer

    # Open our file descriptors

    declare -g _spinnerClientRequestFd=
    declare -g _spinnerClientResponseFd=

    exec {_spinnerClientRequestFd}>${_spinnerRequestFifo}
    exec {_spinnerClientResponseFd}<${_spinnerResponseFifo}
}

_initSpinnerServer() {

    # NOTE: This initialization is isolated so that all state is local to the server.
    #       Name collisions are not an issue, but the convention is followed for consistency.

    require 'rayvn/terminal'

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
    (( _spinnerServerPid )) || invalidArgs "no spinners have been added"
}

_spinnerRequest() {
    local -n responseArrayRef=$1
    local readExit count
    local delay=${_spinnerMaxResponseWait}

    # Initialize if first request

    if (( _firstSpinnerRequest )); then
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
            return 0
        else
            fail "${responseArrayRef[1]}"
        fi
    elif (( $? > 128 )); then
        fail "spinner request failed: response timeout"
    else
        fail "spinner request failed with exit $?"
    fi
}

_startSpinnerServer() {
    (( _spinnerServerPid )) && fail "server already started!"

    # Start server in background

    _spinnerServerMain &
    _spinnerServerPid=$!
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
                remove) _removeSpinner "${request[1]}" "${request[2]}" ;;
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
        mapfile -t -n "${count}" request <&${_spinnerServerRequestFd}
        (( $? )) && fail "read request parameters failed with $?, count=${count}"
        return 0
    elif (( $? <= 128 )); then
        fail "read request count failed with: $?"
    elif (( $? > 128 )); then
        #debug "read request timeout"
        return $?
    fi
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
    local id=$1
    local replacement="$2"

    if (( _spinnerActive[id] )); then
        cursorTo "${_spinnerRows[id]}" "${_spinnerCols[id]}"
        echo -n "${replacement}" > /dev/tty
        freeList+=("${id}")
        _spinnerActive[id]=0
        _spinnerResponse 'ok'

        # decrement active counter and show cursor if we reach zero

        (( _activeSpinnerCount-- ))
        (( _activeSpinnerCount )) || cursorShow

    else
        _spinnerResponse fail "inactive id: ${id}"
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
    cursorShow
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


