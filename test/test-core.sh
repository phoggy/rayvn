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
    assertEqual "hello" "${content}" "assertCommand with eval handles pipelines"
}

testAssertCommandCaptureStdout() {
    local result
    result="${ assertCommand echo "test output"; }"
    assertEqual "test output" "${result}" "assertCommand passes stdout through"
}

# ============================================================================
# String utilities
# ============================================================================

testTrim() {
    assertEqual "hello" "${ trim "  hello  "; }" "trim removes leading/trailing spaces"
    assertEqual "hello" "${ trim "hello"; }" "trim leaves clean string alone"
    assertEqual "" "${ trim "  "; }" "trim on only spaces returns empty"
    assertEqual "" "${ trim ""; }" "trim on empty returns empty"
    assertEqual "tab" "${ trim "	tab	"; }" "trim removes tabs"
    assertEqual "multi  word" "${ trim "  multi  word  "; }" "trim preserves internal spaces"
}

testRepeat() {
    assertEqual "xxxxx" "${ repeat "x" 5; }" "repeat char 5 times"
    assertEqual "ababab" "${ repeat "ab" 3; }" "repeat string 3 times"
    assertEqual "" "${ repeat "x" 0; }" "repeat 0 times returns empty"
    assertEqual "" "${ repeat "" 5; }" "repeat empty string returns empty"
}

testPadString() {
    assertEqual "hi   " "${ padString "hi" 5; }" "padString default pads after"
    assertEqual "hi   " "${ padString "hi" 5 after; }" "padString after pads right"
    assertEqual "   hi" "${ padString "hi" 5 before; }" "padString before pads left"
    assertEqual " hi  " "${ padString "hi" 5 center; }" "padString center pads both"
    assertEqual "hello" "${ padString "hello" 3; }" "padString no-op when string longer"
}

testStripAnsi() {
    local colored=$'\e[31mred\e[0m'
    assertEqual "red" "${ stripAnsi "${colored}"; }" "stripAnsi removes color codes"
    assertEqual "plain" "${ stripAnsi "plain"; }" "stripAnsi leaves plain text"
    local multi=$'\e[1;32mbold green\e[0m'
    assertEqual "bold green" "${ stripAnsi "${multi}"; }" "stripAnsi handles multi-code"
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
    assertEqual "/path/to" "${ dirName "/path/to/file"; }" "dirName extracts directory"
    assertEqual "/path/to" "${ dirName "/path/to/dir/"; }" "dirName handles trailing slash"
    assertEqual "file" "${ dirName "file"; }" "dirName of bare filename is itself"
}

testBaseName() {
    assertEqual "file" "${ baseName "/path/to/file"; }" "baseName extracts filename"
    assertEqual "dir" "${ baseName "/path/to/dir/"; }" "baseName handles trailing slash"
    assertEqual "file" "${ baseName "file"; }" "baseName of bare filename is itself"
}

# ============================================================================
# Array utilities
# ============================================================================

testIndexOf() {
    local arr=("apple" "banana" "cherry")
    assertEqual "1" "${ indexOf "banana" arr; }" "indexOf finds element at index 1"
    assertEqual "0" "${ indexOf "apple" arr; }" "indexOf finds element at index 0"
    assertEqual "-1" "${ indexOf "missing" arr; }" "indexOf returns -1 for missing"
}

testIsMemberOf() {
    local arr=("apple" "banana" "cherry")
    assertTrue "isMemberOf finds 'banana'" isMemberOf "banana" arr
    assertFalse "isMemberOf does not find 'grape'" isMemberOf "grape" arr
}

testMaxArrayElementLength() {
    local arr=("a" "abc" "ab")
    assertEqual "3" "${ maxArrayElementLength arr; }" "maxArrayElementLength finds longest"
    local empty=()
    assertEqual "0" "${ maxArrayElementLength empty; }" "maxArrayElementLength of empty is 0"
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
    assertEqual "first second" "${testVar}" "appendVar adds with space separator"
    local emptyVar=""
    appendVar emptyVar "only"
    assertEqual "only" "${emptyVar}" "appendVar on empty doesn't add leading space"
}

