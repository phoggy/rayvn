#!/usr/bin/env bash

# shellcheck disable=SC2120,SC2155

# Library supporting terminal operations
# Intended for use via: require 'rayvn/terminal'

# Hide the terminal cursor.
cursorHide() {
    echo -n $'\e[?25l' > /dev/tty
}

# Show the terminal cursor.
cursorShow() {
    echo -n $'\e[?25h' > /dev/tty
}

# Read the current cursor position via the terminal's CPR response and store it via namerefs.
# Args: rowVar colVar
#
#   rowVar - nameref variable to receive the 1-based row number
#   colVar - nameref variable to receive the 1-based column number
cursorPosition() {
    local -n rowVarRef="${1}"
    local -n colVarRef="${2}"
    local response=''
    local c

    stty -icanon -echo min 1 time 0
    echo -n $'\e[6n' > /dev/tty

    # Read the response character by character until we get 'R'

    while IFS= read -r -n1 c < /dev/tty; do
        response+="${c}"
        [[ "${c}" == 'R' ]] && break
    done

    stty "${_originalStty}"

    # Parse ESC[row;colR

    if [[ ${response} =~ ${_cursorParsePattern} ]]; then
        rowVarRef=${BASH_REMATCH[1]}
        colVarRef=${BASH_REMATCH[2]}
    else
        fail 'could not read cursor position'
    fi
}

# Save the current cursor position. Note: save/restore does not work correctly if scrolling
# occurs between the save and restore; use reserveRows() first to prevent scrolling.
cursorSave() {
    echo -n $'\e[s' > /dev/tty
}

# Restore the cursor to the position saved by cursorSave().
cursorRestore() {
    echo -n $'\e[u' > /dev/tty
}

# Move the cursor up by a number of rows.
# Args: [rows]
#
#   rows - number of rows to move up (default: 1)
cursorUp() {
    printf '\e[%dA' "${1:-1}" > /dev/tty
}

# Move the cursor up by a number of rows and place it at the start of the line.
# Args: [rows]
#
#   rows - number of rows to move up (default: 1)
cursorUpToLineStart() {
    printf '\e[%dA\r' "${1:-1}" > /dev/tty
}

# Move the cursor up by a number of rows and place it at a specific column.
# Args: rows col
#
#   rows - number of rows to move up
#   col  - 1-based column to move to
cursorUpToColumn() {
    printf '\e[%dA\e[%dG' "${1}" "${2}" > /dev/tty
}

# Move the cursor down by a number of rows.
# Args: [rows]
#
#   rows - number of rows to move down (default: 1)
cursorDown() {
    printf '\e[%dB' "${1:-1}" > /dev/tty
}

# Move the cursor down by a number of rows and place it at the start of the line.
# Args: [rows]
#
#   rows - number of rows to move down (default: 1)
cursorDownToLineStart() {
    printf '\e[%dB\r' "${1:-1}" > /dev/tty
}

# Move the cursor down by a number of rows and place it at a specific column.
# Args: rows col
#
#   rows - number of rows to move down
#   col  - 1-based column to move to
cursorDownToColumn() {
    printf '\e[%dB\e[%dG' "${1}" "${2}" > /dev/tty
}

# Move the cursor to an absolute terminal position (row, col).
# Args: row [col]
#
#   row - 1-based row to move to
#   col - 1-based column to move to (default: 0)
cursorTo() {
    printf '\e[%i;%iH' ${1} ${2:-0} > /dev/tty
}

# Move the cursor to an absolute column on the current row.
# Args: col
#
#   col - 1-based column to move to
cursorToColumn() {
    printf '\e[%dG' "${1}" > /dev/tty
}

# Move the cursor to column 1 (start) of the current row.
cursorToLineStart() {
    printf '\r' > /dev/tty
}

# Move the cursor to a column and erase from that position to the end of the line.
# Args: col
#
#   col - 1-based column to move to before erasing
cursorToColumnAndEraseToEndOfLine() {
    printf '\e[%dG\e[K' "${1}" > /dev/tty
}

# Move the cursor up one row and erase the entire line.
cursorUpOneAndEraseLine() {
    echo -n $'\e[A\e[2K\r' > /dev/tty
}

# Move the cursor down one row and erase the entire line.
cursorDownOneAndEraseLine() {
    echo -n $'\e[B\e[2K\r' > /dev/tty
}

# Erase from the cursor position to the end of the current line.
eraseToEndOfLine() {
    echo -n $'\e[0K' > /dev/tty
}

# Erase the entire current line and move the cursor to column 1.
eraseCurrentLine() {
    echo -n $'\e[2K\r' > /dev/tty
}

# Clear the entire terminal and move the cursor to the top-left.
clearTerminal() {
    echo -n $'\e[2J\e[H' > /dev/tty
}

# Scroll the terminal if necessary to ensure a minimum number of rows are available below the cursor.
# Adjusts the current cursor row to account for any scrolling that occurred.
# Args: [requiredRows]
#
#   requiredRows - number of rows needed below the current cursor position (default: 2)
reserveRows() {
    local requiredRows="${1:-2}"
    local terminalHeight=${ tput lines; }
    local remainingRows

    cursorPosition _cursorRow _cursorCol
    remainingRows=$(( terminalHeight - _cursorRow ))

    if (( requiredRows > remainingRows )); then

        # Need to scroll. Determine how many lines and adjust the
        # row we need to go back to

        local scrollRows=$(( requiredRows - remainingRows ))
        (( _cursorRow -= scrollRows ))

        # Move to the last line and force scrolling

        cursorTo ${terminalHeight} 0
        printf '\n%.0s' ${ seq 1 ${scrollRows}; } > /dev/tty

        # Restore cursor to adjusted row and original column

        cursorTo ${_cursorRow} ${_cursorCol}
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/terminal' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_terminal() {
    require 'rayvn/core'
    (( isInteractive )) || return 0  # Silently succeed when not interactive

    # Save original terminal settings (only when interactive)
    [[ ${_originalStty} ]] || declare -gr _originalStty="${ stty -g; }"

    declare -g _cursorRow=
    declare -g _cursorCol=
    declare -gr _cursorParsePattern=$'\e\\[([0-9]+);([0-9]+)R'
}



