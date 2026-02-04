#!/usr/bin/env bash

# Tests for prompt.sh public functions: request, secureRequest, confirm, choose
#
# Uses doNotSetFunctionsReadOnly=1 to override terminal functions with mocks,
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
        assertEqual "${exitCode}" "0" "request basic input: exit code"
        assertEqual "${result}" "hello" "request basic input: result"
    ) || exit 1
}

testRequestEmptyInputCancelOnEmpty() {
    (
        local result
        request "Name" result true < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "1" "request empty input cancel on empty: exit code"
    ) || exit 1
}

testRequestEmptyInputAllowed() {
    (
        local result
        request "Name" result false < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "request empty input allowed: exit code"
        assertEqual "${result}" "" "request empty input allowed: result"
    ) || exit 1
}

testRequestEscapeCancel() {
    (
        local result
        request "Name" result false < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "130" "request escape cancel: exit code"
    ) || exit 1
}

testRequestHiddenInput() {
    (
        local result
        request "Password" result false 30 true < <(printf 'secret\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "request hidden input: exit code"
        assertEqual "${result}" "secret" "request hidden input: result"
    ) || exit 1
}

testRequestTimeout() {
    (
        local result
        request "Name" result false 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "124" "request timeout: exit code"
    ) || exit 1
}

# --- secureRequest tests ---

testSecureRequestBasicInput() {
    (
        local result
        secureRequest "Password" result < <(printf 'password\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "secureRequest basic input: exit code"
        assertEqual "${result}" "password" "secureRequest basic input: result"
    ) || exit 1
}

testSecureRequestEscapeCancel() {
    (
        local result
        secureRequest "Password" result < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "130" "secureRequest escape cancel: exit code"
    ) || exit 1
}

# --- confirm tests ---

testConfirmSelectFirstAnswer() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "confirm select first answer: exit code"
        assertEqual "${result}" "0" "confirm select first answer: result"
    ) || exit 1
}

testConfirmSelectSecondViaArrowRight() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e[C\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "confirm select second via arrow right: exit code"
        assertEqual "${result}" "1" "confirm select second via arrow right: result"
    ) || exit 1
}

testConfirmSelectFirstViaArrowLeft() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e[C\e[D\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "confirm select first via arrow left: exit code"
        assertEqual "${result}" "0" "confirm select first via arrow left: result"
    ) || exit 1
}

testConfirmDefaultAnswerTwo() {
    (
        local result
        confirm "Continue?" "yes" "no" result true < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "confirm default answer two: exit code"
        assertEqual "${result}" "1" "confirm default answer two: result"
    ) || exit 1
}

testConfirmEscapeCancel() {
    (
        local result
        confirm "Continue?" "yes" "no" result < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "130" "confirm escape cancel: exit code"
    ) || exit 1
}

testConfirmTimeout() {
    (
        local result
        confirm "Continue?" "yes" "no" result false 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "124" "confirm timeout: exit code"
    ) || exit 1
}

# --- choose tests ---

testChooseSelectFirst() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "choose select first: exit code"
        assertEqual "${result}" "0" "choose select first: result"
    ) || exit 1
}

testChooseNavigateDownAndSelect() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e[B\e[B\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "choose navigate down and select: exit code"
        assertEqual "${result}" "2" "choose navigate down and select: result"
    ) || exit 1
}

testChooseNavigateUpWrapsAround() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e[A\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "choose navigate up wraps around: exit code"
        assertEqual "${result}" "2" "choose navigate up wraps around: result"
    ) || exit 1
}

testChooseStartIndex() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 2 0 3 < <(printf '\n') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "0" "choose start index: exit code"
        assertEqual "${result}" "2" "choose start index: result"
    ) || exit 1
}

testChooseEscapeCancel() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 < <(printf '\e') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "130" "choose escape cancel: exit code"
    ) || exit 1
}

