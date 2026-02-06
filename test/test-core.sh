#!/usr/bin/env bash

main() {
    init "$@"

    # Core utility tests
    testAssertCommandSuccess
    testAssertCommandFailure
    testAssertCommandStderr
    testAssertCommandStderrFlag
    testAssertCommandCustomError
    testAssertCommandQuiet
    testAssertCommandStripBrackets
    testAssertCommandWithEval
    testAssertCommandCaptureStdout
    testTrim
    testRepeat
    testPadString
    testStripAnsi
    testContainsAnsi
    testDirName
    testBaseName
    testIndexOf
    testIsMemberOf
    testMaxArrayElementLength
    testVarIsDefined
    testAppendVar
    testNumericPlaces
    testRandomInteger
    testTempDirPath
    testMakeTempFile
    testMakeTempDir
    testAssertValidFileName

    # show() function tests
    testShowBasicUsage
    testShowFormatCombinations
    testShowStylePersistence
    testShowColorReplacement
    testShowPlainResetPattern
    testShowCommandSubstitution
    testShowThemeColors
    testShow256Colors
    testShowRGBColors
    testShowOptions
    testShowEdgeCases
    testShowDocumentedPatterns
    testShowEscapeCodesBasicStyles
    testShowEscapeCodesBasicColors
    testShowEscapeCodesBrightColors
    testShowEscapeCodes256Colors
    testShowEscapeCodesRGBColors
    testShowEscapeCodesStyleCombinations
    testShowEscapeCodesResets
    testShowEscapeCodesComplexPatterns

    printSummary
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

    declare -gi testCount=0
    declare -gi passCount=0
    declare -gi failCount=0
}

# ============================================================================
# Test assertion helpers
# ============================================================================

# Assert with counting (for show tests)
assert() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    (( testCount++ ))

    if [[ ${actual} == "${expected}" ]]; then
        (( passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    else
        (( failCount++ ))
        echo "  ✗ ${testName}"
        echo "    Expected: '${expected}'"
        echo "    Actual:   '${actual}'"
        return 1
    fi
}

assertStripped() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    assert "${testName}" "${expected}" "${ stripAnsi "${actual}"; }"
}

