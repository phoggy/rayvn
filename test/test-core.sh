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

    endTest
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

    beginTest
}

# ============================================================================
# assertCommand tests
# ============================================================================

testAssertCommandSuccess() {
    assertTrue "assertCommand passes on successful command" assertCommand true
}

testAssertCommandFailure() {
    assertFalse "assertCommand fails on command failure" eval '( assertCommand false ) 2>/dev/null'
}

testAssertCommandStderr() {
    assertTrue "assertCommand ignores stderr without --stderr flag" \
        assertCommand bash -c 'echo "error" >&2; exit 0'
}

testAssertCommandStderrFlag() {
    assertFalse "assertCommand --stderr fails on stderr output" \
        eval '( assertCommand --stderr bash -c '\''echo "error" >&2; exit 0'\'' ) 2>/dev/null'
}

testAssertCommandCustomError() {
    assertFalse "assertCommand --error fails correctly" \
        eval '( assertCommand --error "Custom error" false ) 2>/dev/null'
}

testAssertCommandQuiet() {
    assertFalse "assertCommand --quiet --stderr fails on stderr" \
        eval '( assertCommand --stderr --quiet --error "Error" bash -c '\''echo "secret" >&2; exit 0'\'' ) 2>/dev/null'
}

testAssertCommandStripBrackets() {
    assertTrue "assertCommand --strip-brackets filters bracket-only lines" \
        eval '( assertCommand --stderr --strip-brackets bash -c '\''echo "[info]" >&2; exit 0'\'' ) 2>/dev/null'
}

testAssertCommandWithEval() {
    local testFile="${ makeTempFile test-XXXXXX; }"
    assertCommand eval 'echo "hello" | cat > "'"${testFile}"'"'
    local content="${ cat "${testFile}"; }"
    assertEqual "assertCommand with eval handles pipelines" "hello" "${content}"
}

testAssertCommandCaptureStdout() {
    local result
    result="${ assertCommand echo "test output"; }"
    assertEqual "assertCommand passes stdout through" "test output" "${result}"
}

# ============================================================================
# String utilities
# ============================================================================

testTrim() {
    assertEqual "trim removes leading/trailing spaces" "hello" "${ trim "  hello  "; }"
    assertEqual "trim leaves clean string alone" "hello" "${ trim "hello"; }"
    assertEqual "trim on only spaces returns empty" "" "${ trim "  "; }"
    assertEqual "trim on empty returns empty" "" "${ trim ""; }"
    assertEqual "trim removes tabs" "tab" "${ trim "	tab	"; }"
    assertEqual "trim preserves internal spaces" "multi  word" "${ trim "  multi  word  "; }"
}

testRepeat() {
    assertEqual "repeat char 5 times" "xxxxx" "${ repeat "x" 5; }"
    assertEqual "repeat string 3 times" "ababab" "${ repeat "ab" 3; }"
    assertEqual "repeat 0 times returns empty" "" "${ repeat "x" 0; }"
    assertEqual "repeat empty string returns empty" "" "${ repeat "" 5; }"
}

testPadString() {
    assertEqual "padString default pads after" "hi   " "${ padString "hi" 5; }"
    assertEqual "padString after pads right" "hi   " "${ padString "hi" 5 after; }"
    assertEqual "padString before pads left" "   hi" "${ padString "hi" 5 before; }"
    assertEqual "padString center pads both" " hi  " "${ padString "hi" 5 center; }"
    assertEqual "padString no-op when string longer" "hello" "${ padString "hello" 3; }"
}

testStripAnsi() {
    local colored=$'\e[31mred\e[0m'
    assertEqual "stripAnsi removes color codes" "red" "${ stripAnsi "${colored}"; }"
    assertEqual "stripAnsi leaves plain text" "plain" "${ stripAnsi "plain"; }"
    local multi=$'\e[1;32mbold green\e[0m'
    assertEqual "stripAnsi handles multi-code" "bold green" "${ stripAnsi "${multi}"; }"
}

