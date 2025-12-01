#!/usr/bin/env bash

# Comprehensive test suite for the show() function
# Tests all patterns documented in rayvn/lib/core.sh

main() {
    init "${@}"
    testBasicUsage
    testFormatCombinations
    testStylePersistence
    testColorReplacement
    testPlainResetPattern
    testCommandSubstitution
    testThemeColors
    test256Colors
    testRGBColors
    testOptions
    testEdgeCases
    testDocumentedPatterns
    testEscapeCodesBasicStyles
    testEscapeCodesBasicColors
    testEscapeCodesBrightColors
    testEscapeCodes256Colors
    testEscapeCodesRGBColors
    testEscapeCodesStyleCombinations
    testEscapeCodesResets
    testEscapeCodesComplexPatterns

    printSummary
}

init() {
    declare -gi testCount=0
    declare -gi passCount=0
    declare -gi failCount=0
}

# Helper to strip ANSI codes
stripAnsi() {
    echo -n "${1}" | sed 's/\x1b\[[0-9;]*m//g'
}

# Test assertion with better output
assert() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    (( testCount++ ))

    if [[ ${actual} == ${expected} ]]; then
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

# Helper to compare stripped output
assertStripped() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    assert "${testName}" "${expected}" "${ stripAnsi "${actual}"; }"
}

# Helper to assert exact escape code match
assertEscapeCodes() {
    local testName="${1}"
    local expected="${2}"
    local actual="${3}"

    (( testCount++ ))

    if [[ ${actual} == ${expected} ]]; then
        (( passCount++ ))
        echo "  ✓ ${testName}"
        return 0
    else
        (( failCount++ ))
        echo "  ✗ ${testName}"
        echo "    Expected: '${expected}'"
        echo "    Actual:   '${actual}'"
        # Show visible representation of escape codes for debugging
        echo "    Expected (visible): $(echo -n "${expected}" | cat -v)"
        echo "    Actual (visible):   $(echo -n "${actual}" | cat -v)"
        return 1
    fi
}

testBasicUsage() {
    echo ""
    echo "Testing Basic Usage"
    echo "==================="
    echo ""

    local result

    # Applying color only
    result=${ show blue "text"; }
    assertStripped "Color only: blue" "text" "${result}"

    # Applying style only
    result=${ show bold "text"; }
    assertStripped "Style only: bold" "text" "${result}"

    result=${ show italic "text"; }
    assertStripped "Style only: italic" "text" "${result}"

    result=${ show dim "text"; }
    assertStripped "Style only: dim" "text" "${result}"

    # Combining color and style
    result=${ show bold blue "text"; }
    assertStripped "Combined: bold blue" "text" "${result}"

    result=${ show italic green "text"; }
    assertStripped "Combined: italic green" "text" "${result}"

    # Plain text (no formatting)
    result=${ show "plain text"; }
    assertStripped "Plain text" "plain text" "${result}"

    # Multiple arguments
    result=${ show "word1" "word2" "word3"; }
    assertStripped "Multiple plain arguments" "word1 word2 word3" "${result}"
}

testFormatCombinations() {
    echo ""
    echo "Testing Format Combinations"
    echo "============================"
    echo ""

    local result

    # Multiple styles
    result=${ show bold italic "text"; }
    assertStripped "Multiple styles: bold italic" "text" "${result}"

    result=${ show bold italic underline "text"; }
    assertStripped "Triple style: bold italic underline" "text" "${result}"

    # Color + multiple styles
    result=${ show bold italic blue "text"; }
    assertStripped "Color + styles: bold italic blue" "text" "${result}"

    result=${ show dim underline red "text"; }
    assertStripped "Styles + color: dim underline red" "text" "${result}"
}

