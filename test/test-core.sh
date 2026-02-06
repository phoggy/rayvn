#!/usr/bin/env bash

main() {
    init "$@"

    testAssertCommandSuccess
    testAssertCommandFailure
    testAssertCommandStderr
    testAssertCommandStderrFlag
    testAssertCommandCustomError
    testAssertCommandQuiet
    testAssertCommandStripBrackets
    testAssertCommandWithEval
    testAssertCommandCaptureStdout

    return 0
}

init() {
    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${terminal}" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done
}

testAssertCommandSuccess() {
    # Command that succeeds should pass
    assertCommand true
    echo "  assertCommand passes on successful command"
}

testAssertCommandFailure() {
    # Command that fails should call fail()
    local failed=0
    ( assertCommand false ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertCommand fails on command failure"
}

testAssertCommandStderr() {
    # Without --stderr, command with stderr but exit 0 should pass
    assertCommand bash -c 'echo "error" >&2; exit 0'
    echo "  assertCommand ignores stderr without --stderr flag"
}

testAssertCommandStderrFlag() {
    # With --stderr, command with stderr should fail even with exit 0
    local failed=0
    ( assertCommand --stderr bash -c 'echo "error" >&2; exit 0' ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertCommand --stderr fails on stderr output"
}

testAssertCommandCustomError() {
    # Custom error message should work (just verify it doesn't crash)
    local failed=0
    ( assertCommand --error "Custom error" false ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertCommand --error fails correctly"
}

testAssertCommandQuiet() {
    # With --quiet, should still fail on stderr but not crash
    local failed=0
    ( assertCommand --stderr --quiet --error "Error" bash -c 'echo "secret" >&2; exit 0' ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertCommand --quiet --stderr fails on stderr"
}

testAssertCommandStripBrackets() {
    # --strip-brackets should filter out [text] lines from stderr
    local failed=0
    # Only bracket lines, should not fail
    ( assertCommand --stderr --strip-brackets bash -c 'echo "[info]" >&2; exit 0' ) 2>/dev/null || failed=1
    assertEqual "${failed}" "0" "assertCommand --strip-brackets filters bracket-only lines"
}

testAssertCommandWithEval() {
    # eval should work for pipelines
    local testFile="${ makeTempFile test-XXXXXX; }"
    assertCommand eval 'echo "hello" | cat > "'"${testFile}"'"'
    local content="${ cat "${testFile}"; }"
    assertEqual "${content}" "hello" "assertCommand with eval handles pipelines"
}

testAssertCommandCaptureStdout() {
    # stdout should pass through for command substitution
    local result
    result="${ assertCommand echo "test output"; }"
    assertEqual "${result}" "test output" "assertCommand passes stdout through"
}

source rayvn.up 'rayvn/test'
main "$@"
