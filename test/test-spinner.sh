#!/usr/bin/env bash
# shellcheck disable=SC2155

# Test suite for the rayvn/spinner library
# Tests initialization, frame types, frame generation, constants, and isInteractive guards

main() {
    init "${@}"

    testConstants
    testFrameTypeArrays
    testInitSpinnerDefaultMessage
    testInitSpinnerCustomMessage
    testInitSpinnerDefaultFrameType
    testInitSpinnerSnakeType
    testInitSpinnerStarType
    testInitSpinnerInvalidType
    testFrameGenerationSnake
    testFrameGenerationStar
    testFrameGenerationCaching
    testFrameGenerationCustomColors
    testNonInteractiveStartSpinner
    testNonInteractiveStopSpinner
    testNonInteractiveRestartSpinner
    testNonInteractiveReplaceSpinnerAndRestart
    testNonInteractiveStopSpinnerAndEraseLine

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

    # isInteractive is set by rayvn.up and is readonly; when running
    # non-interactively (e.g. from a script) it will already be 0
}

# --- Constants ---

testConstants() {
    assertEqual "${_spinnerCommandPrefix}" "::" "command prefix should be '::'"
    assertEqual "${_spinnerEraseCommand}" "::eraseSpinner" "erase command should be '::eraseSpinner'"
    assertEqual "${_spinnerEraseLineCommand}" "::eraseLine" "erase line command should be '::eraseLine'"
    assertEqual "${_spinnerDelayInterval}" "0.25" "delay interval should be '0.25'"
}

# --- Frame type arrays ---

testFrameTypeArrays() {
    # Verify _frameTypes contains expected types
    isMemberOf 'snake' _frameTypes || fail "'snake' not in _frameTypes"
    isMemberOf 'star' _frameTypes || fail "'star' not in _frameTypes"

    # Verify snake frames exist and have content
    local snakeCount=${#_snakeFrames[@]}
    (( snakeCount > 0 )) || fail "_snakeFrames is empty"
    assertEqual "${snakeCount}" "21" "snake should have 21 frames"

    # Verify star frames exist and have content
    local starCount=${#_starFrames[@]}
    (( starCount > 0 )) || fail "_starFrames is empty"
    assertEqual "${starCount}" "26" "star should have 26 frames"

    # Verify default colors exist
    assertEqual "${_snakeColors[0]}" "primary" "snake default color should be 'primary'"
    assertEqual "${_starColors[0]}" "secondary" "star default color should be 'secondary'"
}

# --- _initSpinner ---

testInitSpinnerDefaultMessage() {
    _initSpinner
    assertEqual "${_spinnerMessage}" " " "default message should be a single space"
}

testInitSpinnerCustomMessage() {
    _initSpinner "Processing..."
    assertEqual "${_spinnerMessage}" "Processing..." "message should be 'Processing...'"
}

testInitSpinnerDefaultFrameType() {
    _initSpinner "test"
    assertEqual "${_spinnerFrameType}" "snake" "default frame type should be 'snake'"
}

testInitSpinnerSnakeType() {
    _spinnerFrameType=  # Reset to force regeneration
    _initSpinner "test" "snake"
    assertEqual "${_spinnerFrameType}" "snake" "frame type should be 'snake'"
}

testInitSpinnerStarType() {
    _spinnerFrameType=  # Reset to force regeneration
    _initSpinner "test" "star"
    assertEqual "${_spinnerFrameType}" "star" "frame type should be 'star'"
}

testInitSpinnerInvalidType() {
    local caught=0
    ( _quietFail=1; _initSpinner "test" "bogus" ) &> /dev/null || caught=1
    (( caught == 1 )) || fail "invalid frame type 'bogus' should have failed"
}

# --- Frame generation ---

testFrameGenerationSnake() {
    _spinnerFrameType=  # Reset to force regeneration
    _initSpinner "test" "snake"
    assertEqual "${_spinnerFramesCount}" "${#_snakeFrames[@]}" "generated frame count should match snake frames"
    (( ${#_spinnerFrames[@]} > 0 )) || fail "spinner frames array should not be empty after generation"
}

testFrameGenerationStar() {
    _spinnerFrameType=  # Reset to force regeneration
    _initSpinner "test" "star"
    assertEqual "${_spinnerFramesCount}" "${#_starFrames[@]}" "generated frame count should match star frames"
    (( ${#_spinnerFrames[@]} > 0 )) || fail "spinner frames array should not be empty after generation"
}

testFrameGenerationCaching() {
    # First call generates frames
    _spinnerFrameType=  # Reset to force regeneration
    _initSpinner "test" "snake"
    local firstCount="${_spinnerFramesCount}"

    # Second call with same type should use cached frames (not regenerate)
    _initSpinner "different message" "snake"
    assertEqual "${_spinnerFramesCount}" "${firstCount}" "frame count should be unchanged on cached call"
    assertEqual "${_spinnerFrameType}" "snake" "frame type should still be 'snake'"
}

testFrameGenerationCustomColors() {
    _spinnerFrameType=  # Reset to force regeneration
    _initSpinner "test" "snake" "red"
    assertEqual "${_spinnerFrameType}" "snake" "frame type should be 'snake'"
    assertEqual "${_spinnerFrameColors[0]}" "red" "custom color should be 'red'"

    # Changing colors should trigger regeneration
    _initSpinner "test" "snake" "blue"
    assertEqual "${_spinnerFrameColors[0]}" "blue" "custom color should now be 'blue'"
}

# --- isInteractive guards ---

testNonInteractiveStartSpinner() {
    # Skip if running interactively
    (( isInteractive )) && return 0
    startSpinner "test"
    [[ -z ${_spinnerPid} ]] || fail "startSpinner should be a no-op when not interactive"
}

testNonInteractiveStopSpinner() {
    # Skip if running interactively
    (( isInteractive )) && return 0
    stopSpinner "test"  # Should return 0 without doing anything
}

testNonInteractiveRestartSpinner() {
    # Skip if running interactively
    (( isInteractive )) && return 0
    restartSpinner "done" "new"  # Should return 0 without doing anything
}

testNonInteractiveReplaceSpinnerAndRestart() {
    # Skip if running interactively
    (( isInteractive )) && return 0
    replaceSpinnerAndRestart "done" "new"  # Should return 0 without doing anything
}

testNonInteractiveStopSpinnerAndEraseLine() {
    # Skip if running interactively
    (( isInteractive )) && return 0
    stopSpinnerAndEraseLine "done"  # Should return 0 without doing anything
}

source rayvn.up 'rayvn/test' 'rayvn/spinner'
main "$@"