testStylePersistence() {
    echo ""
    echo "Testing Style Persistence"
    echo "=========================="
    echo ""

    local result

    # Styles persist across arguments
    result=${ show italic "starts italic" blue "still italic, now blue"; }
    assertStripped "Style persists: italic continues" "starts italic still italic, now blue" "${result}"

    result=${ show bold "bold start" "bold continues" "still bold"; }
    assertStripped "Style persists: bold continues" "bold start bold continues still bold" "${result}"

    # Multiple styles accumulate
    result=${ show italic "italic" bold "italic+bold" underline "italic+bold+underline"; }
    assertStripped "Styles accumulate" "italic+bold italic+bold+underline" "${result}"
}

testColorReplacement() {
    echo ""
    echo "Testing Color Replacement"
    echo "=========================="
    echo ""

    local result

    # Colors replace previous colors
    result=${ show blue "blue" red "red (replaces blue)"; }
    assertStripped "Color replacement: blue to red" "red (replaces blue)" "${result}"

    result=${ show green "green" yellow "yellow" magenta "magenta"; }
    assertStripped "Multiple color replacements" "" "${result}"

    # Color replacement doesn't affect styles
    result=${ show bold blue "bold blue" red "bold red (color replaced)"; }
    assertStripped "Color replacement preserves style" "bold blue bold red (color replaced)" "${result}"
}

testPlainResetPattern() {
    echo ""
    echo "Testing 'plain' Reset Pattern (CRITICAL)"
    echo "========================================="
    echo ""

    local result

    # Reset after color/style combination
    result=${ show bold green "styled" plain "back to normal"; }
    assertStripped "Reset after bold+color" "styled back to normal" "${result}"

    # Transitioning from color to style-only (IMPORTANT)
    result=${ show cyan "colored" plain dim "dimmed, not colored"; }
    assertStripped "Color to style-only: cyan to dim" "colored dimmed, not colored" "${result}"

    result=${ show blue "blue text" plain italic "italic only"; }
    assertStripped "Color to style-only: blue to italic" "blue text italic only" "${result}"

    # Reset between different combinations
    result=${ show bold blue "heading" plain "text" italic "emphasis"; }
    assertStripped "Reset between combinations" "heading text emphasis" "${result}"

    # Multiple resets
    result=${ show bold "bold" plain "normal" italic "italic" plain "normal again"; }
    assertStripped "Multiple resets" "normal normal again" "${result}"
}

testCommandSubstitution() {
    echo ""
    echo "Testing Command Substitution (bash 5.3+)"
    echo "========================================="
    echo ""

    local result message

    # Basic command substitution
    message="${ show bold "text" ;}"
    assertStripped "Command substitution: basic" "text" "${message}"

    message="${ show bold green "styled text" ;}"
    assertStripped "Command substitution: styled" "styled text" "${message}"

    # Multiple formats
    message="${ show "Start" cyan "middle" plain "end" ;}"
    assertStripped "Command substitution: multiple formats" "Start middle end" "${message}"

    # In conditionals/assignments (common pattern)
    result="${ show green "success" ;}"
    assertStripped "Assignment from substitution" "" "${result}"
}

testThemeColors() {
    require 'rayvn/themes'
    echo ""
    echo "Testing Theme Colors"
    echo "===================="
    echo ""

    local result

    # All theme colors
    for themeColor in "${_themeColors[@]}"; do
        result=${ show ${themeColor} "themed text"; }
        assertStripped "Theme color: ${themeColor}" "themed text" "${result}"
    done

    # Theme colors with styles
    result=${ show bold success "bold success"; }
    assertStripped "Theme + style: bold success" "bold success" "${result}"

    result=${ show italic error "italic error"; }
    assertStripped "Theme + style: italic error" "italic error" "${result}"
}

