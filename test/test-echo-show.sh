#!/usr/bin/env bash

main() {
    init "${@}"
    testEcho
    testShow
    testEquivalence
    testEdgeCases

    if (( failCount == 0 )); then
        builtin echo "  ✓ All tests passed!"
        builtin echo ""
        builtin echo "Both echo and show functions are working correctly:"
        builtin echo "  • echo: Fast path optimization, formats must precede text"
        builtin echo "  • show: Flexible positioning, formats can be anywhere"
        builtin echo "  • Both: Full ANSI color/style support"
        builtin echo "  • show: Bonus 256-color code support (0-255)"
        return 0
    else
        builtin echo "  ✗ Some tests failed"
        return 1
    fi
}

init() {
    declare -gi testCount=0
    declare -gi passCount=0
    declare -gi failCount=0
}

# Helper to strip ANSI codes using sed
stripAnsi() {
    builtin echo -n "${1}" | sed 's/\x1b\[[0-9;]*m//g'
}

# Test assertion
assert() {
    local testName=${1}
    local expected=${2}
    local actual=${3}
    local compareType=${4:-exact}  # exact or stripped

    (( testCount++ ))

    local expectedCompare=${expected}
    local actualCompare=${actual}

    if [[ ${compareType} == "stripped" ]]; then
        expectedCompare=${ stripAnsi "${expected}"; }
        actualCompare=${ stripAnsi "${actual}"; }
    fi

    if [[ ${actualCompare} == ${expectedCompare} ]]; then
        (( passCount++ ))
        builtin echo "  ✓ ${testName}"
        return 0
    else
        (( failCount++ ))
        builtin echo "  ✗ ${testName}"
        builtin echo "    Expected: '${expected}'"
        builtin echo "    Actual:   '${actual}'"
        if [[ ${compareType} == "stripped" ]]; then
            builtin echo "    Expected (stripped): '${expectedCompare}'"
            builtin echo "    Actual (stripped):   '${actualCompare}'"
        fi
        return 1
    fi
}

# Test suite for echo
testEcho() {
    builtin echo ""
    builtin echo "Testing echo function"
    builtin echo "====================="
    builtin echo ""

    local result

    # Test 1: Plain text (fast path)
    result=${ echo "plain text"; }
    assert "Plain text fast path" "plain text" "${result}" "stripped"

    # Test 2: Multiple words plain text
    result=${ echo "multiple words here"; }
    assert "Multiple words plain text" "multiple words here" "${result}" "stripped"

    # Test 3: Single color format
    result=${ echo red "red text"; }
    assert "Single color format" "red text" "${result}" "stripped"

    # Test 4: Multiple format keywords
    result=${ echo bold red "bold red"; }
    assert "Multiple formats" "bold red" "${result}" "stripped"

    # Test 5: Theme color
    result=${ echo success "success message"; }
    assert "Theme color (success)" "success message" "${result}" "stripped"

    # Test 6: All theme colors with different text
    result=${ echo error "This is an error"; }
    assert "Theme color (error)" "This is an error" "${result}" "stripped"

    result=${ echo warning "This is a warning"; }
    assert "Theme color (warning)" "This is a warning" "${result}" "stripped"

    result=${ echo info "This is info"; }
    assert "Theme color (info)" "This is info" "${result}" "stripped"

    result=${ echo accent "This has accent"; }
    assert "Theme color (accent)" "This has accent" "${result}" "stripped"

    result=${ echo muted "This is muted"; }
    assert "Theme color (muted)" "This is muted" "${result}" "stripped"

    # Test 7: Text styles with different text
    result=${ echo bold "This is bold"; }
    assert "Bold style" "This is bold" "${result}" "stripped"

    result=${ echo italic "This is italic"; }
    assert "Italic style" "This is italic" "${result}" "stripped"

    result=${ echo underline "underlined text"; }
    assert "Underline style" "underlined text" "${result}" "stripped"

    # Test 8: Complex formatting
    result=${ echo bold italic underline green "complex"; }
    assert "Complex multi-format" "complex" "${result}" "stripped"

    # Test 9: Format keywords without text
    result=${ echo bold red; }
    assert "Format keywords only" "" "${result}" "stripped"

    # Test 10: No arguments
    result=${ echo; }
    assert "No arguments" "" "${result}" "exact"

    # Test 11: With -n option
    result=${ echo -n "no newline"; }
    assert "Option -n (no newline)" "no newline" "${result}" "stripped"

    # Test 12: With -n and format
    result=${ echo -n blue "blue no newline"; }
    assert "Option -n with format" "blue no newline" "${result}" "stripped"

    # Test 13: Multiple options
    result=${ echo -n -e "options"; }
    assert "Multiple options" "options" "${result}" "stripped"

    # Test 14: Options with multiple formats
    result=${ echo -n bold red "formatted no newline"; }
    assert "Options with formats" "formatted no newline" "${result}" "stripped"

    # Test 15: Reset format
    result=${ echo reset "reset text"; }
    assert "Reset format" "reset text" "${result}" "stripped"

    # Test 16: Bright colors
    result=${ echo bright-red "bright red text"; }
    assert "Bright color" "bright red text" "${result}" "stripped"

    # Test 17: All basic colors
    for color in black red green yellow blue magenta cyan white; do
        result=${ echo ${color} "colored text"; }
        assert "Basic color (${color})" "colored text" "${result}" "stripped"
    done

    # Test 18: Format followed by multiple words
    result=${ echo green "multiple words after format"; }
    assert "Format with multiple words" "multiple words after format" "${result}" "stripped"

    # Test 19: ANSI reset code is appended when there are formats
    result=${ echo red "text"; }
    [[ ${result} == *$'\e[0m' ]] && assert "ANSI reset appended" "true" "true" || assert "ANSI reset appended" "true" "false"

    # Test 20: Fast path doesn't add ANSI codes
    result=${ echo "plain"; }
    [[ ${result} != *$'\e['* ]] && assert "Fast path no ANSI" "true" "true" || assert "Fast path no ANSI" "true" "false"

    # Test 21: When first arg is format name but as text (not fast path)
    # This should output nothing since both are formats with no following text
    result=${ echo bold; }
    assert "Single format keyword only" "" "${result}" "stripped"
}

