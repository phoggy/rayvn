#!/usr/bin/env bash

main() {
    init "$@"

    testTypistDelaysCount
    testTypistDelaysFormat
    testTypistDelaysPositive
    testTypistDelaysWpmScaling

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug)     setDebug --showLogOnExit ;;
            --debug-new) setDebug --clearLog --showLogOnExit ;;
            --debug-out) setDebug --tty "${terminal}" ;;
            --debug-tty) shift; setDebug --tty "$1" ;;
        esac
        shift
    done
}

testTypistDelaysCount() {
    local text='hello' delays=()
    typistDelays 120 "${text}" delays
    # One delay per char plus trailing repeat of last delay
    assertEqual $(( ${#text} + 1 )) "${#delays[@]}" "delay count = len(text) + 1"
}

testTypistDelaysFormat() {
    local delays=() delay
    typistDelays 120 'ab' delays
    for delay in "${delays[@]}"; do
        assertTrue "delay '${delay}' matches N.NNN format" \
            eval "[[ '${delay}' =~ ^[0-9]+\.[0-9]{3}$ ]]"
    done
}

testTypistDelaysPositive() {
    local delays=() delay
    typistDelays 120 'hello world' delays
    for delay in "${delays[@]}"; do
        local ms; ms=${ printf '%s' "${delay}" | gawk '{printf "%d", $1 * 1000}'; }
        assertTrue "delay '${delay}' is positive" eval "(( ${ms} > 0 ))"
    done
}

testTypistDelaysWpmScaling() {
    # Faster WPM should produce smaller total delay than slow WPM
    local fastDelays=() slowDelays=()
    typistDelays 300 'hello world' fastDelays
    typistDelays 30  'hello world' slowDelays

    local fastSum=0 slowSum=0 i
    for (( i = 0; i < ${#fastDelays[@]}; i++ )); do
        (( fastSum += ${ printf '%s' "${fastDelays[$i]}" | gawk '{printf "%d", $1 * 1000}'; } ))
        (( slowSum += ${ printf '%s' "${slowDelays[$i]}" | gawk '{printf "%d", $1 * 1000}'; } ))
    done
    assertTrue "300 wpm total delay < 30 wpm total delay" eval "(( ${fastSum} < ${slowSum} ))"
}

source rayvn.up 'rayvn/typist' 'rayvn/test'
main "$@"
