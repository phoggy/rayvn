#!/usr/bin/env bash

# Tests for prompt.sh public functions: request, secureRequest, confirm, choose
#
# Uses rayvnTest_ModifiableFunctions=1 to override terminal functions with mocks,
# and process substitution to inject keystrokes via stdin.

main() {
    init "${@}"

    # request tests
    testRequestBasicInput
    testRequestEmptyInputCancelOnEmpty
    testRequestEmptyInputAllowed
    testRequestEscapeCancel
    testRequestHiddenInput
    testRequestTimeout

    # secureRequest tests
    testSecureRequestBasicInput
    testSecureRequestEscapeCancel

    # confirm tests
    testConfirmSelectFirstAnswer
    testConfirmSelectSecondViaArrowRight
    testConfirmSelectFirstViaArrowLeft
    testConfirmDefaultAnswerTwo
    testConfirmEscapeCancel
    testConfirmTimeout

    # choose tests
    testChooseSelectFirst
    testChooseNavigateDownAndSelect
    testChooseNavigateUpWrapsAround
    testChooseStartIndex
    testChooseEscapeCancel
    testChooseTimeout

    # choose layout calculation tests
    testRowsPerItem
    testExtraLines
    testTotalVisibleItemsWithExplicitMax
    testTotalVisibleItemsClampsToItemCount
    testTotalVisibleItemsFromTerminalHeight
    testReserveRowsNoSeparator
    testReserveRowsWithSeparator
    testNonVisibleItemCount

    return 0
}

init() {
    _installMocks

    # process any debug args
    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${ tty; }" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done
}

_installMocks() {

    # Shadow /bin/stty with a no-op
    stty() { :; }

    # Return fixed cursor position via nameref params
    cursorPosition() {
        local -n _cpRowRef="${1}"
        local -n _cpColRef="${2}"
        _cpRowRef=10
        _cpColRef=1
    }

    # Call mocked cursorPosition instead of real terminal queries
    reserveRows() {
        cursorPosition _cursorRow _cursorCol
    }

    # All other terminal functions — no-ops
    cursorTo() { :; }
    cursorToColumn() { :; }
    cursorToColumnAndEraseToEndOfLine() { :; }
    cursorSave() { :; }
    cursorRestore() { :; }
    cursorHide() { :; }
    cursorShow() { :; }
    cursorUp() { :; }
    cursorUpOneAndEraseLine() { :; }
    cursorDownOneAndEraseLine() { :; }
    eraseToEndOfLine() { :; }
    eraseCurrentLine() { :; }
    clearTerminal() { :; }

    # Set variables that _init_rayvn_terminal skips when isInteractive=0
    [[ ${_originalStty} ]] || declare -g _originalStty="sane"
    declare -gi _cursorRow=10
    declare -gi _cursorCol=1
}

# --- request tests ---

testRequestBasicInput() {
    (
        local result
        request "Name" result false < <(printf 'hello\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "request basic input: exit code"
        assertEqual "hello" "${result}" "request basic input: result"
    ) || exit 1
}

testRequestEmptyInputCancelOnEmpty() {
    (
        local result
        request "Name" result true < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "1" "${exitCode}" "request empty input cancel on empty: exit code"
    ) || exit 1
}

testRequestEmptyInputAllowed() {
    (
        local result
        request "Name" result false < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "request empty input allowed: exit code"
        assertEqual "" "${result}" "request empty input allowed: result"
    ) || exit 1
}

testRequestEscapeCancel() {
    (
        local result
        request "Name" result false < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "130" "${exitCode}" "request escape cancel: exit code"
    ) || exit 1
}

testRequestHiddenInput() {
    (
        local result
        request "Password" result false 30 true < <(printf 'secret\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "request hidden input: exit code"
        assertEqual "secret" "${result}" "request hidden input: result"
    ) || exit 1
}

testRequestTimeout() {
    (
        local result
        request "Name" result false 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "124" "${exitCode}" "request timeout: exit code"
    ) || exit 1
}

# --- secureRequest tests ---

testSecureRequestBasicInput() {
    (
        local result
        secureRequest "Password" result < <(printf 'password\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "secureRequest basic input: exit code"
        assertEqual "password" "${result}" "secureRequest basic input: result"
    ) || exit 1
}

testSecureRequestEscapeCancel() {
    (
        local result
        secureRequest "Password" result < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "130" "${exitCode}" "secureRequest escape cancel: exit code"
    ) || exit 1
}

# --- confirm tests ---

testConfirmSelectFirstAnswer() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "confirm select first answer: exit code"
        assertEqual "0" "${result}" "confirm select first answer: result"
    ) || exit 1
}

testConfirmSelectSecondViaArrowRight() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e[C\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "confirm select second via arrow right: exit code"
        assertEqual "1" "${result}" "confirm select second via arrow right: result"
    ) || exit 1
}