testContainsAnsi() {
    local colored=$'\e[31mred\e[0m'
    assertTrue "containsAnsi detects ANSI codes" containsAnsi "${colored}"
    assertFalse "containsAnsi returns false for plain text" containsAnsi "plain"
}

# ============================================================================
# Path utilities
# ============================================================================

testDirName() {
    assertEqual "dirName extracts directory" "/path/to" "${ dirName "/path/to/file"; }"
    assertEqual "dirName handles trailing slash" "/path/to" "${ dirName "/path/to/dir/"; }"
    assertEqual "dirName of bare filename is itself" "file" "${ dirName "file"; }"
}

testBaseName() {
    assertEqual "baseName extracts filename" "file" "${ baseName "/path/to/file"; }"
    assertEqual "baseName handles trailing slash" "dir" "${ baseName "/path/to/dir/"; }"
    assertEqual "baseName of bare filename is itself" "file" "${ baseName "file"; }"
}

# ============================================================================
# Array utilities
# ============================================================================

testIndexOf() {
    local arr=("apple" "banana" "cherry")
    assertEqual "indexOf finds element at index 1" "1" "${ indexOf "banana" arr; }"
    assertEqual "indexOf finds element at index 0" "0" "${ indexOf "apple" arr; }"
    assertEqual "indexOf returns -1 for missing" "-1" "${ indexOf "missing" arr; }"
}

testIsMemberOf() {
    local arr=("apple" "banana" "cherry")
    assertTrue "isMemberOf finds 'banana'" isMemberOf "banana" arr
    assertFalse "isMemberOf does not find 'grape'" isMemberOf "grape" arr
}

testMaxArrayElementLength() {
    local arr=("a" "abc" "ab")
    assertEqual "maxArrayElementLength finds longest" "3" "${ maxArrayElementLength arr; }"
    local empty=()
    assertEqual "maxArrayElementLength of empty is 0" "0" "${ maxArrayElementLength empty; }"
}

# ============================================================================
# Variable utilities
# ============================================================================

testVarIsDefined() {
    local definedVar="value"
    assertTrue "varIsDefined finds defined var" varIsDefined definedVar
    assertFalse "varIsDefined does not find undefined var" varIsDefined undefinedVar
    local emptyVar=""
    assertTrue "varIsDefined finds empty var" varIsDefined emptyVar
}

testAppendVar() {
    local testVar="first"
    appendVar testVar "second"
    assertEqual "appendVar adds with space separator" "first second" "${testVar}"
    local emptyVar=""
    appendVar emptyVar "only"
    assertEqual "appendVar on empty doesn't add leading space" "only" "${emptyVar}"
}

# ============================================================================
# Numeric utilities
# ============================================================================

testNumericPlaces() {
    assertEqual "numericPlaces for 0-9 is 1 digit" "1" "${ numericPlaces 9; }"
    assertEqual "numericPlaces for 0-10 (adjusted to 9) is 1" "1" "${ numericPlaces 10; }"
    assertEqual "numericPlaces for 0-11 (adjusted to 10) is 2" "2" "${ numericPlaces 11; }"
    assertEqual "numericPlaces for 0-100 (adjusted to 99) is 2" "2" "${ numericPlaces 100; }"
    assertEqual "numericPlaces 1-10 needs 2 digits" "2" "${ numericPlaces 10 1; }"
    assertEqual "numericPlaces 1-9 needs 1 digit" "1" "${ numericPlaces 9 1; }"
}

testRandomInteger() {
    local val
    val=${ randomInteger 10; }
    assertInRange "randomInteger in range 0-10" "${val}" 0 10
    assertEqual "randomInteger with max 0 returns 0" "0" "${ randomInteger 0; }"
}

# ============================================================================
# Temp file utilities
# ============================================================================