test256Colors() {
    echo ""
    echo "Testing 256 Colors"
    echo "=================="
    echo ""

    local result

    # Valid 256 color codes
    result=${ show IDX 196 "red via 256"; }
    assertStripped "256 color: 196 (red)" "red via 256" "${result}"

    result=${ show IDX 46 "green via 256"; }
    assertStripped "256 color: 46 (green)" "green via 256" "${result}"

    # Edge cases: 0 and 255
    result=${ show IDX 0 "color 0"; }
    assertStripped "256 color: 0" "color 0" "${result}"

    result=${ show IDX 255 "color 255"; }
    assertStripped "256 color: 255" "color 255" "${result}"

    # Mix format names and 256 colors
    result=${ show bold IDX 196 "bold red 256"; }
    assertStripped "256 color with style" "bold red 256" "${result}"

    # 256 colors interleaved
    result=${ show "Start" IDX 196 "red" IDX 46 "green" "end"; }
    assertStripped "256 colors interleaved" "Start red green end" "${result}"

    # Invalid 256 color (>255) treated as text
    result=${ show IDX 256 "text"; }
    assertStripped "Invalid 256 color (256)" "IDX 256 text" "${result}"

    result=${ show IDX 999 "text"; }
    assertStripped "Invalid 256 color (999)" "IDX 999 text" "${result}"

    # Numeric values without IDX are displayed as text
    result=${ show "The answer is" 42 "!"; }
    assertStripped "Numeric value as text" "The answer is 42 !" "${result}"

    result=${ show bold 100 "not a color"; }
    assertStripped "Numeric with style as text" "100 not a color" "${result}"
}

testRGBColors() {
    echo ""
    echo "Testing RGB Colors"
    echo "=================="
    echo ""

    local result

    # RGB color syntax
    result=${ show RGB 52:208:88 "rgb green"; }
    assertStripped "RGB color: green" "rgb green" "${result}"

    result=${ show RGB 215:58:73 "rgb red"; }
    assertStripped "RGB color: red" "rgb red" "${result}"

    # RGB with styles
    result=${ show bold RGB 52:208:88 "bold rgb"; }
    assertStripped "RGB with style" "bold rgb" "${result}"
}

testOptions() {
    echo ""
    echo "Testing Options"
    echo "==============="
    echo ""

    local result

    # -n option (no newline)
    result=${ show -n "no newline"; }
    assertStripped "Option -n" "no newline" "${result}"

    result=${ show -n blue "colored no newline"; }
    assertStripped "Option -n with color" "colored no newline" "${result}"

    # Multiple options
    result=${ show -n -e "options"; }
    assertStripped "Multiple options" "options" "${result}"

    # Options with formats
    result=${ show -n bold red "formatted no newline"; }
    assertStripped "Options with formats" "formatted no newline" "${result}"
}

testEdgeCases() {
    echo ""
    echo "Testing Edge Cases"
    echo "=================="
    echo ""

    local result

    # No arguments
    result=${ show; }
    assertStripped "No arguments" "" "${result}"

    # Empty string argument
    result=${ show ""; }
    assertStripped "Empty string" "" "${result}"

    # Format only (no text)
    result=${ show bold red; }
    assertStripped "Format only, no text" "" "${result}"

    # Very long text
    local longText="This is a very long text string that contains many words and should be handled correctly"
    result=${ show green "${longText}"; }
    assertStripped "Very long text" "${longText}" "${result}"

    # Special characters
    result=${ show red "text with \$special @chars!"; }
    assertStripped "Special characters" "text with \$special @chars!" "${result}"

    # Text that looks like format but isn't
    result=${ show red "valid" notaformat "text"; }
    assertStripped "Invalid format as text" "valid notaformat text" "${result}"

    # Many consecutive formats
    result=${ show bold italic underline dim reverse "all styles"; }
    assertStripped "Many consecutive formats" "all styles" "${result}"

    # Alternating formats and text
    result=${ show red "A" blue "B" green "C" yellow "D"; }
    assertStripped "Alternating formats/text" "A B C D" "${result}"

    # Format names in text
    result=${ show "The word red" red "is now red"; }
    assertStripped "Format name in text" "The word red is now red" "${result}"
}