# Test suite for show
testShow() {
    builtin echo ""
    builtin echo "Testing show function"
    builtin echo "====================="
    builtin echo ""

    local result

    # Test 1: Plain text
    result=${ show "plain text"; }
    assert "Plain text" "plain text" "${result}" "stripped"

    # Test 2: Single color format (leading)
    result=${ show red "red text"; }
    assert "Single color format (leading)" "red text" "${result}" "stripped"

    # Test 3: Multiple format keywords (leading)
    result=${ show bold red "bold red"; }
    assert "Multiple formats (leading)" "bold red" "${result}" "stripped"

    # Test 4: Format in middle of text
    result=${ show "Start" red "middle" "end"; }
    assert "Format in middle" "Start middle end" "${result}" "stripped"

    # Test 5: Multiple interleaved formats
    result=${ show "A" red "B" blue "C" green "D"; }
    assert "Multiple interleaved" "A B C D" "${result}" "stripped"

    # Test 6: Format at end (no text after)
    result=${ show "text" red; }
    assert "Format at end (no text after)" "text" "${result}" "stripped"

    # Test 7: Theme colors
    result=${ show success "success message"; }
    assert "Theme color (success)" "success message" "${result}" "stripped"

    result=${ show error "error message"; }
    assert "Theme color (error)" "error message" "${result}" "stripped"

    # Test 8: Text styles interleaved
    result=${ show "Normal" bold "This is bold" italic "This is italic"; }
    assert "Interleaved styles" "Normal This is bold This is italic" "${result}" "stripped"

    # Test 9: Complex interleaving
    result=${ show bold "Some" red "mixed" green "text"; }
    assert "Complex interleaving" "Some mixed text" "${result}" "stripped"

    # Test 10: No arguments
    result=${ show; }
    assert "No arguments" "" "${result}" "exact"

    # Test 11: With -n option
    result=${ show -n "no newline"; }
    assert "Option -n (no newline)" "no newline" "${result}" "stripped"

    # Test 12: With -n and interleaved format
    result=${ show -n "Text" blue "more"; }
    assert "Option -n with interleaved" "Text more" "${result}" "stripped"

    # Test 13: Multiple options
    result=${ show -n -e "options"; }
    assert "Multiple options" "options" "${result}" "stripped"

    # Test 14: 256 color code
    result=${ show 196 "red via 256"; }
    assert "256 color code (196)" "red via 256" "${result}" "stripped"

    # Test 15: Mix format names and 256 colors
    result=${ show bold 196 "formatted"; }
    assert "Mix format and 256 color" "formatted" "${result}" "stripped"

    # Test 16: 256 color interleaved (use non-format text to avoid ambiguity)
    result=${ show "Start" 196 "apple" 46 "lime" "end"; }
    assert "256 colors interleaved" "Start apple lime end" "${result}" "stripped"

    # Test 17: Edge case - 0 color code
    result=${ show 0 "text with color 0"; }
    assert "256 color code (0)" "text with color 0" "${result}" "stripped"

    # Test 18: Edge case - 255 color code
    result=${ show 255 "text with color 255"; }
    assert "256 color code (255)" "text with color 255" "${result}" "stripped"

    # Test 19: Invalid 256 color (over 255) treated as text
    result=${ show 256 "text"; }
    assert "Invalid 256 color (>255)" "256 text" "${result}" "stripped"

    # Test 20: Multiple formats on same text
    result=${ show bold italic underline "multi-styled"; }
    assert "Multiple formats same text" "multi-styled" "${result}" "stripped"

    # Test 21: Format doesn't carry to next text
    result=${ show bold "A" "B"; }
    assert "Format doesn't carry over" "A B" "${result}" "stripped"

    # Test 22: Reset format mid-stream
    result=${ show red "red text" reset "back to normal"; }
    assert "Reset format mid-stream" "red text back to normal" "${result}" "stripped"

    # Test 23: All basic colors work
    for color in black red green yellow blue magenta cyan white; do
        result=${ show ${color} "colored text"; }
        assert "Basic color in show (${color})" "colored text" "${result}" "stripped"
    done

    # Test 24: Empty string argument
    result=${ show ""; }
    assert "Empty string argument" "" "${result}" "stripped"

    # Test 25: ANSI reset code is appended
    result=${ show red "text"; }
    [[ ${result} == *$'\e[0m' ]] && assert "ANSI reset appended" "true" "true" || assert "ANSI reset appended" "true" "false"

    # Test 26: Spacing between words is preserved
    result=${ show "word1" "word2" "word3"; }
    assert "Spacing between words" "word1 word2 word3" "${result}" "stripped"

    # Test 27: Multiple text without formats
    result=${ show "one" "two" "three"; }
    assert "Multiple text args no format" "one two three" "${result}" "stripped"

    # Test 28: Format only (no text)
    result=${ show bold red; }
    assert "Formats only (no text)" "" "${result}" "stripped"
}

