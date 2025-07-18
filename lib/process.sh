#!/usr/bin/env bash

# Process management library.
# Intended for use via: require 'rayvn/process'

require 'rayvn/core'

# waitForProcessExit <pid> <timeoutMs> [checkIntervalMs] [termWaitMs]
#
# If process has not exited on its own after waiting one check interval, a TERM signal is
# sent if timeout has not expired. After termWaitMs, a KILL signal is sent if timeout has
# not expired. Waiting will then continue until timeout expires.

waitForProcessExit() {
    local pid=${1}
    declare -i timeoutMs=${2}
    declare -i checkIntervalMs=${3:-10}
    declare -i termWaitMs=${4:-1000}
    declare -i elapsed=0
    local termSent=0
    local killSent=0
    local checkIntervalS

    if [[ -z "${pid}" || -z "${timeoutMs}" ]]; then
        fail "Usage: waitForProcessExit <pid> <timeoutMs> [checkIntervalMs] [termWaitMs]"
    fi

    checkIntervalS=$(echo "scale=3; ${checkIntervalMs} / 1000" | bc) # Convert millis to fractional seconds

    while (( elapsed < timeoutMs )); do
        if ! kill -0 "${pid}" 2> /dev/null; then
            return 0  # Success, process has exited.
        fi

        if (( ! termSent && elapsed > 0 )); then
            kill -TERM "${pid}" 2> /dev/null
            termSent=1
        fi

        if (( termSent && ! killSent && elapsed >= termWaitMs )); then
            kill -KILL "${pid}" 2> /dev/null
            killSent=1
        fi

        sleep "${checkIntervalS}"
        elapsed=elapsed+checkIntervalMs
    done

    return 1 # fail, timeout
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/process' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_process() {
    require 'rayvn/core'
}