testDocumentedPatterns() {
    echo ""
    echo "Testing Documented Patterns from core.sh"
    echo "========================================="
    echo ""

    local result

    # Example: show blue "This is blue text"
    result=${ show blue "This is blue text"; }
    assertStripped "Doc example: blue text" "This is blue text" "${result}"

    # Example: show bold red "Bold red text"
    result=${ show bold red "Bold red text"; }
    assertStripped "Doc example: bold red" "Bold red text" "${result}"

    # Example: show success "Operation completed"
    result=${ show success "Operation completed"; }
    assertStripped "Doc example: success" "Operation completed" "${result}"

    # Example: show italic underline green "Italic underline green text"
    result=${ show italic underline green "Italic underline green text"; }
    assertStripped "Doc example: multi-style green" "Italic underline green text" "${result}"

    # Example: show "Plain text" italic bold blue "italic bold blue text" red "italic bold red" plain blue "blue text"
    result=${ show "Plain text" italic bold blue "italic bold blue text" red "italic bold red" plain blue "blue text"; }
    assertStripped "Doc example: style continuation" "Plain text italic bold blue text italic bold red blue text" "${result}"

    # IMPORTANT pattern: show cyan "colored text" plain dim "dim text (no color)"
    result=${ show cyan "colored text" plain dim "dim text (no color)"; }
    assertStripped "Doc pattern: cyan to dim" "colored text dim text (no color)" "${result}"

    # Pattern: show bold green "Note" plain "Regular text continues here"
    result=${ show bold green "Note" plain "Regular text continues here"; }
    assertStripped "Doc pattern: reset after combo" "Note Regular text continues here" "${result}"

    # Pattern: show bold blue "heading" plain "text" italic "emphasis"
    result=${ show bold blue "heading" plain "text" italic "emphasis"; }
    assertStripped "Doc pattern: transitions" "heading text emphasis" "${result}"
}

testEscapeCodesBasicStyles() {
    echo ""
    echo "Testing Basic Style Escape Codes"
    echo "================================="
    echo ""

    local result expected

    # Bold: \e[1m
    result=${ show bold "text"; }
    expected=$'\e[1m'"text"$'\e[0m'
    assertEscapeCodes "Bold escape code" "${expected}" "${result}"

    # Dim: \e[2m
    result=${ show dim "text"; }
    expected=$'\e[2m'"text"$'\e[0m'
    assertEscapeCodes "Dim escape code" "${expected}" "${result}"

    # Italic: \e[3m
    result=${ show italic "text"; }
    expected=$'\e[3m'"text"$'\e[0m'
    assertEscapeCodes "Italic escape code" "${expected}" "${result}"

    # Underline: \e[4m
    result=${ show underline "text"; }
    expected=$'\e[4m'"text"$'\e[0m'
    assertEscapeCodes "Underline escape code" "${expected}" "${result}"

    # Blink: \e[5m
    result=${ show blink "text"; }
    expected=$'\e[5m'"text"$'\e[0m'
    assertEscapeCodes "Blink escape code" "${expected}" "${result}"

    # Reverse: \e[7m
    result=${ show reverse "text"; }
    expected=$'\e[7m'"text"$'\e[0m'
    assertEscapeCodes "Reverse escape code" "${expected}" "${result}"
}

testEscapeCodesBasicColors() {
    echo ""
    echo "Testing Basic Color Escape Codes"
    echo "================================="
    echo ""

    local result expected

    # Black: \e[30m
    result=${ show black "text"; }
    expected=$'\e[30m'"text"$'\e[0m'
    assertEscapeCodes "Black escape code" "${expected}" "${result}"

    # Red: \e[31m
    result=${ show red "text"; }
    expected=$'\e[31m'"text"$'\e[0m'
    assertEscapeCodes "Red escape code" "${expected}" "${result}"

    # Green: \e[32m
    result=${ show green "text"; }
    expected=$'\e[32m'"text"$'\e[0m'
    assertEscapeCodes "Green escape code" "${expected}" "${result}"

    # Yellow: \e[33m
    result=${ show yellow "text"; }
    expected=$'\e[33m'"text"$'\e[0m'
    assertEscapeCodes "Yellow escape code" "${expected}" "${result}"

    # Blue: \e[34m
    result=${ show blue "text"; }
    expected=$'\e[34m'"text"$'\e[0m'
    assertEscapeCodes "Blue escape code" "${expected}" "${result}"

    # Magenta: \e[35m
    result=${ show magenta "text"; }
    expected=$'\e[35m'"text"$'\e[0m'
    assertEscapeCodes "Magenta escape code" "${expected}" "${result}"

    # Cyan: \e[36m
    result=${ show cyan "text"; }
    expected=$'\e[36m'"text"$'\e[0m'
    assertEscapeCodes "Cyan escape code" "${expected}" "${result}"

    # White: \e[37m
    result=${ show white "text"; }
    expected=$'\e[37m'"text"$'\e[0m'
    assertEscapeCodes "White escape code" "${expected}" "${result}"
}

