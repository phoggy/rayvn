#!/usr/bin/env bash

# shellcheck disable=SC2120,SC2155

# Terminal operations.
# Use via: require 'rayvn/terminal'

# ◇ Hide the terminal cursor.

cursorHide() {
    echo -n $'\e[?25l' > /dev/tty
}

# ◇ Show the terminal cursor.

cursorShow() {
    echo -n $'\e[?25h' > /dev/tty
}

# ◇ Read the current cursor position.
#
# · ARGS
#
#   rowVarRef (stringRef)  Receives the 1-based row number.
#   colVarRef (stringRef)  Receives the 1-based column number.
#
# · EXAMPLE
#
#   cursorPosition row col
#   echo "Cursor is at row $row, col $col"

cursorPosition() {
    local -n rowVarRef="$1"
    local -n colVarRef="$2"
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

# ◇ Save the current cursor position. Note: save/restore does not work correctly if scrolling
#   occurs between the save and restore; use reserveRows() first to prevent scrolling.

cursorSave() {
    echo -n $'\e[s' > /dev/tty
}

# ◇ Restore the cursor to the position saved by cursorSave().

cursorRestore() {
    echo -n $'\e[u' > /dev/tty
}

# ◇ Move the cursor up N rows (default: 1).

cursorUp() {
    printf '\e[%dA' "${1:-1}" > /dev/tty
}

# ◇ Move cursor up N rows and back to line start (default: 1).

cursorUpToLineStart() {
    printf '\e[%dA\r' "${1:-1}" > /dev/tty
}

# ◇ Move the cursor up N rows and place it at a 1-based column.
#
# · ARGS
#
#   rows (int)  Number of rows to move up.
#   col (int)   1-based column to move to.

cursorUpToColumn() {
    printf '\e[%dA\e[%dG' "$1" "$2" > /dev/tty
}

# ◇ Move the cursor down by the given number of rows (default: 1).

cursorDown() {
    printf '\e[%dB' "${1:-1}" > /dev/tty
}

# ◇ Move the cursor down N rows and to the start of the line (default: 1).

cursorDownToLineStart() {
    printf '\e[%dB\r' "${1:-1}" > /dev/tty
}

# ◇ Move the cursor down N rows then to a 1-based column position.
#
# · ARGS
#
#   rows (int)  Number of rows to move down.
#   col (int)   1-based column to place the cursor at.

cursorDownToColumn() {
    printf '\e[%dB\e[%dG' "$1" "$2" > /dev/tty
}

# ◇ Move the cursor to an absolute terminal position, writing to /dev/tty.
#
# · ARGS
#
#   row (int)  1-based row to move to.
#   col (int)  1-based column to move to (default: 0).

cursorTo() {
    printf '\e[%i;%iH' $1 ${2:-0} > /dev/tty
}

# ◇ Move the cursor to an absolute 1-based column on the current row.

cursorToColumn() {
    printf '\e[%dG' "$1" > /dev/tty
}

# ◇ Move the cursor to column 1 of the current row.

cursorToLineStart() {
    printf '\r' > /dev/tty
}

# ◇ Move cursor to column N (1-based) and erase to end of line.

cursorToColumnAndEraseToEndOfLine() {
    printf '\e[%dG\e[K' "$1" > /dev/tty
}

# ◇ Move the cursor up one row and erase the entire line.

cursorUpOneAndEraseLine() {
    echo -n $'\e[A\e[2K\r' > /dev/tty
}

# ◇ Move the cursor down one row and erase the entire line.

cursorDownOneAndEraseLine() {
    echo -n $'\e[B\e[2K\r' > /dev/tty
}

# ◇ Erase from the cursor position to the end of the current line.

eraseToEndOfLine() {
    echo -n $'\e[0K' > /dev/tty
}

# ◇ Erase the entire current line and move the cursor to column 1.

eraseCurrentLine() {
    echo -n $'\e[2K\r' > /dev/tty
}

# ◇ Clear the entire terminal and move the cursor to the top-left.

clearTerminal() {
    echo -n $'\e[2J\e[H' > /dev/tty
}

# ◇ Scroll the terminal to ensure requiredRows are available below the cursor,
#   adjusting the cursor position to account for any scrolling that occurred.
#
# · ARGS
#
#   requiredRows (int)  Rows needed below the cursor (default: 2).

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

    # Save original terminal settings from the terminal device
    [[ ${_originalStty} ]] || declare -gr _originalStty="${ stty -g < "${terminal}"; }"

    declare -g _cursorRow=
    declare -g _cursorCol=
    declare -gr _cursorParsePattern=$'\e\\[([0-9]+);([0-9]+)R'
}