testTempDirPath() {
    local path="${ tempDirPath; }"
    assertTrue "tempDirPath returns existing directory" test -d "${path}"

    local subpath="${ tempDirPath "subfile"; }"
    assertEqual "tempDirPath with arg appends" "${path}/subfile" "${subpath}"
}

testMakeTempFile() {
    local file="${ makeTempFile test-XXXXXX; }"
    assertTrue "makeTempFile creates file" test -f "${file}"
    assertContains "makeTempFile uses template" "test-" "${file}"
    rm -f "${file}"
}

testMakeTempDir() {
    local dir="${ makeTempDir testdir-XXXXXX; }"
    assertTrue "makeTempDir creates directory" test -d "${dir}"
    assertContains "makeTempDir uses template" "testdir-" "${dir}"
    rmdir "${dir}"
}

# ============================================================================
# Validation
# ============================================================================

testAssertValidFileName() {
    assertTrue "assertValidFileName accepts 'valid-file.txt'" assertValidFileName "valid-file.txt"
    assertTrue "assertValidFileName accepts 'file_name'" assertValidFileName "file_name"
    assertTrue "assertValidFileName accepts '123'" assertValidFileName "123"

    assertFalse "assertValidFileName rejects empty" \
        eval '( assertValidFileName "" ) 2>/dev/null'

    assertFalse "assertValidFileName rejects '.'" \
        eval '( assertValidFileName "." ) 2>/dev/null'

    assertFalse "assertValidFileName rejects '..'" \
        eval '( assertValidFileName ".." ) 2>/dev/null'

    assertFalse "assertValidFileName rejects '/'" \
        eval '( assertValidFileName "path/file" ) 2>/dev/null'

    assertFalse "assertValidFileName rejects ':'" \
        eval '( assertValidFileName "file:name" ) 2>/dev/null'
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
    assertEqualStripped "Color only: blue" "text" "${result}"

    result=${ show bold "text"; }
    assertEqualStripped "Style only: bold" "text" "${result}"

    result=${ show italic "text"; }
    assertEqualStripped "Style only: italic" "text" "${result}"

    result=${ show dim "text"; }
    assertEqualStripped "Style only: dim" "text" "${result}"

    result=${ show bold blue "text"; }
    assertEqualStripped "Combined: bold blue" "text" "${result}"

    result=${ show italic green "text"; }
    assertEqualStripped "Combined: italic green" "text" "${result}"

    result=${ show "plain text"; }
    assertEqualStripped "Plain text" "plain text" "${result}"

    result=${ show "word1" "word2" "word3"; }
    assertEqualStripped "Multiple plain arguments" "word1 word2 word3" "${result}"
}

testShowFormatCombinations() {
    echo ""
    echo "Testing show() Format Combinations"
    echo "==================================="

    local result

    result=${ show bold italic "text"; }
    assertEqualStripped "Multiple styles: bold italic" "text" "${result}"

    result=${ show bold italic underline "text"; }
    assertEqualStripped "Triple style: bold italic underline" "text" "${result}"

    result=${ show bold italic blue "text"; }
    assertEqualStripped "Color + styles: bold italic blue" "text" "${result}"

    result=${ show dim underline red "text"; }
    assertEqualStripped "Styles + color: dim underline red" "text" "${result}"
}

testShowStylePersistence() {
    echo ""
    echo "Testing show() Style Persistence"
    echo "================================="

    local result

    result=${ show italic "starts italic" blue "still italic, now blue"; }
    assertEqualStripped "Style persists: italic continues" "starts italic still italic, now blue" "${result}"

    result=${ show bold "bold start" "bold continues" "still bold"; }
    assertEqualStripped "Style persists: bold continues" "bold start bold continues still bold" "${result}"

    result=${ show italic "italic" bold "italic+bold" underline "italic+bold+underline"; }
    assertEqualStripped "Styles accumulate" "italic+bold italic+bold+underline" "${result}"
}