testEscapeCodesBrightColors() {
    echo ""
    echo "Testing Bright Color Escape Codes"
    echo "=================================="
    echo ""

    local result expected

    # Bright Black: \e[90m
    result=${ show bright-black "text"; }
    expected=$'\e[90m'"text"$'\e[0m'
    assertEscapeCodes "Bright-black escape code" "${expected}" "${result}"

    # Bright Red: \e[91m
    result=${ show bright-red "text"; }
    expected=$'\e[91m'"text"$'\e[0m'
    assertEscapeCodes "Bright-red escape code" "${expected}" "${result}"

    # Bright Green: \e[92m
    result=${ show bright-green "text"; }
    expected=$'\e[92m'"text"$'\e[0m'
    assertEscapeCodes "Bright-green escape code" "${expected}" "${result}"

    # Bright Yellow: \e[93m
    result=${ show bright-yellow "text"; }
    expected=$'\e[93m'"text"$'\e[0m'
    assertEscapeCodes "Bright-yellow escape code" "${expected}" "${result}"

    # Bright Blue: \e[94m
    result=${ show bright-blue "text"; }
    expected=$'\e[94m'"text"$'\e[0m'
    assertEscapeCodes "Bright-blue escape code" "${expected}" "${result}"

    # Bright Magenta: \e[95m
    result=${ show bright-magenta "text"; }
    expected=$'\e[95m'"text"$'\e[0m'
    assertEscapeCodes "Bright-magenta escape code" "${expected}" "${result}"

    # Bright Cyan: \e[96m
    result=${ show bright-cyan "text"; }
    expected=$'\e[96m'"text"$'\e[0m'
    assertEscapeCodes "Bright-cyan escape code" "${expected}" "${result}"

    # Bright White: \e[97m
    result=${ show bright-white "text"; }
    expected=$'\e[97m'"text"$'\e[0m'
    assertEscapeCodes "Bright-white escape code" "${expected}" "${result}"
}

testEscapeCodes256Colors() {
    echo ""
    echo "Testing 256 Color Escape Codes"
    echo "=============================="
    echo ""

    local result expected

    # 256 color format: \e[38;5;Nm where N is 0-255
    # Test color 0
    result=${ show IDX 0 "text"; }
    expected=$'\033[38;5;0m'"text"$'\e[0m'
    assertEscapeCodes "256 color: 0" "${expected}" "${result}"

    # Test color 196 (red)
    result=${ show IDX 196 "text"; }
    expected=$'\033[38;5;196m'"text"$'\e[0m'
    assertEscapeCodes "256 color: 196" "${expected}" "${result}"

    # Test color 46 (green)
    result=${ show IDX 46 "text"; }
    expected=$'\033[38;5;46m'"text"$'\e[0m'
    assertEscapeCodes "256 color: 46" "${expected}" "${result}"

    # Test color 255 (max)
    result=${ show IDX 255 "text"; }
    expected=$'\033[38;5;255m'"text"$'\e[0m'
    assertEscapeCodes "256 color: 255" "${expected}" "${result}"

    # Test that 256+ is treated as text, not color
    result=${ show IDX 256 "text"; }
    expected="IDX 256 text"$'\e[0m'
    assertEscapeCodes "Invalid 256 color (256) treated as text" "${expected}" "${result}"

    result=${ show IDX 999 "text"; }
    expected="IDX 999 text"$'\e[0m'
    assertEscapeCodes "Invalid 256 color (999) treated as text" "${expected}" "${result}"

    # Test that numeric values without IDX are treated as text
    result=${ show 42 "text"; }
    expected="42 text"$'\e[0m'
    assertEscapeCodes "Numeric value without IDX treated as text" "${expected}" "${result}"
}