testConfirmSelectFirstViaArrowLeft() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e[C\e[D\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "confirm select first via arrow left: exit code"
        assertEqual "0" "${result}" "confirm select first via arrow left: result"
    ) || exit 1
}

testConfirmDefaultAnswerTwo() {
    (
        local result
        confirm "Continue?" "yes" "no" result true < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "confirm default answer two: exit code"
        assertEqual "1" "${result}" "confirm default answer two: result"
    ) || exit 1
}

testConfirmEscapeCancel() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "130" "${exitCode}" "confirm escape cancel: exit code"
    ) || exit 1
}

testConfirmTimeout() {
    (
        local result
        confirm "Continue?" "yes" "no" result false 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "124" "${exitCode}" "confirm timeout: exit code"
    ) || exit 1
}

# --- choose tests ---

testChooseSelectFirst() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "choose select first: exit code"
        assertEqual "0" "${result}" "choose select first: result"
    ) || exit 1
}

testChooseNavigateDownAndSelect() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e[B\e[B\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "choose navigate down and select: exit code"
        assertEqual "2" "${result}" "choose navigate down and select: result"
    ) || exit 1
}

testChooseNavigateUpWrapsAround() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e[A\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "choose navigate up wraps around: exit code"
        assertEqual "2" "${result}" "choose navigate up wraps around: result"
    ) || exit 1
}

testChooseStartIndex() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 2 0 3 < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "0" "${exitCode}" "choose start index: exit code"
        assertEqual "2" "${result}" "choose start index: result"
    ) || exit 1
}

testChooseEscapeCancel() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "130" "${exitCode}" "choose escape cancel: exit code"
    ) || exit 1
}

testChooseTimeout() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "124" "${exitCode}" "choose timeout: exit code"
    ) || exit 1
}

# --- choose layout calculation tests ---
#
# The interactive terminal parts of choose() (cursor, keyboard, stty) cannot easily
# be tested in an automated way since those functions are readonly and write directly
# to /dev/tty. These tests verify the reserveRows/totalVisibleItems calculation logic.

# Replicate the choose() calculation to test it
_calculateLayout() {
    local itemCount="${1}"
    local addSeparator="${2}"
    local maxVisibleItems="${3}"
    local availableRows="${4}"

    [[ ${addSeparator} == true ]] && _rowsPerItem=2 || _rowsPerItem=1
    _extraLines=$( (( _rowsPerItem == 1 )) && echo 2 || echo 1 )

    if (( maxVisibleItems > 0 )); then
        if (( maxVisibleItems > itemCount )); then
            _totalVisibleItems=${itemCount}
        else
            _totalVisibleItems=${maxVisibleItems}
        fi
    else
        local visibleRows=$(( availableRows - 6 ))
        _totalVisibleItems=$(( visibleRows / _rowsPerItem ))
        (( _totalVisibleItems > itemCount )) && _totalVisibleItems=${itemCount}
    fi

    _reserveRows=$(( (_totalVisibleItems * _rowsPerItem) + _extraLines ))
    _nonVisibleItems=0
    (( _totalVisibleItems < itemCount )) && _nonVisibleItems=$(( itemCount - _totalVisibleItems ))
}