# ============================================================================
# Numeric utilities
# ============================================================================

testNumericPlaces() {
    assertEqual "1" "${ numericPlaces 9; }" "numericPlaces for 0-9 is 1 digit"
    assertEqual "1" "${ numericPlaces 10; }" "numericPlaces for 0-10 (adjusted to 9) is 1"
    assertEqual "2" "${ numericPlaces 11; }" "numericPlaces for 0-11 (adjusted to 10) is 2"
    assertEqual "2" "${ numericPlaces 100; }" "numericPlaces for 0-100 (adjusted to 99) is 2"
    assertEqual "2" "${ numericPlaces 10 1; }" "numericPlaces 1-10 needs 2 digits"
    assertEqual "1" "${ numericPlaces 9 1; }" "numericPlaces 1-9 needs 1 digit"
}

testRandomInteger() {
    local val
    randomInteger val 10
    assertInRange "${val}" 0 10 "randomInteger in range 0-10"
    randomInteger val
    assertInRange "${val}" 0 4294967295 "randomInteger in range 0-4294967295"
}

# ============================================================================
# Temp file utilities
# ============================================================================

testTempDirPath() {
    local path="${ tempDirPath; }"
    assertTrue "tempDirPath returns existing directory" test -d "${path}"

    local subpath="${ tempDirPath "subfile"; }"
    assertEqual "${path}/subfile" "${subpath}" "tempDirPath with arg appends"
}

testMakeTempFile() {
    local file="${ makeTempFile test-XXXXXX; }"
    assertTrue "makeTempFile creates file" test -f "${file}"
    assertContains "test-" "${file}" "makeTempFile uses template"
    rm -f "${file}"
}

testMakeTempDir() {
    local dir="${ makeTempDir testdir-XXXXXX; }"
    assertTrue "makeTempDir creates directory" test -d "${dir}"
    assertContains "testdir-" "${dir}" "makeTempDir uses template"
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
    assertEqualStripped "text" "${result}" "Color only: blue"

    result=${ show bold "text"; }
    assertEqualStripped "text" "${result}" "Style only: bold"

    result=${ show italic "text"; }
    assertEqualStripped "text" "${result}" "Style only: italic"

    result=${ show dim "text"; }
    assertEqualStripped "text" "${result}" "Style only: dim"

    result=${ show bold blue "text"; }
    assertEqualStripped "text" "${result}" "Combined: bold blue"

    result=${ show italic green "text"; }
    assertEqualStripped "text" "${result}" "Combined: italic green"

    result=${ show "plain text"; }
    assertEqualStripped "plain text" "${result}" "Plain text"

    result=${ show "word1" "word2" "word3"; }
    assertEqualStripped "word1 word2 word3" "${result}" "Multiple plain arguments"
}

testShowFormatCombinations() {
    echo ""
    echo "Testing show() Format Combinations"
    echo "==================================="

    local result

    result=${ show bold italic "text"; }
    assertEqualStripped "text" "${result}" "Multiple styles: bold italic"

    result=${ show bold italic underline "text"; }
    assertEqualStripped "text" "${result}" "Triple style: bold italic underline"

    result=${ show bold italic blue "text"; }
    assertEqualStripped "text" "${result}" "Color + styles: bold italic blue"

    result=${ show dim underline red "text"; }
    assertEqualStripped "text" "${result}" "Styles + color: dim underline red"
}

testShowStylePersistence() {
    echo ""
    echo "Testing show() Style Persistence"
    echo "================================="

    local result

    result=${ show italic "starts italic" blue "still italic, now blue"; }
    assertEqualStripped "starts italic still italic, now blue" "${result}" "Style persists: italic continues"

    result=${ show bold "bold start" "bold continues" "still bold"; }
    assertEqualStripped "bold start bold continues still bold" "${result}" "Style persists: bold continues"

    result=${ show italic "italic" bold "italic+bold" underline "italic+bold+underline"; }
    assertEqualStripped "italic+bold italic+bold+underline" "${result}" "Styles accumulate"
}