testEscapeCodesRGBColors() {
    echo ""
    echo "Testing RGB Color Escape Codes"
    echo "=============================="
    echo ""

    local result expected

    # RGB format: \e[38;2;R;G;Bm
    # Test RGB green (52:208:88)
    result=${ show RGB 52:208:88 "text"; }
    expected=$'\e[38;2;52;208;88m'"text"$'\e[0m'
    assertEscapeCodes "RGB color: green (52:208:88)" "${expected}" "${result}"

    # Test RGB red (215:58:73)
    result=${ show RGB 215:58:73 "text"; }
    expected=$'\e[38;2;215;58;73m'"text"$'\e[0m'
    assertEscapeCodes "RGB color: red (215:58:73)" "${expected}" "${result}"

    # Test RGB with zeros
    result=${ show RGB 0:0:0 "text"; }
    expected=$'\e[38;2;0;0;0m'"text"$'\e[0m'
    assertEscapeCodes "RGB color: black (0:0:0)" "${expected}" "${result}"

    # Test RGB with max values
    result=${ show RGB 255:255:255 "text"; }
    expected=$'\e[38;2;255;255;255m'"text"$'\e[0m'
    assertEscapeCodes "RGB color: white (255:255:255)" "${expected}" "${result}"
}

testEscapeCodesStyleCombinations() {
    echo ""
    echo "Testing Style Combination Escape Codes"
    echo "======================================="
    echo ""

    local result expected

    # Bold + Italic
    result=${ show bold italic "text"; }
    expected=$'\e[1m\e[3m'"text"$'\e[0m'
    assertEscapeCodes "Bold + Italic" "${expected}" "${result}"

    # Bold + Red
    result=${ show bold red "text"; }
    expected=$'\e[1m\e[31m'"text"$'\e[0m'
    assertEscapeCodes "Bold + Red" "${expected}" "${result}"

    # Italic + Underline + Green
    result=${ show italic underline green "text"; }
    expected=$'\e[3m\e[4m\e[32m'"text"$'\e[0m'
    assertEscapeCodes "Italic + Underline + Green" "${expected}" "${result}"

    # Bold + Italic + Underline
    result=${ show bold italic underline "text"; }
    expected=$'\e[1m\e[3m\e[4m'"text"$'\e[0m'
    assertEscapeCodes "Bold + Italic + Underline" "${expected}" "${result}"

    # Bold + 256 color
    result=${ show bold IDX 196 "text"; }
    expected=$'\e[1m\033[38;5;196m'"text"$'\e[0m'
    assertEscapeCodes "Bold + 256 color (196)" "${expected}" "${result}"

    # Italic + RGB color
    result=${ show italic RGB 52:208:88 "text"; }
    expected=$'\e[3m\e[38;2;52;208;88m'"text"$'\e[0m'
    assertEscapeCodes "Italic + RGB color" "${expected}" "${result}"

    # All styles combined
    result=${ show bold italic underline dim reverse "text"; }
    expected=$'\e[1m\e[3m\e[4m\e[2m\e[7m'"text"$'\e[0m'
    assertEscapeCodes "All styles: bold+italic+underline+dim+reverse" "${expected}" "${result}"
}

