#!/usr/bin/env bash

main() {
    init "$@"

    testTypistAsciinemaEventsFormat
    testTypistAsciinemaEventsCount
    testAsciinemaTypingFile
    testAsciinemaPostProcessV2Prepend
    testAsciinemaPostProcessV2Shift
    testAsciinemaPostProcessNoTrim
    testAsciinemaComputeDimensions

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

# ============================================================================
# typistAsciinemaEvents
# ============================================================================

testTypistAsciinemaEventsFormat() {
    local output; output=${ typistAsciinemaEvents 120 'hi'; }
    local line
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        assertTrue "event line is valid JSON array: ${line}" \
            eval "printf '%s' '${line}' | jq -e 'type == \"array\" and length == 3' > /dev/null 2>&1"
        assertTrue "event type is 'o': ${line}" \
            eval "printf '%s' '${line}' | jq -e '.[1] == \"o\"' > /dev/null 2>&1"
    done <<< "${output}"
}

testTypistAsciinemaEventsCount() {
    local text='hi' output; output=${ typistAsciinemaEvents 120 "${text}"; }
    # Use printf '%s\n' to restore the trailing newline stripped by ${ ; }
    local count; count=${ printf '%s\n' "${output}" | wc -l | tr -d ' '; }
    # One line per char + one Enter line
    assertEqual $(( ${#text} + 1 )) "${count}" "event count = len(text) + 1 (Enter)"
}

# ============================================================================
# asciinemaTypingFile
# ============================================================================

testAsciinemaTypingFile() {
    local cmd='echo hi'
    local f; f=${ makeTempFile; }
    asciinemaTypingFile 120 '[test]$ ' "${cmd}" "${f}"
    assertTrue "typing file exists and is non-empty" eval "[[ -s '${f}' ]]"

    local firstLine; firstLine=${ head -1 "${f}"; }
    assertTrue "first line contains prompt" \
        eval "[[ '${firstLine}' == *'[test]\$ '* ]]"

    local lineCount; lineCount=${ wc -l < "${f}" | tr -d ' '; }
    # 1 prompt + len(cmd) chars + 1 Enter = 1 + 7 + 1 = 9
    assertEqual $(( 1 + ${#cmd} + 1 )) "${lineCount}" "line count"
}

# ============================================================================
# asciinemaPostProcess
# ============================================================================

# Write a minimal v2 cast to a temp file
_makeV2Cast() {
    local castFile=$1
    printf '{"version":2,"width":220,"height":60}\n' > "${castFile}"
    printf '[1.0, "o", "hello"]\n' >> "${castFile}"
    printf '[2.0, "o", "world"]\n' >> "${castFile}"
}

testAsciinemaPostProcessV2Prepend() {
    local castFile; castFile=${ makeTempFile; }
    _makeV2Cast "${castFile}"

    local typingFile; typingFile=${ makeTempFile; }
    printf '[0.3, "o", "[t]$ "]\n' > "${typingFile}"
    printf '[0.1, "o", "x"]\n'    >> "${typingFile}"

    asciinemaPostProcess "${castFile}" "${typingFile}" 0

    local lineCount; lineCount=${ wc -l < "${castFile}" | tr -d ' '; }
    # 1 header + 2 typing lines + 2 original events = 5
    assertEqual 5 "${lineCount}" "typing events prepended"

    # First event line after header should be the prompt
    local secondLine; secondLine=${ sed -n '2p' "${castFile}"; }
    assertTrue "first event is prompt" eval "[[ '${secondLine}' == *'[t]\$ '* ]]"
}

testAsciinemaPostProcessV2Shift() {
    local castFile; castFile=${ makeTempFile; }
    _makeV2Cast "${castFile}"

    # Total typing duration: 0.3 + 0.1 = 0.4s
    local typingFile; typingFile=${ makeTempFile; }
    printf '[0.3, "o", "a"]\n' > "${typingFile}"
    printf '[0.1, "o", "b"]\n' >> "${typingFile}"

    asciinemaPostProcess "${castFile}" "${typingFile}" 0

    # Original first event was at t=1.0; after shift by 0.4 it should be ~1.4
    local firstOrigTs; firstOrigTs=${ sed -n '4p' "${castFile}" | jq '.[0]'; }
    assertTrue "original events shifted forward" \
        eval "awk 'BEGIN{exit !(${firstOrigTs} > 1.0)}'"
}

testAsciinemaPostProcessNoTrim() {
    local castFile; castFile=${ makeTempFile; }
    _makeV2Cast "${castFile}"
    local typingFile; typingFile=${ makeTempFile; }
    printf '[0.1, "o", "x"]\n' > "${typingFile}"

    asciinemaPostProcess "${castFile}" "${typingFile}" 0

    local header; header=${ head -1 "${castFile}"; }
    assertEqual 220 "${ printf '%s' "${header}" | jq '.width'; }" "width unchanged with no-trim"
    assertEqual 60  "${ printf '%s' "${header}" | jq '.height'; }" "height unchanged with no-trim"
}

# ============================================================================
# _asciinemaComputeDimensions
# ============================================================================

testAsciinemaComputeDimensions() {
    local castFile; castFile=${ makeTempFile; }
    printf '{"version":2,"width":220,"height":60}\n' > "${castFile}"
    # 20 visible chars on one line, cursor positioned at row 3
    printf '[1.0, "o", "12345678901234567890"]\n' >> "${castFile}"
    printf '[2.0, "o", "\\u001b[3;1H"]\n' >> "${castFile}"

    local cols rows
    _asciinemaComputeDimensions "${castFile}" cols rows

    # cols: max(20 + 4, 106) = 106
    assertEqual 106 "${cols}" "cols floored at 106"
    # rows: 3 + 1 = 4
    assertEqual 4 "${rows}" "rows = max_cursor_row + 1"
}

source rayvn.up 'rayvn/asciinema' 'rayvn/test'
main "$@"
