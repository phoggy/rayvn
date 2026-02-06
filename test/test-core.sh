#!/usr/bin/env bash

main() {
    init "$@"

    # assertCommand tests
    testAssertCommandSuccess
    testAssertCommandFailure
    testAssertCommandStderr
    testAssertCommandStderrFlag
    testAssertCommandCustomError
    testAssertCommandQuiet
    testAssertCommandStripBrackets
    testAssertCommandWithEval
    testAssertCommandCaptureStdout

    # String utilities
    testTrim
    testRepeat
    testPadString
    testStripAnsi
    testContainsAnsi

    # Path utilities
    testDirName
    testBaseName

    # Array utilities
    testIndexOf
    testIsMemberOf
    testMaxArrayElementLength

    # Variable utilities
    testVarIsDefined
    testAppendVar

    # Numeric utilities
    testNumericPlaces
    testRandomInteger

    # Temp file utilities
    testTempDirPath
    testMakeTempFile
    testMakeTempDir

    # Validation
    testAssertValidFileName

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

# ============================================================================
# String utilities
# ============================================================================

testTrim() {
    assertEqual "${ trim "  hello  "; }" "hello" "trim removes leading/trailing spaces"
    assertEqual "${ trim "hello"; }" "hello" "trim leaves clean string alone"
    assertEqual "${ trim "  "; }" "" "trim on only spaces returns empty"
    assertEqual "${ trim ""; }" "" "trim on empty returns empty"
    assertEqual "${ trim "	tab	"; }" "tab" "trim removes tabs"
    assertEqual "${ trim "  multi  word  "; }" "multi  word" "trim preserves internal spaces"
}

testRepeat() {
    assertEqual "${ repeat "x" 5; }" "xxxxx" "repeat char 5 times"
    assertEqual "${ repeat "ab" 3; }" "ababab" "repeat string 3 times"
    assertEqual "${ repeat "x" 0; }" "" "repeat 0 times returns empty"
    assertEqual "${ repeat "" 5; }" "" "repeat empty string returns empty"
}

testPadString() {
    assertEqual "${ padString "hi" 5; }" "hi   " "padString default pads after"
    assertEqual "${ padString "hi" 5 after; }" "hi   " "padString after pads right"
    assertEqual "${ padString "hi" 5 before; }" "   hi" "padString before pads left"
    assertEqual "${ padString "hi" 5 center; }" " hi  " "padString center pads both"
    assertEqual "${ padString "hello" 3; }" "hello" "padString no-op when string longer"
}

testStripAnsi() {
    local colored=$'\e[31mred\e[0m'
    assertEqual "${ stripAnsi "${colored}"; }" "red" "stripAnsi removes color codes"
    assertEqual "${ stripAnsi "plain"; }" "plain" "stripAnsi leaves plain text"
    local multi=$'\e[1;32mbold green\e[0m'
    assertEqual "${ stripAnsi "${multi}"; }" "bold green" "stripAnsi handles multi-code"
}

testContainsAnsi() {
    local colored=$'\e[31mred\e[0m'
    containsAnsi "${colored}" || fail "containsAnsi should detect ANSI codes"
    ! containsAnsi "plain" || fail "containsAnsi should return false for plain text"
    echo "  containsAnsi works correctly"
}

# ============================================================================
# Path utilities
# ============================================================================

testDirName() {
    assertEqual "${ dirName "/path/to/file"; }" "/path/to" "dirName extracts directory"
    assertEqual "${ dirName "/path/to/dir/"; }" "/path/to" "dirName handles trailing slash"
    assertEqual "${ dirName "file"; }" "file" "dirName of bare filename is itself"
}

testBaseName() {
    assertEqual "${ baseName "/path/to/file"; }" "file" "baseName extracts filename"
    assertEqual "${ baseName "/path/to/dir/"; }" "dir" "baseName handles trailing slash"
    assertEqual "${ baseName "file"; }" "file" "baseName of bare filename is itself"
}

# ============================================================================
# Array utilities
# ============================================================================

testIndexOf() {
    local arr=("apple" "banana" "cherry")
    assertEqual "${ indexOf "banana" arr; }" "1" "indexOf finds element at index 1"
    assertEqual "${ indexOf "apple" arr; }" "0" "indexOf finds element at index 0"
    assertEqual "${ indexOf "missing" arr; }" "-1" "indexOf returns -1 for missing"
}

testIsMemberOf() {
    local arr=("apple" "banana" "cherry")
    isMemberOf "banana" arr || fail "isMemberOf should find 'banana'"
    ! isMemberOf "grape" arr || fail "isMemberOf should not find 'grape'"
    echo "  isMemberOf works correctly"
}

testMaxArrayElementLength() {
    local arr=("a" "abc" "ab")
    assertEqual "${ maxArrayElementLength arr; }" "3" "maxArrayElementLength finds longest"
    local empty=()
    assertEqual "${ maxArrayElementLength empty; }" "0" "maxArrayElementLength of empty is 0"
}

# ============================================================================
# Variable utilities
# ============================================================================

testVarIsDefined() {
    local definedVar="value"
    varIsDefined definedVar || fail "varIsDefined should find defined var"
    ! varIsDefined undefinedVar || fail "varIsDefined should not find undefined var"
    local emptyVar=""
    varIsDefined emptyVar || fail "varIsDefined should find empty var"
    echo "  varIsDefined works correctly"
}

testAppendVar() {
    local testVar="first"
    appendVar testVar "second"
    assertEqual "${testVar}" "first second" "appendVar adds with space separator"
    local emptyVar=""
    appendVar emptyVar "only"
    assertEqual "${emptyVar}" "only" "appendVar on empty doesn't add leading space"
}

# ============================================================================
# Numeric utilities
# ============================================================================

testNumericPlaces() {
    # numericPlaces calculates digits needed for range [startValue, maxValue]
    # Default startValue is 0, so it adjusts maxValue by -1
    assertEqual "${ numericPlaces 9; }" "1" "numericPlaces for 0-9 is 1 digit"
    assertEqual "${ numericPlaces 10; }" "1" "numericPlaces for 0-10 (adjusted to 9) is 1"
    assertEqual "${ numericPlaces 11; }" "2" "numericPlaces for 0-11 (adjusted to 10) is 2"
    assertEqual "${ numericPlaces 100; }" "2" "numericPlaces for 0-100 (adjusted to 99) is 2"
    assertEqual "${ numericPlaces 10 1; }" "2" "numericPlaces 1-10 needs 2 digits"
    assertEqual "${ numericPlaces 9 1; }" "1" "numericPlaces 1-9 needs 1 digit"
}

testRandomInteger() {
    local val
    val=${ randomInteger 10; }
    (( val >= 0 && val <= 10 )) || fail "randomInteger should be in range 0-10, got ${val}"
    val=${ randomInteger 0; }
    assertEqual "${val}" "0" "randomInteger with max 0 returns 0"
    echo "  randomInteger works correctly"
}

# ============================================================================
# Temp file utilities
# ============================================================================

testTempDirPath() {
    local path="${ tempDirPath; }"
    [[ -d "${path}" ]] || fail "tempDirPath should return existing directory"
    local subpath="${ tempDirPath "subfile"; }"
    [[ "${subpath}" == "${path}/subfile" ]] || fail "tempDirPath with arg should append"
    echo "  tempDirPath works correctly"
}

testMakeTempFile() {
    local file="${ makeTempFile test-XXXXXX; }"
    [[ -f "${file}" ]] || fail "makeTempFile should create file"
    [[ "${file}" == *test-* ]] || fail "makeTempFile should use template"
    rm -f "${file}"
    echo "  makeTempFile works correctly"
}

testMakeTempDir() {
    local dir="${ makeTempDir testdir-XXXXXX; }"
    [[ -d "${dir}" ]] || fail "makeTempDir should create directory"
    [[ "${dir}" == *testdir-* ]] || fail "makeTempDir should use template"
    rmdir "${dir}"
    echo "  makeTempDir works correctly"
}

# ============================================================================
# Validation
# ============================================================================

testAssertValidFileName() {
    # Valid names should pass
    assertValidFileName "valid-file.txt"
    assertValidFileName "file_name"
    assertValidFileName "123"

    # Invalid names should fail
    local failed=0
    ( assertValidFileName "" ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertValidFileName rejects empty"

    failed=0
    ( assertValidFileName "." ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertValidFileName rejects '.'"

    failed=0
    ( assertValidFileName ".." ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertValidFileName rejects '..'"

    failed=0
    ( assertValidFileName "path/file" ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertValidFileName rejects '/'"

    failed=0
    ( assertValidFileName "file:name" ) 2>/dev/null || failed=1
    assertEqual "${failed}" "1" "assertValidFileName rejects ':'"
}

source rayvn.up 'rayvn/test'
main "$@"