testEscapeCodesResets() {
    echo ""
    echo "Testing Reset Escape Codes"
    echo "=========================="
    echo ""

    local result expected

    # Plain resets all formatting: \e[0m
    result=${ show bold green "text1" plain "text2"; }
    expected=$'\e[1m\e[32m'"text1 "$'\e[0m'"text2"$'\e[0m'
    assertEscapeCodes "Plain resets formatting" "${expected}" "${result}"

    # Plain between color and style
    result=${ show blue "text1" plain italic "text2"; }
    expected=$'\e[34m'"text1 "$'\e[0m\e[3m'"text2"$'\e[0m'
    assertEscapeCodes "Plain between color and style" "${expected}" "${result}"

    # Multiple plain resets
    result=${ show bold "text1" plain "text2" plain "text3"; }
    expected=$'\e[1m'"text1 "$'\e[0m'"text2 "$'\e[0m'"text3"$'\e[0m'
    assertEscapeCodes "Multiple plain resets" "${expected}" "${result}"

    # Final reset always applied
    result=${ show bold red "text"; }
    expected=$'\e[1m\e[31m'"text"$'\e[0m'
    assertEscapeCodes "Final reset code present" "${expected}" "${result}"

    # No arguments - just newline, no reset code
    result=${ show; }
    expected=''
    assertEscapeCodes "No arguments produces empty output" "${expected}" "${result}"

    # Format only, no text - just final reset
    result=${ show bold red; }
    expected=$'\e[0m'
    assertEscapeCodes "Format only produces only reset" "${expected}" "${result}"
}

testEscapeCodesComplexPatterns() {
    echo ""
    echo "Testing Complex Pattern Escape Codes"
    echo "====================================="
    echo ""

    local result expected

    # Style persistence: italic continues across arguments
    result=${ show italic "text1" blue "text2"; }
    expected=$'\e[3m'"text1 "$'\e[34m'"text2"$'\e[0m'
    assertEscapeCodes "Style persistence with color change" "${expected}" "${result}"

    # Color replacement: blue replaced by red, bold persists
    result=${ show bold blue "text1" red "text2"; }
    expected=$'\e[1m\e[34m'"text1 "$'\e[31m'"text2"$'\e[0m'
    assertEscapeCodes "Color replacement with style persistence" "${expected}" "${result}"

    # Multiple arguments with accumulating styles
    result=${ show "text1" bold "text2" italic "text3"; }
    expected="text1 "$'\e[1m'"text2 "$'\e[3m'"text3"$'\e[0m'
    assertEscapeCodes "Accumulating styles across arguments" "${expected}" "${result}"

    # Plain reset, then new style
    result=${ show bold green "text1" plain dim "text2"; }
    expected=$'\e[1m\e[32m'"text1 "$'\e[0m\e[2m'"text2"$'\e[0m'
    assertEscapeCodes "Reset then new style" "${expected}" "${result}"

    # Documented pattern: cyan to dim via plain
    result=${ show cyan "colored text" plain dim "dim text"; }
    expected=$'\e[36m'"colored text "$'\e[0m\e[2m'"dim text"$'\e[0m'
    assertEscapeCodes "Cyan to dim via plain" "${expected}" "${result}"

    # Multiple text with multiple color changes
    result=${ show red "A" blue "B" green "C"; }
    expected=$'\e[31m'"A "$'\e[34m'"B "$'\e[32m'"C"$'\e[0m'
    assertEscapeCodes "Multiple color changes" "${expected}" "${result}"
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
        echo ""
        echo "The show() function is working correctly with:"
        echo "  • Basic colors and styles"
        echo "  • Format combinations"
        echo "  • Style persistence and color replacement"
        echo "  • Critical 'plain' reset pattern"
        echo "  • Command substitution (bash 5.3+)"
        echo "  • Theme colors"
        echo "  • 256 color codes"
        echo "  • RGB colors"
        echo "  • All documented patterns"
        echo "  • Correct ANSI escape code generation"
        return 0
    else
        echo "✗ Some tests failed"
        return 1
    fi
}

# If we're not running in a terminal, set a flag to force core to act as if we are
[[ -t 1 && -t 2 ]] || declare -gx forceRayvn24BitColor=1

source rayvn.up 'rayvn/core' 'rayvn/test'
main "${@}"
