#!/usr/bin/env bash

# My library.
# Use via: require 'rayvn/spinners'

spinnerTypes() {
    local -n resultArray="${1}"
    resultArray=("${!_spinnerNames[@]}")
}

addSpinner() {
    local type=$1 row=$2 col=$3 color=${4:-'secondary'}
    [[ -n ${type} ]] || invalidArgs "type required"
    [[ -n ${row} ]] || invalidArgs "row required"
    [[ -n ${col} ]] || invalidArgs "col required"
    [[ -v _spinnerNames[${type}] ]] || invalidArgs "unknown type: ${type}"

    _ensureSpinnerServer
    _spinnerCommand add "${type}" "${color}" "${row}" "${col}"
}

removeSpinner() {
    local id=$1 replacement=${2:-' '}
    [[ -n ${id} ]] || invalidArgs "id required"
    [[ -n ${_spinnerServerPid} ]] || invalidArgs "spinners are not yet running"

    _spinnerCommand remove "${id}" "${replacement}" > /dev/null
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/spinners' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_spinners() {
    require 'rayvn/core' 'rayvn/terminal' 'rayvn/process'

    # Request and response fifos

    local fifo
    fifo="${ makeTempFifo; }"
    declare -gr _spinnerRequestFifo="${fifo}"
    fifo="${ makeTempFifo; }"
    declare -gr _spinnerResponseFifo="${fifo}"

    # Client state

    declare -grA _spinnerNames=(['star']=1 ['dots']=1 ['line']=1 ['circle']=1 ['arrow']=1 ['box']=1 ['bounce']=1 ['pulse']=1 ['grow']=1)
    declare -g _spinnerServerPid=0

    # Add shutdown handler

    _spinnerShutdown() {
        _shutdownSpinnerServer
    }

    addExitHandler _spinnerShutdown
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ SERVER ⚠️ )+---)++++---)++-)++-+------+-+--"

# Server main loop
_spinnerServerMain() {
    local command
    _initSpinnerState

    while true; do
        if IFS=$'\x1f' read -t 0.1 -ra command <&4; then
            case "${command[0]}" in
                add) _addSpinner "${command[1]}" "${command[2]}" "${command[3]}" "${command[4]}" ;;
                remove) _removeSpinner "${command[1]}" "${command[2]}" ;;
                stop) _stopSpinnerServer ;;
            esac
        fi
        _renderSpinners
    done
}

_initSpinnerState() {
    cursorHide

    # Open fifos

    exec 4< "${_spinnerRequestFifo}"
    exec 5> "${_spinnerResponseFifo}"

    # Spinner state

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
}

_addSpinner() {
    local type=$1 color=$2 row=$3 col=$4
    local id

    id=${ _getNextId; }

    _spinnerActive[id]=1
    _spinnerTypes[id]="${type}"
    _spinnerColors[id]="${color}"
    _spinnerRows[id]="${row}"
    _spinnerCols[id]="${col}"
    (( _activeSpinnerCount++ ))

    echo "${id}" >&5
}

_removeSpinner() {
    local id=$1
    local replacement="$2"

    if [[ -n ${_spinnerActive[id]} ]]; then
        cursorTo "${_spinnerRows[id]}" "${_spinnerCols[id]}"
        echo -n "${replacement}" > /dev/tty
        freeList+=("${id}")
        _spinnerActive[id]=0
        (( _activeSpinnerCount-- ))

        echo "ok" >&5
    else
        echo "error: invalid id" >&5
    fi
}

_stopSpinnerServer() {
    for (( i=0; i < ${#_spinnerTypes}; i++ )); do
        if [[ -n ${_spinnerRows[i]} ]]; then
            cursorTo "${_spinnerRows[i]}" "${_spinnerCols[i]}"
            echo -n ' ' > /dev/tty
        fi
    done
    tput cnorm
    echo "stopped" >&5
    exit 0
}

_renderSpinners() {
    local i spinnerIndex spinnerName spinnerArrayName

    for (( i=0; i < ${#_spinnerActive[@]}; i++ )); do
        if (( ${_spinnerActive[i]} )); then
            cursorTo "${_spinnerRows[i]}" "${_spinnerCols[i]}"
            spinnerName="${_spinnerTypes[i]}"
            local -n spinner="_${spinnerName}Spinner"
            spinnerIndex=$(( _spinnerTick % ${#spinner[@]} ))
            show -n "${_spinnerColors[i]}" "${spinner[spinnerIndex]}" > /dev/tty
        fi
    done

    (( _spinnerTick++ ))
}

_getNextId() {
    local id
    if (( ${#freeList[@]} )); then
        id="${freeList[-1]}"
        unset 'freeList[-1]'
    else
        id=${#_spinnerRows[@]}
    fi
    echo "${id}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ CLIENT ⚠️ )+---)++++---)++-)++-+------+-+--"

_spinnerCommand() {
    local response
    local IFS=$'\x1f'
    printf "%s\n" "$*" > "${_spinnerRequestFifo}"
    read -r response < "${_spinnerResponseFifo}"
    echo "${response}"
}

_ensureSpinnerServer() {
    if (( ! _spinnerServerPid )); then
        _startSpinnerServer
    fi
}

# Start server if not running
_startSpinnerServer() {
    (( _spinnerServerPid )) && return 0

    # Start server in background

    _spinnerServerMain &
    _spinnerServerPid=$!

    # Wait for server to be ready
    local count=0 maxWait=50
    while [[ ! -p ${_spinnerResponseFifo} ]] && (( count < maxWait )); do
        sleep 0.1
        (( count++ ))
    done

    if [[ ! -p ${_spinnerResponseFifo} ]]; then
        fail "Spinner server failed to start"
    fi
}

# Stop server
_shutdownSpinnerServer() {
    if (( _spinnerServerPid )); then
        {
            echo 'stop' > "${_spinnerRequestFifo}"
            read -r response < "${_spinnerResponseFifo}"
        } &> /dev/null

        if ! waitForProcessExit "${_spinnerServerPid}" 4000 10 500; then
            local errMsg="spinner process ${_spinnerServerPid} didn't exit"
            [[ -n "${inRayvnFail}" ]] && error "${errMsg}" || fail "${errMsg}"
        fi
    fi
    _spinnerServerPid=0
}