testShowColorReplacement() {
    echo ""
    echo "Testing show() Color Replacement"
    echo "================================="

    local result

    result=${ show blue "blue" red "red (replaces blue)"; }
    assertEqualStripped "Color replacement: blue to red" "red (replaces blue)" "${result}"

    result=${ show green "green" yellow "yellow" magenta "magenta"; }
    assertEqualStripped "Multiple color replacements" "" "${result}"

    result=${ show bold blue "bold blue" red "bold red (color replaced)"; }
    assertEqualStripped "Color replacement preserves style" "bold blue bold red (color replaced)" "${result}"
}

testShowPlainResetPattern() {
    echo ""
    echo "Testing show() 'plain' Reset Pattern"
    echo "====================================="

    local result

    result=${ show bold green "styled" plain "back to normal"; }
    assertEqualStripped "Reset after bold+color" "styled back to normal" "${result}"

    result=${ show cyan "colored" plain dim "dimmed, not colored"; }
    assertEqualStripped "Color to style-only: cyan to dim" "colored dimmed, not colored" "${result}"

    result=${ show blue "blue text" plain italic "italic only"; }
    assertEqualStripped "Color to style-only: blue to italic" "blue text italic only" "${result}"

    result=${ show bold blue "heading" plain "text" italic "emphasis"; }
    assertEqualStripped "Reset between combinations" "heading text emphasis" "${result}"

    result=${ show bold "bold" plain "normal" italic "italic" plain "normal again"; }
    assertEqualStripped "Multiple resets" "normal normal again" "${result}"
}

testShowCommandSubstitution() {
    echo ""
    echo "Testing show() Command Substitution"
    echo "===================================="

    local result message

    message="${ show bold "text" ;}"
    assertEqualStripped "Command substitution: basic" "text" "${message}"

    message="${ show bold green "styled text" ;}"
    assertEqualStripped "Command substitution: styled" "styled text" "${message}"

    message="${ show "Start" cyan "middle" plain "end" ;}"
    assertEqualStripped "Command substitution: multiple formats" "Start middle end" "${message}"

    result="${ show green "success" ;}"
    assertEqualStripped "Assignment from substitution" "" "${result}"
}

testShowThemeColors() {
    require 'rayvn/theme'
    echo ""
    echo "Testing show() Theme Colors"
    echo "============================"

    local result

    for themeColor in "${_themeColors[@]}"; do
        result=${ show ${themeColor} "themed text"; }
        assertEqualStripped "Theme color: ${themeColor}" "themed text" "${result}"
    done

    result=${ show bold success "bold success"; }
    assertEqualStripped "Theme + style: bold success" "bold success" "${result}"

    result=${ show italic error "italic error"; }
    assertEqualStripped "Theme + style: italic error" "italic error" "${result}"
}

testShow256Colors() {
    echo ""
    echo "Testing show() 256 Colors"
    echo "========================="

    local result

    result=${ show IDX 196 "red via 256"; }
    assertEqualStripped "256 color: 196 (red)" "red via 256" "${result}"

    result=${ show IDX 46 "green via 256"; }
    assertEqualStripped "256 color: 46 (green)" "green via 256" "${result}"

    result=${ show IDX 0 "color 0"; }
    assertEqualStripped "256 color: 0" "color 0" "${result}"

    result=${ show IDX 255 "color 255"; }
    assertEqualStripped "256 color: 255" "color 255" "${result}"

    result=${ show bold IDX 196 "bold red 256"; }
    assertEqualStripped "256 color with style" "bold red 256" "${result}"

    result=${ show "Start" IDX 196 "'red'" IDX 46 "'green'" "end"; }
    assertEqualStripped "256 colors interleaved" "Start 'red' 'green' end" "${result}"

    result=${ show IDX 256 "text"; }
    assertEqualStripped "Invalid 256 color (256)" "IDX 256 text" "${result}"

    result=${ show IDX 999 "text"; }
    assertEqualStripped "Invalid 256 color (999)" "IDX 999 text" "${result}"

    result=${ show "The answer is" 42 "!"; }
    assertEqualStripped "Numeric value as text" "The answer is 42 !" "${result}"

    result=${ show bold 100 "not a color"; }
    assertEqualStripped "Numeric with style as text" "100 not a color" "${result}"
}

