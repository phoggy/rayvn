#!/usr/bin/env bash

# My library.
# Use via: require 'rayvn/spinners'

spinnerTypes() {
    local -n resultArray="${1}"
    resultArray=(${!_spinners[@]})
}

addSpinner() {
    local row=$1 col=$2 type=$3 index
    _ensureSpinnerServer
    echo "add ${row} ${col} ${type}" > "${_spinnerRequestFifo}"
    read -r index < "${_spinnerResponseFifo}"
    echo "${index}"
}

removeSpinner() {
    local index=$1
    local response

    _ensureSpinnerServer
    echo "remove ${index}" > "${_spinnerRequestFifo}"
    read -r response < "${_spinnerResponseFifo}"
    echo "${response}"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/spinners' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_spinners() {
    require 'rayvn/core' 'rayvn/terminal' 'rayvn/process'

    # Request and response fifos

    declare -g _spinnerRequestFifo
    declare -g _spinnerResponseFifo

    # Server state arrays

    declare -a _spinnerRows=()
    declare -a _spinnerCols=()
    declare -a _spinnerTypes=()
    declare -a _spinnerFreeList=()

    # Spinners

    declare -gra _starSpinner=('✴' '❈' '❀' '❁' '❂' '❃' '❄' '❆' '❈' '✦' '✧' '✱' '✲' '✳' '✴' '✵' '✶' '✷' '✸' '✹' '✺' '✻' '✼' '✽' '✾' '✿')
    declare -gra _dotsSpinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇ ⠏')
    declare -gra _lineSpinner=('-' '\\' '|' '/')
    declare -gra _circleSpinner=('◐' '◓' '◑' '◒')
    declare -gra _arrowSpinner=('←' '↖' '↑' '↗' '→' '↘' '↓' '↙')
    declare -gra _boxSpinner=('◰' '◳' '◲' '◱')
    declare -gra _bounceSpinner=('⠁' '⠂' '⠄' '⠂')
    declare -gra _pulseSpinner=('∙' '●' '◉' '●' '∙')
    declare -gra _growSpinner=('▁' '▃' '▅' '▇' '█' '▇' '▅' '▃')

    # Map type to spinner array

    declare -grA _spinners=(['star']=_starSpinner ['dots']=_dotsSpinner ['line']=_lineSpinner ['circle']=_circleSpinner \
                             ['arrow']=_arrowSpinner ['box']=_boxSpinner ['bounce']=_bounceSpinner ['pulse']=_pulseSpinner \
                             ['grow']=_growSpinner )

    # Misc state

    declare -g _spinnerServerPid=0
    declare -g _spinnerTick=0

    # Add shutdown handler

    _spinnerShutdown() {
        _stopSpinnerServer
        cursorShow
    }

    addExitHandler _spinnerShutdown
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ SERVER ⚠️ )+---)++++---)++-)++-+------+-+--"

# Server main loop
_spinnerServerMain() {
 debug "in server main"
    # Hide cursor
    cursorHide

    # Create fifos

    local fifo
    fifo="${ makeTempFifo; }"
    declare -gr _spinnerRequestFifo="${fifo}"
    fifo="${ makeTempFifo; }"
    declare -gr _spinnerResponseFifo="${fifo}"
  debugVar _spinnerRequestFifo _spinnerResponseFifo

    # Main loop
    while true; do
        if read -t 0.25 -r line < "${_spinnerRequestFifo}"; then
            if [[ ${line} =~ ^add[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+(.+)$ ]]; then
                _handleAdd "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"

            elif [[ ${line} =~ ^remove[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
                _handleRemove "${BASH_REMATCH[1]}"

            elif [[ ${line} == stop ]]; then
                _handleStop
            fi
        fi

        _renderSpinners
    done
}

_handleAdd() {
    local row=$1 col=$2 type=$3
    local index
    debug "_handleAdd($1 $2 $3)"

    index=${ _getNextIndex; }
    _spinnerRows[index]="${row}"
    _spinnerCols[index]="${col}"
    _spinnerTypes[index]="${type}"

    echo "${index}" > "${_spinnerResponseFifo}"
}

_handleRemove() {
    local index=$1

    if [[ -n ${_spinnerRows[index]} ]]; then
        tput cup "${_spinnerRows[index]}" "${_spinnerCols[index]}"
        echo -n " "

        unset '_spinnerRows[index]'
        unset '_spinnerCols[index]'
        unset '_spinnerTypes[index]'
        freeList+=("${index}")

        echo "ok" > "${_spinnerResponseFifo}"
    else
        echo "error: invalid index" > "${_spinnerResponseFifo}"
    fi
}

_handleStop() {
    echo "stopping" > "${_spinnerResponseFifo}"
    tput cnorm
    exit 0
}


# Get next available index
_getNextIndex() {
    local index
    if [[ ${#freeList[@]} -gt 0 ]]; then
        index="${freeList[-1]}"
        unset 'freeList[-1]'
    else
        index=${#_spinnerRows[@]}
    fi
    echo "${index}"
}

_renderSpinners() {
    local i spinnerIndex
    local -n spinner

    for i in "${!_spinnerRows[@]}"; do
        spinner="${_spinnerTypes[i]}"

        if [[ -n ${spinner} ]]; then
            cursorTo "${_spinnerRows[i]}" "${_spinnerCols[i]}"
            spinnerIndex=$(( _spinnerTick % ${#spinner[@]} ))
            echo -n "${spinner[spinnerIndex]}" > /dev/tty
        fi
    done

    (( _spinnerTick++ ))
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ CLIENT ⚠️ )+---)++++---)++-)++-+------+-+--"

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
debug "spin server ready"
}

# Stop server
_stopSpinnerServer() {
    if (( _spinnerServerPid )); then
        {
            echo "stop" > "${_spinnerRequestFifo}"
            read -r response < "${_spinnerResponseFifo}"
        } &> /dev/null

        if ! waitForProcessExit "${_spinnerServerPid}" 4000 10 500; then
            local errMsg="spinner process ${_spinnerServerPid} didn't exit"
            [[ -n "${inRayvnFail}" ]] && error "${errMsg}" || fail "${errMsg}"
        fi
    fi
    unset _spinnerServerPid
}