testShowColorReplacement() {
    echo ""
    echo "Testing show() Color Replacement"
    echo "================================="

    local result

    result=${ show blue "blue" red "red (replaces blue)"; }
    assertEqualStripped "red (replaces blue)" "${result}" "Color replacement: blue to red"

    result=${ show green "green" yellow "yellow" magenta "magenta"; }
    assertEqualStripped "" "${result}" "Multiple color replacements"

    result=${ show bold blue "bold blue" red "bold red (color replaced)"; }
    assertEqualStripped "bold blue bold red (color replaced)" "${result}" "Color replacement preserves style"
}

testShowPlainResetPattern() {
    echo ""
    echo "Testing show() 'plain' Reset Pattern"
    echo "====================================="

    local result

    result=${ show bold green "styled" plain "back to normal"; }
    assertEqualStripped "styled back to normal" "${result}" "Reset after bold+color"

    result=${ show cyan "colored" plain dim "dimmed, not colored"; }
    assertEqualStripped "colored dimmed, not colored" "${result}" "Color to style-only: cyan to dim"

    result=${ show blue "blue text" plain italic "italic only"; }
    assertEqualStripped "blue text italic only" "${result}" "Color to style-only: blue to italic"

    result=${ show bold blue "heading" plain "text" italic "emphasis"; }
    assertEqualStripped "heading text emphasis" "${result}" "Reset between combinations"

    result=${ show bold "bold" plain "normal" italic "italic" plain "normal again"; }
    assertEqualStripped "normal normal again" "${result}" "Multiple resets"
}

testShowCommandSubstitution() {
    echo ""
    echo "Testing show() Command Substitution"
    echo "===================================="

    local result message

    message="${ show bold "text" ;}"
    assertEqualStripped "text" "${message}" "Command substitution: basic"

    message="${ show bold green "styled text" ;}"
    assertEqualStripped "styled text" "${message}" "Command substitution: styled"

    message="${ show "Start" cyan "middle" plain "end" ;}"
    assertEqualStripped "Start middle end" "${message}" "Command substitution: multiple formats"

    result="${ show green "success" ;}"
    assertEqualStripped "" "${result}" "Assignment from substitution"
}

testShowThemeColors() {
    require 'rayvn/theme'
    echo ""
    echo "Testing show() Theme Colors"
    echo "============================"

    local result

    for themeColor in "${_themeColors[@]}"; do
        result=${ show ${themeColor} "themed text"; }
        assertEqualStripped "themed text" "${result}" "Theme color: ${themeColor}"
    done

    result=${ show bold success "bold success"; }
    assertEqualStripped "bold success" "${result}" "Theme + style: bold success"

    result=${ show italic error "italic error"; }
    assertEqualStripped "italic error" "${result}" "Theme + style: italic error"
}

testShow256Colors() {
    echo ""
    echo "Testing show() 256 Colors"
    echo "========================="

    local result

    result=${ show IDX 196 "red via 256"; }
    assertEqualStripped "red via 256" "${result}" "256 color: 196 (red)"

    result=${ show IDX 46 "green via 256"; }
    assertEqualStripped "green via 256" "${result}" "256 color: 46 (green)"

    result=${ show IDX 0 "color 0"; }
    assertEqualStripped "color 0" "${result}" "256 color: 0"

    result=${ show IDX 255 "color 255"; }
    assertEqualStripped "color 255" "${result}" "256 color: 255"

    result=${ show bold IDX 196 "bold red 256"; }
    assertEqualStripped "bold red 256" "${result}" "256 color with style"

    result=${ show "Start" IDX 196 "'red'" IDX 46 "'green'" "end"; }
    assertEqualStripped "Start 'red' 'green' end" "${result}" "256 colors interleaved"

    result=${ show IDX 256 "text"; }
    assertEqualStripped "IDX 256 text" "${result}" "Invalid 256 color (256)"

    result=${ show IDX 999 "text"; }
    assertEqualStripped "IDX 999 text" "${result}" "Invalid 256 color (999)"

    result=${ show "The answer is" 42 "!"; }
    assertEqualStripped "The answer is 42 !" "${result}" "Numeric value as text"

    result=${ show bold 100 "not a color"; }
    assertEqualStripped "100 not a color" "${result}" "Numeric with style as text"
}

