#!/usr/bin/env bash

# Process management.
# Use via: require 'rayvn/process'

require 'rayvn/core'

# ◇ Wait for a process to exit, escalating SIGTERM then SIGKILL if needed.
#
# · ARGS
#
#   pid (int)              Process ID to wait for.
#   timeoutMs (int)        Maximum wait time in milliseconds before returning failure.
#   checkIntervalMs (int)  Polling interval in milliseconds (default: 10).
#   termWaitMs (int)       Milliseconds after first check before sending SIGKILL (default: 1000).
#
# · NOTES
#
#   SIGTERM is sent after the first check interval if the process is still running.
#   SIGKILL is sent once termWaitMs has elapsed. Polling continues until timeoutMs
#   is reached regardless of which signals have been sent.
#
# · RETURNS
#
#   0  process exited
#   1  timeout expired

waitForProcessExit() {
    local pid=$1
    declare -i timeoutMs=$2
    declare -i checkIntervalMs=${3:-10}
    declare -i termWaitMs=${4:-1000}
    declare -i elapsed=0
    local termSent=0
    local killSent=0
    local checkIntervalS

    if [[ -z "${pid}" || -z "${timeoutMs}" ]]; then
        fail "Usage: waitForProcessExit <pid> <timeoutMs> [checkIntervalMs] [termWaitMs]"
    fi

    checkIntervalS="${ echo "scale=3; ${checkIntervalMs} / 1000" | bc; }" # Convert millis to fractional seconds

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