testShowRGBColors() {
    echo ""
    echo "Testing show() RGB Colors"
    echo "========================="

    local result

    result=${ show RGB 52:208:88 "rgb green"; }
    assertEqualStripped "RGB color: green" "rgb green" "${result}"

    result=${ show RGB 215:58:73 "rgb red"; }
    assertEqualStripped "RGB color: red" "rgb red" "${result}"

    result=${ show bold RGB 52:208:88 "bold rgb"; }
    assertEqualStripped "RGB with style" "bold rgb" "${result}"
}

testShowOptions() {
    echo ""
    echo "Testing show() Options"
    echo "======================"

    local result

    result=${ show -n "no newline"; }
    assertEqualStripped "Option -n" "no newline" "${result}"

    result=${ show -n blue "colored no newline"; }
    assertEqualStripped "Option -n with color" "colored no newline" "${result}"

    result=${ show -n -e "options"; }
    assertEqualStripped "Multiple options" "options" "${result}"

    result=${ show -n bold red "formatted no newline"; }
    assertEqualStripped "Options with formats" "formatted no newline" "${result}"
}

testShowEdgeCases() {
    echo ""
    echo "Testing show() Edge Cases"
    echo "========================="

    local result

    result=${ show; }
    assertEqualStripped "No arguments" "" "${result}"

    result=${ show ""; }
    assertEqualStripped "Empty string" "" "${result}"

    result=${ show bold red; }
    assertEqualStripped "Format only, no text" "" "${result}"

    local longText="This is a very long text string that contains many words and should be handled correctly"
    result=${ show green "${longText}"; }
    assertEqualStripped "Very long text" "${longText}" "${result}"

    result=${ show red "text with \$special @chars!"; }
    assertEqualStripped "Special characters" "text with \$special @chars!" "${result}"

    result=${ show red "valid" notaformat "text"; }
    assertEqualStripped "Invalid format as text" "valid notaformat text" "${result}"

    result=${ show bold italic underline dim reverse "all styles"; }
    assertEqualStripped "Many consecutive formats" "all styles" "${result}"

    result=${ show red "A" blue "B" green "C" yellow "D"; }
    assertEqualStripped "Alternating formats/text" "A B C D" "${result}"

    result=${ show "The word red" red "is now red"; }
    assertEqualStripped "Format name in text" "The word red is now red" "${result}"
}

testShowDocumentedPatterns() {
    echo ""
    echo "Testing show() Documented Patterns"
    echo "==================================="

    local result

    result=${ show blue "This is blue text"; }
    assertEqualStripped "Doc example: blue text" "This is blue text" "${result}"

    result=${ show bold red "Bold red text"; }
    assertEqualStripped "Doc example: bold red" "Bold red text" "${result}"

    result=${ show success "Operation completed"; }
    assertEqualStripped "Doc example: success" "Operation completed" "${result}"

    result=${ show italic underline green "Italic underline green text"; }
    assertEqualStripped "Doc example: multi-style green" "Italic underline green text" "${result}"

    result=${ show "Plain text" italic bold blue "italic bold blue text" red "italic bold red" plain blue "blue text"; }
    assertEqualStripped "Doc example: style continuation" "Plain text italic bold blue text italic bold red blue text" "${result}"

    result=${ show cyan "colored text" plain dim "dim text (no color)"; }
    assertEqualStripped "Doc pattern: cyan to dim" "colored text dim text (no color)" "${result}"

    result=${ show bold green "Note" plain "Regular text continues here"; }
    assertEqualStripped "Doc pattern: reset after combo" "Note Regular text continues here" "${result}"

    result=${ show bold blue "heading" plain "text" italic "emphasis"; }
    assertEqualStripped "Doc pattern: transitions" "heading text emphasis" "${result}"
}