testShowRGBColors() {
    echo ""
    echo "Testing show() RGB Colors"
    echo "========================="

    local result

    result=${ show RGB 52:208:88 "rgb green"; }
    assertEqualStripped "rgb green" "${result}" "RGB color: green"

    result=${ show RGB 215:58:73 "rgb red"; }
    assertEqualStripped "rgb red" "${result}" "RGB color: red"

    result=${ show bold RGB 52:208:88 "bold rgb"; }
    assertEqualStripped "bold rgb" "${result}" "RGB with style"
}

testShowOptions() {
    echo ""
    echo "Testing show() Options"
    echo "======================"

    local result

    result=${ show -n "no newline"; }
    assertEqualStripped "no newline" "${result}" "Option -n"

    result=${ show -n blue "colored no newline"; }
    assertEqualStripped "colored no newline" "${result}" "Option -n with color"

    result=${ show -n -e "options"; }
    assertEqualStripped "options" "${result}" "Multiple options"

    result=${ show -n bold red "formatted no newline"; }
    assertEqualStripped "formatted no newline" "${result}" "Options with formats"
}

testShowEdgeCases() {
    echo ""
    echo "Testing show() Edge Cases"
    echo "========================="

    local result

    result=${ show; }
    assertEqualStripped "" "${result}" "No arguments"

    result=${ show ""; }
    assertEqualStripped "" "${result}" "Empty string"

    result=${ show bold red; }
    assertEqualStripped "" "${result}" "Format only, no text"

    local longText="This is a very long text string that contains many words and should be handled correctly"
    result=${ show green "${longText}"; }
    assertEqualStripped "${longText}" "${result}" "Very long text"

    result=${ show red "text with \$special @chars!"; }
    assertEqualStripped "text with \$special @chars!" "${result}" "Special characters"

    result=${ show red "valid" notaformat "text"; }
    assertEqualStripped "valid notaformat text" "${result}" "Invalid format as text"

    result=${ show bold italic underline dim reverse "all styles"; }
    assertEqualStripped "all styles" "${result}" "Many consecutive formats"

    result=${ show red "A" blue "B" green "C" yellow "D"; }
    assertEqualStripped "A B C D" "${result}" "Alternating formats/text"

    result=${ show "The word red" red "is now red"; }
    assertEqualStripped "The word red is now red" "${result}" "Format name in text"
}

testShowDocumentedPatterns() {
    echo ""
    echo "Testing show() Documented Patterns"
    echo "==================================="

    local result

    result=${ show blue "This is blue text"; }
    assertEqualStripped "This is blue text" "${result}" "Doc example: blue text"

    result=${ show bold red "Bold red text"; }
    assertEqualStripped "Bold red text" "${result}" "Doc example: bold red"

    result=${ show success "Operation completed"; }
    assertEqualStripped "Operation completed" "${result}" "Doc example: success"

    result=${ show italic underline green "Italic underline green text"; }
    assertEqualStripped "Italic underline green text" "${result}" "Doc example: multi-style green"

    result=${ show "Plain text" italic bold blue "italic bold blue text" red "italic bold red" plain blue "blue text"; }
    assertEqualStripped "Plain text italic bold blue text italic bold red blue text" "${result}" "Doc example: style continuation"

    result=${ show cyan "colored text" plain dim "dim text (no color)"; }
    assertEqualStripped "colored text dim text (no color)" "${result}" "Doc pattern: cyan to dim"

    result=${ show bold green "Note" plain "Regular text continues here"; }
    assertEqualStripped "Note Regular text continues here" "${result}" "Doc pattern: reset after combo"

    result=${ show bold blue "heading" plain "text" italic "emphasis"; }
    assertEqualStripped "heading text emphasis" "${result}" "Doc pattern: transitions"
}

