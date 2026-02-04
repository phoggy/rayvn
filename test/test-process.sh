#!/usr/bin/env bash
# shellcheck disable=SC2155

# Test suite for the rayvn/process library
# Tests waitForProcessExit with various process states, signals, and argument validation

main() {
    init "${@}"

    testAlreadyExitedProcess
    testNonExistentPid
    testProcessExitsOnTerm
    testProcessRequiresKill
    testMissingPidFails
    testMissingTimeoutFails
    testCustomCheckInterval
    testCustomTermWait

    return 0
}

init() {
    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${ tty; }" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done
}

# --- Already exited / non-existent ---

testAlreadyExitedProcess() {
    # Start a process and wait for it to finish naturally
    sleep 0 &
    local pid=${!}
    wait "${pid}" 2> /dev/null

    # Process has already exited, should return 0 immediately
    waitForProcessExit ${pid} 1000 10 || fail "should succeed for already exited process"
}

testNonExistentPid() {
    # Use a PID that almost certainly doesn't exist
    local fakePid=99999
    while kill -0 ${fakePid} 2> /dev/null; do
        (( fakePid++ ))
    done

    waitForProcessExit ${fakePid} 1000 10 || fail "should succeed for non-existent PID"
}

# --- Signal handling ---

testProcessExitsOnTerm() {
    # Start a long-running process that will respond to TERM
    sleep 60 &
    local pid=${!}

    # Verify it's running
    kill -0 ${pid} 2> /dev/null || fail "test process should be running"

    # Wait with short timeout; process should exit via TERM signal
    waitForProcessExit ${pid} 2000 10 500 || fail "process should exit after TERM"

    # Verify it's gone
    if kill -0 ${pid} 2> /dev/null; then
        kill -KILL ${pid} 2> /dev/null
        fail "process should not be running after waitForProcessExit"
    fi
}

testProcessRequiresKill() {
    # Start a process that ignores TERM
    bash -c 'trap "" TERM; sleep 60' &
    local pid=${!}
    disown ${pid} 2> /dev/null  # Suppress "Killed" message from bash

    # Verify it's running
    kill -0 ${pid} 2> /dev/null || fail "test process should be running"

    # Wait; should escalate from TERM to KILL
    waitForProcessExit ${pid} 4000 10 200 || fail "process should exit after KILL"

    # Verify it's gone
    if kill -0 ${pid} 2> /dev/null; then
        kill -KILL ${pid} 2> /dev/null
        fail "process should not be running after KILL"
    fi
}

# --- Argument validation ---

testMissingPidFails() {
    local caught=0
    ( nonInteractive=1; waitForProcessExit "" 1000 ) &> /dev/null || caught=1
    (( caught == 1 )) || fail "should fail when pid is empty"
}

testMissingTimeoutFails() {
    local caught=0
    ( nonInteractive=1; waitForProcessExit 12345 "" ) &> /dev/null || caught=1
    (( caught == 1 )) || fail "should fail when timeout is empty"
}

# --- Custom intervals ---

testCustomCheckInterval() {
    # Start and immediately stop a process
    sleep 0 &
    local pid=${!}
    wait "${pid}" 2> /dev/null

    # Use a large check interval; should still return quickly since process is already gone
    waitForProcessExit ${pid} 5000 100 || fail "should succeed with custom check interval"
}

testCustomTermWait() {
    # Start a process that ignores TERM
    bash -c 'trap "" TERM; sleep 60' &
    local pid=${!}
    disown ${pid} 2> /dev/null  # Suppress "Killed" message from bash

    # Use a short termWait so KILL is sent quickly
    waitForProcessExit ${pid} 4000 10 100 || fail "should succeed with short termWait"

    # Verify it's gone
    if kill -0 ${pid} 2> /dev/null; then
        kill -KILL ${pid} 2> /dev/null
        fail "process should not be running after short termWait KILL"
    fi
}

source rayvn.up 'rayvn/test' 'rayvn/process'
main "$@"