# Comparison tests (echo vs show equivalence)
testEquivalence() {
    builtin echo ""
    builtin echo "Testing echo/show equivalence"
    builtin echo "=============================="
    builtin echo ""

    local echoResult showResult

    # Test 1: Simple format equivalence
    echoResult=${ echo red "text"; }
    showResult=${ show red "text"; }
    assert "Equivalence: simple format" "${ stripAnsi "${echoResult}"; }" "${ stripAnsi "${showResult}"; }" "exact"

    # Test 2: Multiple formats equivalence
    echoResult=${ echo bold blue "text"; }
    showResult=${ show bold blue "text"; }
    assert "Equivalence: multiple formats" "${ stripAnsi "${echoResult}"; }" "${ stripAnsi "${showResult}"; }" "exact"

    # Test 3: Theme color equivalence
    echoResult=${ echo success "message"; }
    showResult=${ show success "message"; }
    assert "Equivalence: theme color" "${ stripAnsi "${echoResult}"; }" "${ stripAnsi "${showResult}"; }" "exact"

    # Test 4: With -n option equivalence
    echoResult=${ echo -n yellow "text"; }
    showResult=${ show -n yellow "text"; }
    assert "Equivalence: -n option" "${ stripAnsi "${echoResult}"; }" "${ stripAnsi "${showResult}"; }" "exact"

    # Test 5: Plain text equivalence
    echoResult=${ echo "plain text"; }
    showResult=${ show "plain text"; }
    # Both should output plain text, but show always adds reset
    assert "Equivalence: plain text (content)" "${ stripAnsi "${echoResult}"; }" "${ stripAnsi "${showResult}"; }" "exact"
}

# Edge cases and error conditions
testEdgeCases() {
    builtin echo ""
    builtin echo "Testing edge cases"
    builtin echo "=================="
    builtin echo ""

    local result

    # Test 1: Very long text
    local longText="This is a very long text string that contains many words and should be handled correctly by both functions without any issues or truncation problems"
    result=${ echo green "${longText}"; }
    assert "Echo: very long text" "${longText}" "${ stripAnsi "${result}"; }" "exact"

    result=${ show green "${longText}"; }
    assert "Show: very long text" "${longText}" "${ stripAnsi "${result}"; }" "exact"

    # Test 2: Special characters in text
    result=${ echo red "text with \$special @chars!"; }
    assert "Echo: special characters" "text with \$special @chars!" "${ stripAnsi "${result}"; }" "exact"

    result=${ show red "text with \$special @chars!"; }
    assert "Show: special characters" "text with \$special @chars!" "${ stripAnsi "${result}"; }" "exact"

    # Test 3: Text that looks like format but isn't (fast path triggered)
    result=${ echo notaformat "text"; }
    assert "Echo: non-format at start triggers fast path" "notaformat text" "${ stripAnsi "${result}"; }" "exact"

    # Test 4: Mix of valid and invalid format names
    result=${ show red "valid" notaformat "text"; }
    assert "Show: invalid format name treated as text" "valid notaformat text" "${ stripAnsi "${result}"; }" "exact"

    # Test 5: Numeric text (not 256 color)
    result=${ show 300 "text"; }
    assert "Show: number >255 as text" "300 text" "${ stripAnsi "${result}"; }" "exact"

    # Test 6: Many consecutive formats
    result=${ echo bold italic underline dim reverse "all styles"; }
    assert "Echo: many consecutive formats" "all styles" "${ stripAnsi "${result}"; }" "exact"

    result=${ show bold italic underline dim reverse "all styles"; }
    assert "Show: many consecutive formats" "all styles" "${ stripAnsi "${result}"; }" "exact"

    # Test 7: Alternating formats and text
    result=${ show red "A" blue "B" green "C" yellow "D" magenta "E"; }
    assert "Show: alternating formats/text" "A B C D E" "${ stripAnsi "${result}"; }" "exact"

    # Test 8: Format names that collide with text
    result=${ show "The word red" red "is now red"; }
    assert "Show: format name in text" "The word red is now red" "${ stripAnsi "${result}"; }" "exact"
}

source rayvn.up 'rayvn/core' 'rayvn/test' 'rayvn/debug'
main "${@}"