testShowEscapeCodesBasicStyles() {
    echo ""
    echo "Testing show() Basic Style Escape Codes"
    echo "========================================"

    local result expected

    result=${ show bold "text"; }
    expected=$'\e[1m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bold escape code"

    result=${ show dim "text"; }
    expected=$'\e[2m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Dim escape code"

    result=${ show italic "text"; }
    expected=$'\e[3m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Italic escape code"

    result=${ show underline "text"; }
    expected=$'\e[4m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Underline escape code"

    result=${ show blink "text"; }
    expected=$'\e[5m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Blink escape code"

    result=${ show reverse "text"; }
    expected=$'\e[7m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Reverse escape code"
}

testShowEscapeCodesBasicColors() {
    echo ""
    echo "Testing show() Basic Color Escape Codes"
    echo "========================================"

    local result expected

    result=${ show black "text"; }
    expected=$'\e[30m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Black escape code"

    result=${ show red "text"; }
    expected=$'\e[31m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Red escape code"

    result=${ show green "text"; }
    expected=$'\e[32m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Green escape code"

    result=${ show yellow "text"; }
    expected=$'\e[33m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Yellow escape code"

    result=${ show blue "text"; }
    expected=$'\e[34m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Blue escape code"

    result=${ show magenta "text"; }
    expected=$'\e[35m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Magenta escape code"

    result=${ show cyan "text"; }
    expected=$'\e[36m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Cyan escape code"

    result=${ show white "text"; }
    expected=$'\e[37m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "White escape code"
}

testShowEscapeCodesBrightColors() {
    echo ""
    echo "Testing show() Bright Color Escape Codes"
    echo "========================================="

    local result expected

    result=${ show bright-black "text"; }
    expected=$'\e[90m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bright-black escape code"

    result=${ show bright-red "text"; }
    expected=$'\e[91m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bright-red escape code"

    result=${ show bright-green "text"; }
    expected=$'\e[92m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bright-green escape code"

    result=${ show bright-yellow "text"; }
    expected=$'\e[93m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bright-yellow escape code"

    result=${ show bright-blue "text"; }
    expected=$'\e[94m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bright-blue escape code"

    result=${ show bright-magenta "text"; }
    expected=$'\e[95m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bright-magenta escape code"

    result=${ show bright-cyan "text"; }
    expected=$'\e[96m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bright-cyan escape code"

    result=${ show bright-white "text"; }
    expected=$'\e[97m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bright-white escape code"
}

testShowEscapeCodes256Colors() {
    echo ""
    echo "Testing show() 256 Color Escape Codes"
    echo "======================================"

    local result expected

    result=${ show IDX 0 "text"; }
    expected=$'\033[38;5;0m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "256 color: 0"

    result=${ show IDX 196 "text"; }
    expected=$'\033[38;5;196m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "256 color: 196"

    result=${ show IDX 46 "text"; }
    expected=$'\033[38;5;46m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "256 color: 46"

    result=${ show IDX 255 "text"; }
    expected=$'\033[38;5;255m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "256 color: 255"

    result=${ show IDX 256 "text"; }
    expected="IDX 256 text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Invalid 256 color (256) treated as text"

    result=${ show IDX 999 "text"; }
    expected="IDX 999 text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Invalid 256 color (999) treated as text"

    result=${ show 42 "text"; }
    expected="42 text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Numeric value without IDX treated as text"
}

testShowEscapeCodesRGBColors() {
    echo ""
    echo "Testing show() RGB Color Escape Codes"
    echo "======================================"

    local result expected

    result=${ show RGB 52:208:88 "text"; }
    expected=$'\e[38;2;52;208;88m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "RGB color: green (52:208:88)"

    result=${ show RGB 215:58:73 "text"; }
    expected=$'\e[38;2;215;58;73m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "RGB color: red (215:58:73)"

    result=${ show RGB 0:0:0 "text"; }
    expected=$'\e[38;2;0;0;0m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "RGB color: black (0:0:0)"

    result=${ show RGB 255:255:255 "text"; }
    expected=$'\e[38;2;255;255;255m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "RGB color: white (255:255:255)"
}

