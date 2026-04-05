#!/usr/bin/env bash

main() {
    init "$@"

    testCursorVisibility
    testCursorSaveRestore
    testCursorUp
    testCursorUpToLineStart
    testCursorUpToColumn
    testCursorDown
    testCursorDownToLineStart
    testCursorDownToColumn
    testCursorTo
    testCursorToColumn
    testCursorToLineStart
    testCursorToColumnAndEraseToEndOfLine
    testCursorUpOneAndEraseLine
    testCursorDownOneAndEraseLine
    testEraseToEndOfLine
    testEraseCurrentLine
    testClearTerminal

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    startTtyCapture
}

testCursorVisibility() {
    clearTtyCapture
    cursorHide
    assertTtyRawContains $'\e[?25l' "cursorHide emits hide sequence"

    clearTtyCapture
    cursorShow
    assertTtyRawContains $'\e[?25h' "cursorShow emits show sequence"
}

testCursorSaveRestore() {
    clearTtyCapture
    cursorSave
    assertTtyRawContains $'\e[s' "cursorSave emits save sequence"

    clearTtyCapture
    cursorRestore
    assertTtyRawContains $'\e[u' "cursorRestore emits restore sequence"
}

testCursorUp() {
    clearTtyCapture
    cursorUp
    assertTtyRawContains $'\e[1A' "cursorUp defaults to 1 row"

    clearTtyCapture
    cursorUp 3
    assertTtyRawContains $'\e[3A' "cursorUp 3 moves 3 rows"
}

testCursorUpToLineStart() {
    clearTtyCapture
    cursorUpToLineStart
    assertTtyRawContains $'\e[1A\r' "cursorUpToLineStart defaults to 1 row"

    clearTtyCapture
    cursorUpToLineStart 2
    assertTtyRawContains $'\e[2A\r' "cursorUpToLineStart 2 moves 2 rows"
}

testCursorUpToColumn() {
    clearTtyCapture
    cursorUpToColumn 2 5
    assertTtyRawContains $'\e[2A\e[5G' "cursorUpToColumn 2 5 moves up and to column"
}

testCursorDown() {
    clearTtyCapture
    cursorDown
    assertTtyRawContains $'\e[1B' "cursorDown defaults to 1 row"

    clearTtyCapture
    cursorDown 4
    assertTtyRawContains $'\e[4B' "cursorDown 4 moves 4 rows"
}

testCursorDownToLineStart() {
    clearTtyCapture
    cursorDownToLineStart
    assertTtyRawContains $'\e[1B\r' "cursorDownToLineStart defaults to 1 row"

    clearTtyCapture
    cursorDownToLineStart 3
    assertTtyRawContains $'\e[3B\r' "cursorDownToLineStart 3 moves 3 rows"
}

testCursorDownToColumn() {
    clearTtyCapture
    cursorDownToColumn 2 8
    assertTtyRawContains $'\e[2B\e[8G' "cursorDownToColumn 2 8 moves down and to column"
}

testCursorTo() {
    clearTtyCapture
    cursorTo 5 10
    assertTtyRawContains $'\e[5;10H' "cursorTo 5 10 emits absolute position sequence"

    clearTtyCapture
    cursorTo 1 1
    assertTtyRawContains $'\e[1;1H' "cursorTo 1 1 emits home position"
}

testCursorToColumn() {
    clearTtyCapture
    cursorToColumn 7
    assertTtyRawContains $'\e[7G' "cursorToColumn 7 emits column sequence"
}

testCursorToLineStart() {
    clearTtyCapture
    cursorToLineStart
    assertTtyRawContains $'\r' "cursorToLineStart emits carriage return"
}

testCursorToColumnAndEraseToEndOfLine() {
    clearTtyCapture
    cursorToColumnAndEraseToEndOfLine 3
    assertTtyRawContains $'\e[3G\e[K' "cursorToColumnAndEraseToEndOfLine emits move+erase sequence"
}

testCursorUpOneAndEraseLine() {
    clearTtyCapture
    cursorUpOneAndEraseLine
    assertTtyRawContains $'\e[A\e[2K\r' "cursorUpOneAndEraseLine emits up+erase+cr sequence"
}

testCursorDownOneAndEraseLine() {
    clearTtyCapture
    cursorDownOneAndEraseLine
    assertTtyRawContains $'\e[B\e[2K\r' "cursorDownOneAndEraseLine emits down+erase+cr sequence"
}

testEraseToEndOfLine() {
    clearTtyCapture
    eraseToEndOfLine
    assertTtyRawContains $'\e[0K' "eraseToEndOfLine emits erase-to-end sequence"
}

testEraseCurrentLine() {
    clearTtyCapture
    eraseCurrentLine
    assertTtyRawContains $'\e[2K\r' "eraseCurrentLine emits full-line erase sequence"
}

testClearTerminal() {
    clearTtyCapture
    clearTerminal
    assertTtyRawContains $'\e[2J\e[H' "clearTerminal emits clear+home sequence"
}

source rayvn.up 'rayvn/core' 'rayvn/terminal' 'rayvn/test'
main "$@"