testShowEscapeCodesBasicStyles() {
    echo ""
    echo "Testing show() Basic Style Escape Codes"
    echo "========================================"

    local result expected

    result=${ show bold "text"; }
    expected=$'\e[1m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bold escape code" "${expected}" "${result}"

    result=${ show dim "text"; }
    expected=$'\e[2m'"text"$'\e[0m'
    assertEqualEscapeCodes "Dim escape code" "${expected}" "${result}"

    result=${ show italic "text"; }
    expected=$'\e[3m'"text"$'\e[0m'
    assertEqualEscapeCodes "Italic escape code" "${expected}" "${result}"

    result=${ show underline "text"; }
    expected=$'\e[4m'"text"$'\e[0m'
    assertEqualEscapeCodes "Underline escape code" "${expected}" "${result}"

    result=${ show blink "text"; }
    expected=$'\e[5m'"text"$'\e[0m'
    assertEqualEscapeCodes "Blink escape code" "${expected}" "${result}"

    result=${ show reverse "text"; }
    expected=$'\e[7m'"text"$'\e[0m'
    assertEqualEscapeCodes "Reverse escape code" "${expected}" "${result}"
}

testShowEscapeCodesBasicColors() {
    echo ""
    echo "Testing show() Basic Color Escape Codes"
    echo "========================================"

    local result expected

    result=${ show black "text"; }
    expected=$'\e[30m'"text"$'\e[0m'
    assertEqualEscapeCodes "Black escape code" "${expected}" "${result}"

    result=${ show red "text"; }
    expected=$'\e[31m'"text"$'\e[0m'
    assertEqualEscapeCodes "Red escape code" "${expected}" "${result}"

    result=${ show green "text"; }
    expected=$'\e[32m'"text"$'\e[0m'
    assertEqualEscapeCodes "Green escape code" "${expected}" "${result}"

    result=${ show yellow "text"; }
    expected=$'\e[33m'"text"$'\e[0m'
    assertEqualEscapeCodes "Yellow escape code" "${expected}" "${result}"

    result=${ show blue "text"; }
    expected=$'\e[34m'"text"$'\e[0m'
    assertEqualEscapeCodes "Blue escape code" "${expected}" "${result}"

    result=${ show magenta "text"; }
    expected=$'\e[35m'"text"$'\e[0m'
    assertEqualEscapeCodes "Magenta escape code" "${expected}" "${result}"

    result=${ show cyan "text"; }
    expected=$'\e[36m'"text"$'\e[0m'
    assertEqualEscapeCodes "Cyan escape code" "${expected}" "${result}"

    result=${ show white "text"; }
    expected=$'\e[37m'"text"$'\e[0m'
    assertEqualEscapeCodes "White escape code" "${expected}" "${result}"
}

testShowEscapeCodesBrightColors() {
    echo ""
    echo "Testing show() Bright Color Escape Codes"
    echo "========================================="

    local result expected

    result=${ show bright-black "text"; }
    expected=$'\e[90m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bright-black escape code" "${expected}" "${result}"

    result=${ show bright-red "text"; }
    expected=$'\e[91m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bright-red escape code" "${expected}" "${result}"

    result=${ show bright-green "text"; }
    expected=$'\e[92m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bright-green escape code" "${expected}" "${result}"

    result=${ show bright-yellow "text"; }
    expected=$'\e[93m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bright-yellow escape code" "${expected}" "${result}"

    result=${ show bright-blue "text"; }
    expected=$'\e[94m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bright-blue escape code" "${expected}" "${result}"

    result=${ show bright-magenta "text"; }
    expected=$'\e[95m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bright-magenta escape code" "${expected}" "${result}"

    result=${ show bright-cyan "text"; }
    expected=$'\e[96m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bright-cyan escape code" "${expected}" "${result}"

    result=${ show bright-white "text"; }
    expected=$'\e[97m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bright-white escape code" "${expected}" "${result}"
}