testShowEscapeCodesStyleCombinations() {
    echo ""
    echo "Testing show() Style Combination Escape Codes"
    echo "=============================================="

    local result expected

    result=${ show bold italic "text"; }
    expected=$'\e[1m\e[3m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bold + Italic"

    result=${ show bold red "text"; }
    expected=$'\e[1m\e[31m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bold + Red"

    result=${ show italic underline green "text"; }
    expected=$'\e[3m\e[4m\e[32m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Italic + Underline + Green"

    result=${ show bold italic underline "text"; }
    expected=$'\e[1m\e[3m\e[4m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bold + Italic + Underline"

    result=${ show bold IDX 196 "text"; }
    expected=$'\e[1m\033[38;5;196m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Bold + 256 color (196)"

    result=${ show italic RGB 52:208:88 "text"; }
    expected=$'\e[3m\e[38;2;52;208;88m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Italic + RGB color"

    result=${ show bold italic underline dim reverse "text"; }
    expected=$'\e[1m\e[3m\e[4m\e[2m\e[7m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "All styles: bold+italic+underline+dim+reverse"
}

testShowEscapeCodesResets() {
    echo ""
    echo "Testing show() Reset Escape Codes"
    echo "=================================="

    local result expected

    result=${ show bold green "text1" plain "text2"; }
    expected=$'\e[1m\e[32m'"text1 "$'\e[0m'"text2"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Plain resets formatting"

    result=${ show blue "text1" plain italic "text2"; }
    expected=$'\e[34m'"text1 "$'\e[0m\e[3m'"text2"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Plain between color and style"

    result=${ show bold "text1" plain "text2" plain "text3"; }
    expected=$'\e[1m'"text1 "$'\e[0m'"text2 "$'\e[0m'"text3"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Multiple plain resets"

    result=${ show bold red "text"; }
    expected=$'\e[1m\e[31m'"text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Final reset code present"

    result=${ show; }
    expected=''
    assertEqualEscapeCodes "${expected}" "${result}" "No arguments produces empty output"

    result=${ show bold red; }
    expected=$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Format only produces only reset"
}

testShowEscapeCodesComplexPatterns() {
    echo ""
    echo "Testing show() Complex Pattern Escape Codes"
    echo "============================================"

    local result expected

    result=${ show italic "text1" blue "text2"; }
    expected=$'\e[3m'"text1 "$'\e[34m'"text2"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Style persistence with color change"

    result=${ show bold blue "text1" red "text2"; }
    expected=$'\e[1m\e[34m'"text1 "$'\e[31m'"text2"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Color replacement with style persistence"

    result=${ show "text1" bold "text2" italic "text3"; }
    expected="text1 "$'\e[1m'"text2 "$'\e[3m'"text3"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Accumulating styles across arguments"

    result=${ show bold green "text1" plain dim "text2"; }
    expected=$'\e[1m\e[32m'"text1 "$'\e[0m\e[2m'"text2"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Reset then new style"

    result=${ show cyan "colored text" plain dim "dim text"; }
    expected=$'\e[36m'"colored text "$'\e[0m\e[2m'"dim text"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Cyan to dim via plain"

    result=${ show red "A" blue "B" green "C"; }
    expected=$'\e[31m'"A "$'\e[34m'"B "$'\e[32m'"C"$'\e[0m'
    assertEqualEscapeCodes "${expected}" "${result}" "Multiple color changes"
}

# Force 24-bit color mode if not running in a terminal
[[ -t 1 && -t 2 ]] || declare -gx rayvnTest_Force24BitColor=1

source rayvn.up 'rayvn/core' 'rayvn/test'
main "$@"
