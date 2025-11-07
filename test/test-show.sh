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
    echo ""
    echo "Testing Theme Colors"
    echo "===================="
    echo ""

    local result

    # All theme colors
    for theme in success error warning info accent muted; do
        result=${ show ${theme} "themed text"; }
        assertStripped "Theme color: ${theme}" "themed text" "${result}"
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
    result=${ show 196 "red via 256"; }
    assertStripped "256 color: 196 (red)" "red via 256" "${result}"

    result=${ show 46 "green via 256"; }
    assertStripped "256 color: 46 (green)" "green via 256" "${result}"

    # Edge cases: 0 and 255
    result=${ show 0 "color 0"; }
    assertStripped "256 color: 0" "color 0" "${result}"

    result=${ show 255 "color 255"; }
    assertStripped "256 color: 255" "color 255" "${result}"

    # Mix format names and 256 colors
    result=${ show bold 196 "bold red 256"; }
    assertStripped "256 color with style" "bold red 256" "${result}"

    # 256 colors interleaved
    result=${ show "Start" 196 "red" 46 "green" "end"; }
    assertStripped "256 colors interleaved" "Start end" "${result}"

    # Invalid 256 color (>255) treated as text
    result=${ show 256 "text"; }
    assertStripped "Invalid 256 color (256)" "256 text" "${result}"

    result=${ show 999 "text"; }
    assertStripped "Invalid 256 color (999)" "999 text" "${result}"
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
        return 0
    else
        echo "✗ Some tests failed"
        return 1
    fi
}

source rayvn.up 'rayvn/core' 'rayvn/test'
main "${@}"