assertEscapeCodes() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    (( testCount++ ))

    if [[ ${actual} == "${expected}" ]]; then
        (( passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    else
        (( failCount++ ))
        echo "  ✗ ${testName}"
        echo "    Expected: '${expected}'"
        echo "    Actual:   '${actual}'"
        echo "    Expected (visible): ${ echo -n "${expected}" | cat -v; }"
        echo "    Actual (visible):   ${ echo -n "${actual}" | cat -v; }"
        return 1
    fi
}

printSummary() {
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Total tests:  ${testCount}"
    echo "Passed:       ${passCount}"
    echo "Failed:       ${failCount}"
    echo ""

    if (( failCount == 0 )); then
        echo "✓ All tests passed!"
        return 0
    else
        fail "${failCount} tests failed"
    fi
}

# ============================================================================
# assertCommand tests
# ============================================================================

testAssertCommandSuccess() {
    assertCommand true
    (( testCount++ )); (( passCount++ ))
    echo "  ✓ assertCommand passes on successful command"
}

testAssertCommandFailure() {
    local failed=0
    ( assertCommand false ) 2>/dev/null || failed=1
    assert "assertCommand fails on command failure" "1" "${failed}"
}

testAssertCommandStderr() {
    assertCommand bash -c 'echo "error" >&2; exit 0'
    (( testCount++ )); (( passCount++ ))
    echo "  ✓ assertCommand ignores stderr without --stderr flag"
}

testAssertCommandStderrFlag() {
    local failed=0
    ( assertCommand --stderr bash -c 'echo "error" >&2; exit 0' ) 2>/dev/null || failed=1
    assert "assertCommand --stderr fails on stderr output" "1" "${failed}"
}

testAssertCommandCustomError() {
    local failed=0
    ( assertCommand --error "Custom error" false ) 2>/dev/null || failed=1
    assert "assertCommand --error fails correctly" "1" "${failed}"
}

testAssertCommandQuiet() {
    local failed=0
    ( assertCommand --stderr --quiet --error "Error" bash -c 'echo "secret" >&2; exit 0' ) 2>/dev/null || failed=1
    assert "assertCommand --quiet --stderr fails on stderr" "1" "${failed}"
}

testAssertCommandStripBrackets() {
    local failed=0
    ( assertCommand --stderr --strip-brackets bash -c 'echo "[info]" >&2; exit 0' ) 2>/dev/null || failed=1
    assert "assertCommand --strip-brackets filters bracket-only lines" "0" "${failed}"
}

testAssertCommandWithEval() {
    local testFile="${ makeTempFile test-XXXXXX; }"
    assertCommand eval 'echo "hello" | cat > "'"${testFile}"'"'
    local content="${ cat "${testFile}"; }"
    assert "assertCommand with eval handles pipelines" "hello" "${content}"
}

testAssertCommandCaptureStdout() {
    local result
    result="${ assertCommand echo "test output"; }"
    assert "assertCommand passes stdout through" "test output" "${result}"
}

# ============================================================================
# String utilities
# ============================================================================

testTrim() {
    assert "trim removes leading/trailing spaces" "hello" "${ trim "  hello  "; }"
    assert "trim leaves clean string alone" "hello" "${ trim "hello"; }"
    assert "trim on only spaces returns empty" "" "${ trim "  "; }"
    assert "trim on empty returns empty" "" "${ trim ""; }"
    assert "trim removes tabs" "tab" "${ trim "	tab	"; }"
    assert "trim preserves internal spaces" "multi  word" "${ trim "  multi  word  "; }"
}

testRepeat() {
    assert "repeat char 5 times" "xxxxx" "${ repeat "x" 5; }"
    assert "repeat string 3 times" "ababab" "${ repeat "ab" 3; }"
    assert "repeat 0 times returns empty" "" "${ repeat "x" 0; }"
    assert "repeat empty string returns empty" "" "${ repeat "" 5; }"
}

testPadString() {
    assert "padString default pads after" "hi   " "${ padString "hi" 5; }"
    assert "padString after pads right" "hi   " "${ padString "hi" 5 after; }"
    assert "padString before pads left" "   hi" "${ padString "hi" 5 before; }"
    assert "padString center pads both" " hi  " "${ padString "hi" 5 center; }"
    assert "padString no-op when string longer" "hello" "${ padString "hello" 3; }"
}

testStripAnsi() {
    local colored=$'\e[31mred\e[0m'
    assert "stripAnsi removes color codes" "red" "${ stripAnsi "${colored}"; }"
    assert "stripAnsi leaves plain text" "plain" "${ stripAnsi "plain"; }"
    local multi=$'\e[1;32mbold green\e[0m'
    assert "stripAnsi handles multi-code" "bold green" "${ stripAnsi "${multi}"; }"
}

testContainsAnsi() {
    local colored=$'\e[31mred\e[0m'
    (( testCount++ ))
    if containsAnsi "${colored}"; then
        (( passCount++ ))
        echo "  ✓ containsAnsi detects ANSI codes"
    else
        (( failCount++ ))
        echo "  ✗ containsAnsi should detect ANSI codes"
    fi

    (( testCount++ ))
    if ! containsAnsi "plain"; then
        (( passCount++ ))
        echo "  ✓ containsAnsi returns false for plain text"
    else
        (( failCount++ ))
        echo "  ✗ containsAnsi should return false for plain text"
    fi
}

# ============================================================================
# Path utilities
# ============================================================================

testDirName() {
    assert "dirName extracts directory" "/path/to" "${ dirName "/path/to/file"; }"
    assert "dirName handles trailing slash" "/path/to" "${ dirName "/path/to/dir/"; }"
    assert "dirName of bare filename is itself" "file" "${ dirName "file"; }"
}

testBaseName() {
    assert "baseName extracts filename" "file" "${ baseName "/path/to/file"; }"
    assert "baseName handles trailing slash" "dir" "${ baseName "/path/to/dir/"; }"
    assert "baseName of bare filename is itself" "file" "${ baseName "file"; }"
}

# ============================================================================
# Array utilities
# ============================================================================

testIndexOf() {
    local arr=("apple" "banana" "cherry")
    assert "indexOf finds element at index 1" "1" "${ indexOf "banana" arr; }"
    assert "indexOf finds element at index 0" "0" "${ indexOf "apple" arr; }"
    assert "indexOf returns -1 for missing" "-1" "${ indexOf "missing" arr; }"
}

testIsMemberOf() {
    local arr=("apple" "banana" "cherry")
    (( testCount++ ))
    if isMemberOf "banana" arr; then
        (( passCount++ ))
        echo "  ✓ isMemberOf finds 'banana'"
    else
        (( failCount++ ))
        echo "  ✗ isMemberOf should find 'banana'"
    fi

    (( testCount++ ))
    if ! isMemberOf "grape" arr; then
        (( passCount++ ))
        echo "  ✓ isMemberOf does not find 'grape'"
    else
        (( failCount++ ))
        echo "  ✗ isMemberOf should not find 'grape'"
    fi
}

testMaxArrayElementLength() {
    local arr=("a" "abc" "ab")
    assert "maxArrayElementLength finds longest" "3" "${ maxArrayElementLength arr; }"
    local empty=()
    assert "maxArrayElementLength of empty is 0" "0" "${ maxArrayElementLength empty; }"
}

# ============================================================================
# Variable utilities
# ============================================================================

testVarIsDefined() {
    local definedVar="value"
    (( testCount++ ))
    if varIsDefined definedVar; then
        (( passCount++ ))
        echo "  ✓ varIsDefined finds defined var"
    else
        (( failCount++ ))
        echo "  ✗ varIsDefined should find defined var"
    fi

    (( testCount++ ))
    if ! varIsDefined undefinedVar; then
        (( passCount++ ))
        echo "  ✓ varIsDefined does not find undefined var"
    else
        (( failCount++ ))
        echo "  ✗ varIsDefined should not find undefined var"
    fi

    local emptyVar=""
    (( testCount++ ))
    if varIsDefined emptyVar; then
        (( passCount++ ))
        echo "  ✓ varIsDefined finds empty var"
    else
        (( failCount++ ))
        echo "  ✗ varIsDefined should find empty var"
    fi
}

testAppendVar() {
    local testVar="first"
    appendVar testVar "second"
    assert "appendVar adds with space separator" "first second" "${testVar}"
    local emptyVar=""
    appendVar emptyVar "only"
    assert "appendVar on empty doesn't add leading space" "only" "${emptyVar}"
}

# ============================================================================
# Numeric utilities
# ============================================================================

testNumericPlaces() {
    assert "numericPlaces for 0-9 is 1 digit" "1" "${ numericPlaces 9; }"
    assert "numericPlaces for 0-10 (adjusted to 9) is 1" "1" "${ numericPlaces 10; }"
    assert "numericPlaces for 0-11 (adjusted to 10) is 2" "2" "${ numericPlaces 11; }"
    assert "numericPlaces for 0-100 (adjusted to 99) is 2" "2" "${ numericPlaces 100; }"
    assert "numericPlaces 1-10 needs 2 digits" "2" "${ numericPlaces 10 1; }"
    assert "numericPlaces 1-9 needs 1 digit" "1" "${ numericPlaces 9 1; }"
}

testRandomInteger() {
    local val
    val=${ randomInteger 10; }
    (( testCount++ ))
    if (( val >= 0 && val <= 10 )); then
        (( passCount++ ))
        echo "  ✓ randomInteger in range 0-10"
    else
        (( failCount++ ))
        echo "  ✗ randomInteger should be in range 0-10, got ${val}"
    fi
    assert "randomInteger with max 0 returns 0" "0" "${ randomInteger 0; }"
}

# ============================================================================
# Temp file utilities
# ============================================================================

testTempDirPath() {
    local path="${ tempDirPath; }"
    (( testCount++ ))
    if [[ -d "${path}" ]]; then
        (( passCount++ ))
        echo "  ✓ tempDirPath returns existing directory"
    else
        (( failCount++ ))
        echo "  ✗ tempDirPath should return existing directory"
    fi

    local subpath="${ tempDirPath "subfile"; }"
    assert "tempDirPath with arg appends" "${path}/subfile" "${subpath}"
}

testMakeTempFile() {
    local file="${ makeTempFile test-XXXXXX; }"
    (( testCount++ ))
    if [[ -f "${file}" ]]; then
        (( passCount++ ))
        echo "  ✓ makeTempFile creates file"
    else
        (( failCount++ ))
        echo "  ✗ makeTempFile should create file"
    fi

    (( testCount++ ))
    if [[ "${file}" == *test-* ]]; then
        (( passCount++ ))
        echo "  ✓ makeTempFile uses template"
    else
        (( failCount++ ))
        echo "  ✗ makeTempFile should use template"
    fi
    rm -f "${file}"
}

testMakeTempDir() {
    local dir="${ makeTempDir testdir-XXXXXX; }"
    (( testCount++ ))
    if [[ -d "${dir}" ]]; then
        (( passCount++ ))
        echo "  ✓ makeTempDir creates directory"
    else
        (( failCount++ ))
        echo "  ✗ makeTempDir should create directory"
    fi

    (( testCount++ ))
    if [[ "${dir}" == *testdir-* ]]; then
        (( passCount++ ))
        echo "  ✓ makeTempDir uses template"
    else
        (( failCount++ ))
        echo "  ✗ makeTempDir should use template"
    fi
    rmdir "${dir}"
}

# ============================================================================
# Validation
# ============================================================================

testAssertValidFileName() {
    assertValidFileName "valid-file.txt"
    assertValidFileName "file_name"
    assertValidFileName "123"
    (( testCount++ )); (( passCount++ ))
    echo "  ✓ assertValidFileName accepts valid names"

    local failed=0
    ( assertValidFileName "" ) 2>/dev/null || failed=1
    assert "assertValidFileName rejects empty" "1" "${failed}"

    failed=0
    ( assertValidFileName "." ) 2>/dev/null || failed=1
    assert "assertValidFileName rejects '.'" "1" "${failed}"

    failed=0
    ( assertValidFileName ".." ) 2>/dev/null || failed=1
    assert "assertValidFileName rejects '..'" "1" "${failed}"

    failed=0
    ( assertValidFileName "path/file" ) 2>/dev/null || failed=1
    assert "assertValidFileName rejects '/'" "1" "${failed}"

    failed=0
    ( assertValidFileName "file:name" ) 2>/dev/null || failed=1
    assert "assertValidFileName rejects ':'" "1" "${failed}"
}

# ============================================================================
# show() function tests
# ============================================================================

testShowBasicUsage() {
    echo ""
    echo "Testing show() Basic Usage"
    echo "=========================="

    local result

    result=${ show blue "text"; }
    assertStripped "Color only: blue" "text" "${result}"

    result=${ show bold "text"; }
    assertStripped "Style only: bold" "text" "${result}"

    result=${ show italic "text"; }
    assertStripped "Style only: italic" "text" "${result}"

    result=${ show dim "text"; }
    assertStripped "Style only: dim" "text" "${result}"

    result=${ show bold blue "text"; }
    assertStripped "Combined: bold blue" "text" "${result}"

    result=${ show italic green "text"; }
    assertStripped "Combined: italic green" "text" "${result}"

    result=${ show "plain text"; }
    assertStripped "Plain text" "plain text" "${result}"

    result=${ show "word1" "word2" "word3"; }
    assertStripped "Multiple plain arguments" "word1 word2 word3" "${result}"
}

testShowFormatCombinations() {
    echo ""
    echo "Testing show() Format Combinations"
    echo "==================================="

    local result

    result=${ show bold italic "text"; }
    assertStripped "Multiple styles: bold italic" "text" "${result}"

    result=${ show bold italic underline "text"; }
    assertStripped "Triple style: bold italic underline" "text" "${result}"

    result=${ show bold italic blue "text"; }
    assertStripped "Color + styles: bold italic blue" "text" "${result}"

    result=${ show dim underline red "text"; }
    assertStripped "Styles + color: dim underline red" "text" "${result}"
}

testShowStylePersistence() {
    echo ""
    echo "Testing show() Style Persistence"
    echo "================================="

    local result

    result=${ show italic "starts italic" blue "still italic, now blue"; }
    assertStripped "Style persists: italic continues" "starts italic still italic, now blue" "${result}"

    result=${ show bold "bold start" "bold continues" "still bold"; }
    assertStripped "Style persists: bold continues" "bold start bold continues still bold" "${result}"

    result=${ show italic "italic" bold "italic+bold" underline "italic+bold+underline"; }
    assertStripped "Styles accumulate" "italic+bold italic+bold+underline" "${result}"
}

testShowColorReplacement() {
    echo ""
    echo "Testing show() Color Replacement"
    echo "================================="

    local result

    result=${ show blue "blue" red "red (replaces blue)"; }
    assertStripped "Color replacement: blue to red" "red (replaces blue)" "${result}"

    result=${ show green "green" yellow "yellow" magenta "magenta"; }
    assertStripped "Multiple color replacements" "" "${result}"

    result=${ show bold blue "bold blue" red "bold red (color replaced)"; }
    assertStripped "Color replacement preserves style" "bold blue bold red (color replaced)" "${result}"
}

testShowPlainResetPattern() {
    echo ""
    echo "Testing show() 'plain' Reset Pattern"
    echo "====================================="

    local result

    result=${ show bold green "styled" plain "back to normal"; }
    assertStripped "Reset after bold+color" "styled back to normal" "${result}"

    result=${ show cyan "colored" plain dim "dimmed, not colored"; }
    assertStripped "Color to style-only: cyan to dim" "colored dimmed, not colored" "${result}"

    result=${ show blue "blue text" plain italic "italic only"; }
    assertStripped "Color to style-only: blue to italic" "blue text italic only" "${result}"

    result=${ show bold blue "heading" plain "text" italic "emphasis"; }
    assertStripped "Reset between combinations" "heading text emphasis" "${result}"

    result=${ show bold "bold" plain "normal" italic "italic" plain "normal again"; }
    assertStripped "Multiple resets" "normal normal again" "${result}"
}

testShowCommandSubstitution() {
    echo ""
    echo "Testing show() Command Substitution"
    echo "===================================="

    local result message

    message="${ show bold "text" ;}"
    assertStripped "Command substitution: basic" "text" "${message}"

    message="${ show bold green "styled text" ;}"
    assertStripped "Command substitution: styled" "styled text" "${message}"

    message="${ show "Start" cyan "middle" plain "end" ;}"
    assertStripped "Command substitution: multiple formats" "Start middle end" "${message}"

    result="${ show green "success" ;}"
    assertStripped "Assignment from substitution" "" "${result}"
}

testShowThemeColors() {
    require 'rayvn/theme'
    echo ""
    echo "Testing show() Theme Colors"
    echo "============================"

    local result

    for themeColor in "${_themeColors[@]}"; do
        result=${ show ${themeColor} "themed text"; }
        assertStripped "Theme color: ${themeColor}" "themed text" "${result}"
    done

    result=${ show bold success "bold success"; }
    assertStripped "Theme + style: bold success" "bold success" "${result}"

    result=${ show italic error "italic error"; }
    assertStripped "Theme + style: italic error" "italic error" "${result}"
}

testShow256Colors() {
    echo ""
    echo "Testing show() 256 Colors"
    echo "========================="

    local result

    result=${ show IDX 196 "red via 256"; }
    assertStripped "256 color: 196 (red)" "red via 256" "${result}"

    result=${ show IDX 46 "green via 256"; }
    assertStripped "256 color: 46 (green)" "green via 256" "${result}"

    result=${ show IDX 0 "color 0"; }
    assertStripped "256 color: 0" "color 0" "${result}"

    result=${ show IDX 255 "color 255"; }
    assertStripped "256 color: 255" "color 255" "${result}"

    result=${ show bold IDX 196 "bold red 256"; }
    assertStripped "256 color with style" "bold red 256" "${result}"

    result=${ show "Start" IDX 196 "'red'" IDX 46 "'green'" "end"; }
    assertStripped "256 colors interleaved" "Start 'red' 'green' end" "${result}"

    result=${ show IDX 256 "text"; }
    assertStripped "Invalid 256 color (256)" "IDX 256 text" "${result}"

    result=${ show IDX 999 "text"; }
    assertStripped "Invalid 256 color (999)" "IDX 999 text" "${result}"

    result=${ show "The answer is" 42 "!"; }
    assertStripped "Numeric value as text" "The answer is 42 !" "${result}"

    result=${ show bold 100 "not a color"; }
    assertStripped "Numeric with style as text" "100 not a color" "${result}"
}

testShowRGBColors() {
    echo ""
    echo "Testing show() RGB Colors"
    echo "========================="

    local result

    result=${ show RGB 52:208:88 "rgb green"; }
    assertStripped "RGB color: green" "rgb green" "${result}"

    result=${ show RGB 215:58:73 "rgb red"; }
    assertStripped "RGB color: red" "rgb red" "${result}"

    result=${ show bold RGB 52:208:88 "bold rgb"; }
    assertStripped "RGB with style" "bold rgb" "${result}"
}

testShowOptions() {
    echo ""
    echo "Testing show() Options"
    echo "======================"

    local result

    result=${ show -n "no newline"; }
    assertStripped "Option -n" "no newline" "${result}"

    result=${ show -n blue "colored no newline"; }
    assertStripped "Option -n with color" "colored no newline" "${result}"

    result=${ show -n -e "options"; }
    assertStripped "Multiple options" "options" "${result}"

    result=${ show -n bold red "formatted no newline"; }
    assertStripped "Options with formats" "formatted no newline" "${result}"
}

testShowEdgeCases() {
    echo ""
    echo "Testing show() Edge Cases"
    echo "========================="

    local result

    result=${ show; }
    assertStripped "No arguments" "" "${result}"

    result=${ show ""; }
    assertStripped "Empty string" "" "${result}"

    result=${ show bold red; }
    assertStripped "Format only, no text" "" "${result}"

    local longText="This is a very long text string that contains many words and should be handled correctly"
    result=${ show green "${longText}"; }
    assertStripped "Very long text" "${longText}" "${result}"

    result=${ show red "text with \$special @chars!"; }
    assertStripped "Special characters" "text with \$special @chars!" "${result}"

    result=${ show red "valid" notaformat "text"; }
    assertStripped "Invalid format as text" "valid notaformat text" "${result}"

    result=${ show bold italic underline dim reverse "all styles"; }
    assertStripped "Many consecutive formats" "all styles" "${result}"

    result=${ show red "A" blue "B" green "C" yellow "D"; }
    assertStripped "Alternating formats/text" "A B C D" "${result}"

    result=${ show "The word red" red "is now red"; }
    assertStripped "Format name in text" "The word red is now red" "${result}"
}

testShowDocumentedPatterns() {
    echo ""
    echo "Testing show() Documented Patterns"
    echo "==================================="

    local result

    result=${ show blue "This is blue text"; }
    assertStripped "Doc example: blue text" "This is blue text" "${result}"

    result=${ show bold red "Bold red text"; }
    assertStripped "Doc example: bold red" "Bold red text" "${result}"

    result=${ show success "Operation completed"; }
    assertStripped "Doc example: success" "Operation completed" "${result}"

    result=${ show italic underline green "Italic underline green text"; }
    assertStripped "Doc example: multi-style green" "Italic underline green text" "${result}"

    result=${ show "Plain text" italic bold blue "italic bold blue text" red "italic bold red" plain blue "blue text"; }
    assertStripped "Doc example: style continuation" "Plain text italic bold blue text italic bold red blue text" "${result}"

    result=${ show cyan "colored text" plain dim "dim text (no color)"; }
    assertStripped "Doc pattern: cyan to dim" "colored text dim text (no color)" "${result}"

    result=${ show bold green "Note" plain "Regular text continues here"; }
    assertStripped "Doc pattern: reset after combo" "Note Regular text continues here" "${result}"

    result=${ show bold blue "heading" plain "text" italic "emphasis"; }
    assertStripped "Doc pattern: transitions" "heading text emphasis" "${result}"
}

testShowEscapeCodesBasicStyles() {
    echo ""
    echo "Testing show() Basic Style Escape Codes"
    echo "========================================"

    local result expected

    result=${ show bold "text"; }
    expected=$'\e[1m'"text"$'\e[0m'
    assertEscapeCodes "Bold escape code" "${expected}" "${result}"

    result=${ show dim "text"; }
    expected=$'\e[2m'"text"$'\e[0m'
    assertEscapeCodes "Dim escape code" "${expected}" "${result}"

    result=${ show italic "text"; }
    expected=$'\e[3m'"text"$'\e[0m'
    assertEscapeCodes "Italic escape code" "${expected}" "${result}"

    result=${ show underline "text"; }
    expected=$'\e[4m'"text"$'\e[0m'
    assertEscapeCodes "Underline escape code" "${expected}" "${result}"

    result=${ show blink "text"; }
    expected=$'\e[5m'"text"$'\e[0m'
    assertEscapeCodes "Blink escape code" "${expected}" "${result}"

    result=${ show reverse "text"; }
    expected=$'\e[7m'"text"$'\e[0m'
    assertEscapeCodes "Reverse escape code" "${expected}" "${result}"
}

testShowEscapeCodesBasicColors() {
    echo ""
    echo "Testing show() Basic Color Escape Codes"
    echo "========================================"

    local result expected

    result=${ show black "text"; }
    expected=$'\e[30m'"text"$'\e[0m'
    assertEscapeCodes "Black escape code" "${expected}" "${result}"

    result=${ show red "text"; }
    expected=$'\e[31m'"text"$'\e[0m'
    assertEscapeCodes "Red escape code" "${expected}" "${result}"

    result=${ show green "text"; }
    expected=$'\e[32m'"text"$'\e[0m'
    assertEscapeCodes "Green escape code" "${expected}" "${result}"

    result=${ show yellow "text"; }
    expected=$'\e[33m'"text"$'\e[0m'
    assertEscapeCodes "Yellow escape code" "${expected}" "${result}"

    result=${ show blue "text"; }
    expected=$'\e[34m'"text"$'\e[0m'
    assertEscapeCodes "Blue escape code" "${expected}" "${result}"

    result=${ show magenta "text"; }
    expected=$'\e[35m'"text"$'\e[0m'
    assertEscapeCodes "Magenta escape code" "${expected}" "${result}"

    result=${ show cyan "text"; }
    expected=$'\e[36m'"text"$'\e[0m'
    assertEscapeCodes "Cyan escape code" "${expected}" "${result}"

    result=${ show white "text"; }
    expected=$'\e[37m'"text"$'\e[0m'
    assertEscapeCodes "White escape code" "${expected}" "${result}"
}

testShowEscapeCodesBrightColors() {
    echo ""
    echo "Testing show() Bright Color Escape Codes"
    echo "========================================="

    local result expected

    result=${ show bright-black "text"; }
    expected=$'\e[90m'"text"$'\e[0m'
    assertEscapeCodes "Bright-black escape code" "${expected}" "${result}"

    result=${ show bright-red "text"; }
    expected=$'\e[91m'"text"$'\e[0m'
    assertEscapeCodes "Bright-red escape code" "${expected}" "${result}"

    result=${ show bright-green "text"; }
    expected=$'\e[92m'"text"$'\e[0m'
    assertEscapeCodes "Bright-green escape code" "${expected}" "${result}"

    result=${ show bright-yellow "text"; }
    expected=$'\e[93m'"text"$'\e[0m'
    assertEscapeCodes "Bright-yellow escape code" "${expected}" "${result}"

    result=${ show bright-blue "text"; }
    expected=$'\e[94m'"text"$'\e[0m'
    assertEscapeCodes "Bright-blue escape code" "${expected}" "${result}"

    result=${ show bright-magenta "text"; }
    expected=$'\e[95m'"text"$'\e[0m'
    assertEscapeCodes "Bright-magenta escape code" "${expected}" "${result}"

    result=${ show bright-cyan "text"; }
    expected=$'\e[96m'"text"$'\e[0m'
    assertEscapeCodes "Bright-cyan escape code" "${expected}" "${result}"

    result=${ show bright-white "text"; }
    expected=$'\e[97m'"text"$'\e[0m'
    assertEscapeCodes "Bright-white escape code" "${expected}" "${result}"
}

testShowEscapeCodes256Colors() {
    echo ""
    echo "Testing show() 256 Color Escape Codes"
    echo "======================================"

    local result expected

    result=${ show IDX 0 "text"; }
    expected=$'\033[38;5;0m'"text"$'\e[0m'
    assertEscapeCodes "256 color: 0" "${expected}" "${result}"

    result=${ show IDX 196 "text"; }
    expected=$'\033[38;5;196m'"text"$'\e[0m'
    assertEscapeCodes "256 color: 196" "${expected}" "${result}"

    result=${ show IDX 46 "text"; }
    expected=$'\033[38;5;46m'"text"$'\e[0m'
    assertEscapeCodes "256 color: 46" "${expected}" "${result}"

    result=${ show IDX 255 "text"; }
    expected=$'\033[38;5;255m'"text"$'\e[0m'
    assertEscapeCodes "256 color: 255" "${expected}" "${result}"

    result=${ show IDX 256 "text"; }
    expected="IDX 256 text"$'\e[0m'
    assertEscapeCodes "Invalid 256 color (256) treated as text" "${expected}" "${result}"

    result=${ show IDX 999 "text"; }
    expected="IDX 999 text"$'\e[0m'
    assertEscapeCodes "Invalid 256 color (999) treated as text" "${expected}" "${result}"

    result=${ show 42 "text"; }
    expected="42 text"$'\e[0m'
    assertEscapeCodes "Numeric value without IDX treated as text" "${expected}" "${result}"
}

testShowEscapeCodesRGBColors() {
    echo ""
    echo "Testing show() RGB Color Escape Codes"
    echo "======================================"

    local result expected

    result=${ show RGB 52:208:88 "text"; }
    expected=$'\e[38;2;52;208;88m'"text"$'\e[0m'
    assertEscapeCodes "RGB color: green (52:208:88)" "${expected}" "${result}"

    result=${ show RGB 215:58:73 "text"; }
    expected=$'\e[38;2;215;58;73m'"text"$'\e[0m'
    assertEscapeCodes "RGB color: red (215:58:73)" "${expected}" "${result}"

    result=${ show RGB 0:0:0 "text"; }
    expected=$'\e[38;2;0;0;0m'"text"$'\e[0m'
    assertEscapeCodes "RGB color: black (0:0:0)" "${expected}" "${result}"

    result=${ show RGB 255:255:255 "text"; }
    expected=$'\e[38;2;255;255;255m'"text"$'\e[0m'
    assertEscapeCodes "RGB color: white (255:255:255)" "${expected}" "${result}"
}

testShowEscapeCodesStyleCombinations() {
    echo ""
    echo "Testing show() Style Combination Escape Codes"
    echo "=============================================="

    local result expected

    result=${ show bold italic "text"; }
    expected=$'\e[1m\e[3m'"text"$'\e[0m'
    assertEscapeCodes "Bold + Italic" "${expected}" "${result}"

    result=${ show bold red "text"; }
    expected=$'\e[1m\e[31m'"text"$'\e[0m'
    assertEscapeCodes "Bold + Red" "${expected}" "${result}"

    result=${ show italic underline green "text"; }
    expected=$'\e[3m\e[4m\e[32m'"text"$'\e[0m'
    assertEscapeCodes "Italic + Underline + Green" "${expected}" "${result}"

    result=${ show bold italic underline "text"; }
    expected=$'\e[1m\e[3m\e[4m'"text"$'\e[0m'
    assertEscapeCodes "Bold + Italic + Underline" "${expected}" "${result}"

    result=${ show bold IDX 196 "text"; }
    expected=$'\e[1m\033[38;5;196m'"text"$'\e[0m'
    assertEscapeCodes "Bold + 256 color (196)" "${expected}" "${result}"

    result=${ show italic RGB 52:208:88 "text"; }
    expected=$'\e[3m\e[38;2;52;208;88m'"text"$'\e[0m'
    assertEscapeCodes "Italic + RGB color" "${expected}" "${result}"

    result=${ show bold italic underline dim reverse "text"; }
    expected=$'\e[1m\e[3m\e[4m\e[2m\e[7m'"text"$'\e[0m'
    assertEscapeCodes "All styles: bold+italic+underline+dim+reverse" "${expected}" "${result}"
}

testShowEscapeCodesResets() {
    echo ""
    echo "Testing show() Reset Escape Codes"
    echo "=================================="

    local result expected

    result=${ show bold green "text1" plain "text2"; }
    expected=$'\e[1m\e[32m'"text1 "$'\e[0m'"text2"$'\e[0m'
    assertEscapeCodes "Plain resets formatting" "${expected}" "${result}"

    result=${ show blue "text1" plain italic "text2"; }
    expected=$'\e[34m'"text1 "$'\e[0m\e[3m'"text2"$'\e[0m'
    assertEscapeCodes "Plain between color and style" "${expected}" "${result}"

    result=${ show bold "text1" plain "text2" plain "text3"; }
    expected=$'\e[1m'"text1 "$'\e[0m'"text2 "$'\e[0m'"text3"$'\e[0m'
    assertEscapeCodes "Multiple plain resets" "${expected}" "${result}"

    result=${ show bold red "text"; }
    expected=$'\e[1m\e[31m'"text"$'\e[0m'
    assertEscapeCodes "Final reset code present" "${expected}" "${result}"

    result=${ show; }
    expected=''
    assertEscapeCodes "No arguments produces empty output" "${expected}" "${result}"

    result=${ show bold red; }
    expected=$'\e[0m'
    assertEscapeCodes "Format only produces only reset" "${expected}" "${result}"
}

testShowEscapeCodesComplexPatterns() {
    echo ""
    echo "Testing show() Complex Pattern Escape Codes"
    echo "============================================"

    local result expected

    result=${ show italic "text1" blue "text2"; }
    expected=$'\e[3m'"text1 "$'\e[34m'"text2"$'\e[0m'
    assertEscapeCodes "Style persistence with color change" "${expected}" "${result}"

    result=${ show bold blue "text1" red "text2"; }
    expected=$'\e[1m\e[34m'"text1 "$'\e[31m'"text2"$'\e[0m'
    assertEscapeCodes "Color replacement with style persistence" "${expected}" "${result}"

    result=${ show "text1" bold "text2" italic "text3"; }
    expected="text1 "$'\e[1m'"text2 "$'\e[3m'"text3"$'\e[0m'
    assertEscapeCodes "Accumulating styles across arguments" "${expected}" "${result}"

    result=${ show bold green "text1" plain dim "text2"; }
    expected=$'\e[1m\e[32m'"text1 "$'\e[0m\e[2m'"text2"$'\e[0m'
    assertEscapeCodes "Reset then new style" "${expected}" "${result}"

    result=${ show cyan "colored text" plain dim "dim text"; }
    expected=$'\e[36m'"colored text "$'\e[0m\e[2m'"dim text"$'\e[0m'
    assertEscapeCodes "Cyan to dim via plain" "${expected}" "${result}"

    result=${ show red "A" blue "B" green "C"; }
    expected=$'\e[31m'"A "$'\e[34m'"B "$'\e[32m'"C"$'\e[0m'
    assertEscapeCodes "Multiple color changes" "${expected}" "${result}"
}

# Force 24-bit color mode if not running in a terminal
[[ -t 1 && -t 2 ]] || declare -gx rayvnTest_Force24BitColor=1

source rayvn.up 'rayvn/core' 'rayvn/test'
main "$@"