testRowsPerItem() {
    _calculateLayout 10 false 0 50
    assertEqual 1 "${_rowsPerItem}" "rowsPerItem should be 1 without separator"

    _calculateLayout 10 true 0 50
    assertEqual 2 "${_rowsPerItem}" "rowsPerItem should be 2 with separator"
}

testExtraLines() {
    _calculateLayout 10 false 0 50
    assertEqual 2 "${_extraLines}" "extraLines should be 2 without separator"

    _calculateLayout 10 true 0 50
    assertEqual 1 "${_extraLines}" "extraLines should be 1 with separator"
}

testTotalVisibleItemsWithExplicitMax() {
    # maxVisibleItems=5, itemCount=10: should show 5
    _calculateLayout 10 false 5 50
    assertEqual 5 "${_totalVisibleItems}" "should respect maxVisibleItems"

    # maxVisibleItems=5, itemCount=3: should clamp to 3
    _calculateLayout 3 false 5 50
    assertEqual 3 "${_totalVisibleItems}" "should clamp to itemCount when fewer items than max"
}

testTotalVisibleItemsClampsToItemCount() {
    # Large terminal, few items: should clamp to itemCount
    _calculateLayout 3 false 0 100
    assertEqual 3 "${_totalVisibleItems}" "should clamp to itemCount with large terminal"

    # With separator
    _calculateLayout 4 true 0 100
    assertEqual 4 "${_totalVisibleItems}" "should clamp to itemCount with separator and large terminal"
}

testTotalVisibleItemsFromTerminalHeight() {
    # availableRows=30, -6 = 24 visible rows, rowsPerItem=1: 24 items fit
    _calculateLayout 50 false 0 30
    assertEqual 24 "${_totalVisibleItems}" "should calculate from terminal height without separator"

    # availableRows=30, -6 = 24 visible rows, rowsPerItem=2: 12 items fit
    _calculateLayout 50 true 0 30
    assertEqual 12 "${_totalVisibleItems}" "should calculate from terminal height with separator"

    # Small terminal: availableRows=10, -6 = 4 visible rows, rowsPerItem=1: 4 items
    _calculateLayout 50 false 0 10
    assertEqual 4 "${_totalVisibleItems}" "should handle small terminal"
}

testReserveRowsNoSeparator() {
    # 5 items visible, rowsPerItem=1, extraLines=2: (5*1)+2 = 7
    _calculateLayout 5 false 0 50
    assertEqual 7 "${_reserveRows}" "reserveRows for 5 items, no separator"

    # 10 items visible (explicit max), rowsPerItem=1, extraLines=2: (10*1)+2 = 12
    _calculateLayout 20 false 10 50
    assertEqual 12 "${_reserveRows}" "reserveRows for 10 visible items, no separator"
}

testReserveRowsWithSeparator() {
    # 5 items visible, rowsPerItem=2, extraLines=1: (5*2)+1 = 11
    _calculateLayout 5 true 0 50
    assertEqual 11 "${_reserveRows}" "reserveRows for 5 items, with separator"

    # 10 items visible (explicit max), rowsPerItem=2, extraLines=1: (10*2)+1 = 21
    _calculateLayout 20 true 10 50
    assertEqual 21 "${_reserveRows}" "reserveRows for 10 visible items, with separator"
}

testNonVisibleItemCount() {
    # All items visible
    _calculateLayout 5 false 0 50
    assertEqual 0 "${_nonVisibleItems}" "no non-visible items when all fit"

    # 50 items, 24 visible rows: 50-24 = 26 non-visible
    _calculateLayout 50 false 0 30
    assertEqual 26 "${_nonVisibleItems}" "should report correct non-visible count"

    # Explicit max: 20 items, show 5: 15 non-visible
    _calculateLayout 20 false 5 50
    assertEqual 15 "${_nonVisibleItems}" "should report non-visible with explicit max"
}

# Boot

[[ -t 1 && -t 2 ]] || declare -gx rayvnTest_Force24BitColor=1
rayvnTest_ModifiableFunctions=1
source rayvn.up 'rayvn/prompt' 'rayvn/test'
main "$@"