testShowEscapeCodes256Colors() {
    echo ""
    echo "Testing show() 256 Color Escape Codes"
    echo "======================================"

    local result expected

    result=${ show IDX 0 "text"; }
    expected=$'\033[38;5;0m'"text"$'\e[0m'
    assertEqualEscapeCodes "256 color: 0" "${expected}" "${result}"

    result=${ show IDX 196 "text"; }
    expected=$'\033[38;5;196m'"text"$'\e[0m'
    assertEqualEscapeCodes "256 color: 196" "${expected}" "${result}"

    result=${ show IDX 46 "text"; }
    expected=$'\033[38;5;46m'"text"$'\e[0m'
    assertEqualEscapeCodes "256 color: 46" "${expected}" "${result}"

    result=${ show IDX 255 "text"; }
    expected=$'\033[38;5;255m'"text"$'\e[0m'
    assertEqualEscapeCodes "256 color: 255" "${expected}" "${result}"

    result=${ show IDX 256 "text"; }
    expected="IDX 256 text"$'\e[0m'
    assertEqualEscapeCodes "Invalid 256 color (256) treated as text" "${expected}" "${result}"

    result=${ show IDX 999 "text"; }
    expected="IDX 999 text"$'\e[0m'
    assertEqualEscapeCodes "Invalid 256 color (999) treated as text" "${expected}" "${result}"

    result=${ show 42 "text"; }
    expected="42 text"$'\e[0m'
    assertEqualEscapeCodes "Numeric value without IDX treated as text" "${expected}" "${result}"
}

testShowEscapeCodesRGBColors() {
    echo ""
    echo "Testing show() RGB Color Escape Codes"
    echo "======================================"

    local result expected

    result=${ show RGB 52:208:88 "text"; }
    expected=$'\e[38;2;52;208;88m'"text"$'\e[0m'
    assertEqualEscapeCodes "RGB color: green (52:208:88)" "${expected}" "${result}"

    result=${ show RGB 215:58:73 "text"; }
    expected=$'\e[38;2;215;58;73m'"text"$'\e[0m'
    assertEqualEscapeCodes "RGB color: red (215:58:73)" "${expected}" "${result}"

    result=${ show RGB 0:0:0 "text"; }
    expected=$'\e[38;2;0;0;0m'"text"$'\e[0m'
    assertEqualEscapeCodes "RGB color: black (0:0:0)" "${expected}" "${result}"

    result=${ show RGB 255:255:255 "text"; }
    expected=$'\e[38;2;255;255;255m'"text"$'\e[0m'
    assertEqualEscapeCodes "RGB color: white (255:255:255)" "${expected}" "${result}"
}

testShowEscapeCodesStyleCombinations() {
    echo ""
    echo "Testing show() Style Combination Escape Codes"
    echo "=============================================="

    local result expected

    result=${ show bold italic "text"; }
    expected=$'\e[1m\e[3m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bold + Italic" "${expected}" "${result}"

    result=${ show bold red "text"; }
    expected=$'\e[1m\e[31m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bold + Red" "${expected}" "${result}"

    result=${ show italic underline green "text"; }
    expected=$'\e[3m\e[4m\e[32m'"text"$'\e[0m'
    assertEqualEscapeCodes "Italic + Underline + Green" "${expected}" "${result}"

    result=${ show bold italic underline "text"; }
    expected=$'\e[1m\e[3m\e[4m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bold + Italic + Underline" "${expected}" "${result}"

    result=${ show bold IDX 196 "text"; }
    expected=$'\e[1m\033[38;5;196m'"text"$'\e[0m'
    assertEqualEscapeCodes "Bold + 256 color (196)" "${expected}" "${result}"

    result=${ show italic RGB 52:208:88 "text"; }
    expected=$'\e[3m\e[38;2;52;208;88m'"text"$'\e[0m'
    assertEqualEscapeCodes "Italic + RGB color" "${expected}" "${result}"

    result=${ show bold italic underline dim reverse "text"; }
    expected=$'\e[1m\e[3m\e[4m\e[2m\e[7m'"text"$'\e[0m'
    assertEqualEscapeCodes "All styles: bold+italic+underline+dim+reverse" "${expected}" "${result}"
}