testChooseTimeout() {
    (
        local choices=("Option A" "Option B" "Option C")
        local result
        choose "Pick" choices result false 0 0 3 1 < <(printf '') > /dev/null
        local exitCode=$?
        assertEqual "${exitCode}" "124" "choose timeout: exit code"
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
    assertEqual "${_rowsPerItem}" 1 "rowsPerItem should be 1 without separator"

    _calculateLayout 10 true 0 50
    assertEqual "${_rowsPerItem}" 2 "rowsPerItem should be 2 with separator"
}

testExtraLines() {
    _calculateLayout 10 false 0 50
    assertEqual "${_extraLines}" 2 "extraLines should be 2 without separator"

    _calculateLayout 10 true 0 50
    assertEqual "${_extraLines}" 1 "extraLines should be 1 with separator"
}

testTotalVisibleItemsWithExplicitMax() {
    # maxVisibleItems=5, itemCount=10: should show 5
    _calculateLayout 10 false 5 50
    assertEqual "${_totalVisibleItems}" 5 "should respect maxVisibleItems"

    # maxVisibleItems=5, itemCount=3: should clamp to 3
    _calculateLayout 3 false 5 50
    assertEqual "${_totalVisibleItems}" 3 "should clamp to itemCount when fewer items than max"
}

testTotalVisibleItemsClampsToItemCount() {
    # Large terminal, few items: should clamp to itemCount
    _calculateLayout 3 false 0 100
    assertEqual "${_totalVisibleItems}" 3 "should clamp to itemCount with large terminal"

    # With separator
    _calculateLayout 4 true 0 100
    assertEqual "${_totalVisibleItems}" 4 "should clamp to itemCount with separator and large terminal"
}

testTotalVisibleItemsFromTerminalHeight() {
    # availableRows=30, -6 = 24 visible rows, rowsPerItem=1: 24 items fit
    _calculateLayout 50 false 0 30
    assertEqual "${_totalVisibleItems}" 24 "should calculate from terminal height without separator"

    # availableRows=30, -6 = 24 visible rows, rowsPerItem=2: 12 items fit
    _calculateLayout 50 true 0 30
    assertEqual "${_totalVisibleItems}" 12 "should calculate from terminal height with separator"

    # Small terminal: availableRows=10, -6 = 4 visible rows, rowsPerItem=1: 4 items
    _calculateLayout 50 false 0 10
    assertEqual "${_totalVisibleItems}" 4 "should handle small terminal"
}

testReserveRowsNoSeparator() {
    # 5 items visible, rowsPerItem=1, extraLines=2: (5*1)+2 = 7
    _calculateLayout 5 false 0 50
    assertEqual "${_reserveRows}" 7 "reserveRows for 5 items, no separator"

    # 10 items visible (explicit max), rowsPerItem=1, extraLines=2: (10*1)+2 = 12
    _calculateLayout 20 false 10 50
    assertEqual "${_reserveRows}" 12 "reserveRows for 10 visible items, no separator"
}

testReserveRowsWithSeparator() {
    # 5 items visible, rowsPerItem=2, extraLines=1: (5*2)+1 = 11
    _calculateLayout 5 true 0 50
    assertEqual "${_reserveRows}" 11 "reserveRows for 5 items, with separator"

    # 10 items visible (explicit max), rowsPerItem=2, extraLines=1: (10*2)+1 = 21
    _calculateLayout 20 true 10 50
    assertEqual "${_reserveRows}" 21 "reserveRows for 10 visible items, with separator"
}

testNonVisibleItemCount() {
    # All items visible
    _calculateLayout 5 false 0 50
    assertEqual "${_nonVisibleItems}" 0 "no non-visible items when all fit"

    # 50 items, 24 visible rows: 50-24 = 26 non-visible
    _calculateLayout 50 false 0 30
    assertEqual "${_nonVisibleItems}" 26 "should report correct non-visible count"

    # Explicit max: 20 items, show 5: 15 non-visible
    _calculateLayout 20 false 5 50
    assertEqual "${_nonVisibleItems}" 15 "should report non-visible with explicit max"
}

# Boot

[[ -t 1 && -t 2 ]] || declare -gx forceRayvn24BitColor=1
doNotSetFunctionsReadOnly=1
source rayvn.up 'rayvn/prompt' 'rayvn/test'
main "$@"
