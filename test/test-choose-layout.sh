#!/usr/bin/env bash

# Tests for the choose() layout calculation logic.
#
# The interactive terminal parts of choose() (cursor, keyboard, stty) cannot easily
# be tested in an automated way since those functions are readonly and write directly
# to /dev/tty. These tests verify the reserveRows/totalVisibleItems calculation logic.

main() {
    init "${@}"

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

# --- Replicate the choose() calculation to test it ---

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

# --- Tests ---

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

source rayvn.up 'rayvn/test'
main "$@"