testShowEscapeCodesResets() {
    echo ""
    echo "Testing show() Reset Escape Codes"
    echo "=================================="

    local result expected

    result=${ show bold green "text1" plain "text2"; }
    expected=$'\e[1m\e[32m'"text1 "$'\e[0m'"text2"$'\e[0m'
    assertEqualEscapeCodes "Plain resets formatting" "${expected}" "${result}"

    result=${ show blue "text1" plain italic "text2"; }
    expected=$'\e[34m'"text1 "$'\e[0m\e[3m'"text2"$'\e[0m'
    assertEqualEscapeCodes "Plain between color and style" "${expected}" "${result}"

    result=${ show bold "text1" plain "text2" plain "text3"; }
    expected=$'\e[1m'"text1 "$'\e[0m'"text2 "$'\e[0m'"text3"$'\e[0m'
    assertEqualEscapeCodes "Multiple plain resets" "${expected}" "${result}"

    result=${ show bold red "text"; }
    expected=$'\e[1m\e[31m'"text"$'\e[0m'
    assertEqualEscapeCodes "Final reset code present" "${expected}" "${result}"

    result=${ show; }
    expected=''
    assertEqualEscapeCodes "No arguments produces empty output" "${expected}" "${result}"

    result=${ show bold red; }
    expected=$'\e[0m'
    assertEqualEscapeCodes "Format only produces only reset" "${expected}" "${result}"
}

testShowEscapeCodesComplexPatterns() {
    echo ""
    echo "Testing show() Complex Pattern Escape Codes"
    echo "============================================"

    local result expected

    result=${ show italic "text1" blue "text2"; }
    expected=$'\e[3m'"text1 "$'\e[34m'"text2"$'\e[0m'
    assertEqualEscapeCodes "Style persistence with color change" "${expected}" "${result}"

    result=${ show bold blue "text1" red "text2"; }
    expected=$'\e[1m\e[34m'"text1 "$'\e[31m'"text2"$'\e[0m'
    assertEqualEscapeCodes "Color replacement with style persistence" "${expected}" "${result}"

    result=${ show "text1" bold "text2" italic "text3"; }
    expected="text1 "$'\e[1m'"text2 "$'\e[3m'"text3"$'\e[0m'
    assertEqualEscapeCodes "Accumulating styles across arguments" "${expected}" "${result}"

    result=${ show bold green "text1" plain dim "text2"; }
    expected=$'\e[1m\e[32m'"text1 "$'\e[0m\e[2m'"text2"$'\e[0m'
    assertEqualEscapeCodes "Reset then new style" "${expected}" "${result}"

    result=${ show cyan "colored text" plain dim "dim text"; }
    expected=$'\e[36m'"colored text "$'\e[0m\e[2m'"dim text"$'\e[0m'
    assertEqualEscapeCodes "Cyan to dim via plain" "${expected}" "${result}"

    result=${ show red "A" blue "B" green "C"; }
    expected=$'\e[31m'"A "$'\e[34m'"B "$'\e[32m'"C"$'\e[0m'
    assertEqualEscapeCodes "Multiple color changes" "${expected}" "${result}"
}

# Force 24-bit color mode if not running in a terminal
[[ -t 1 && -t 2 ]] || declare -gx rayvnTest_Force24BitColor=1

source rayvn.up 'rayvn/core' 'rayvn/test'
main "$@"
