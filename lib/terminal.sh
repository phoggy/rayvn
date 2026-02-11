#!/usr/bin/env bash

# shellcheck disable=SC2120,SC2155

# Library supporting terminal operations
# Intended for use via: require 'rayvn/terminal'

cursorHide() {
    echo -n $'\e[?25l' > /dev/tty
}

cursorShow() {
    echo -n $'\e[?25h' > /dev/tty
}

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

# Save/restore will not work correctly if scrolling occurs, use reserveRows() to prevent.
cursorSave() {
    echo -n $'\e[s' > /dev/tty
}

cursorRestore() {
    echo -n $'\e[u' > /dev/tty
}

cursorUp() {
    printf '\e[%dA' "${1:-1}" > /dev/tty
}

cursorUpToLineStart() {
    printf '\e[%dA\r' "${1:-1}" > /dev/tty
}

cursorUpToColumn() {
    printf '\e[%dA\e[%dG' "${1}" "${2}" > /dev/tty
}

cursorDown() {
    printf '\e[%dB' "${1:-1}" > /dev/tty
}

cursorDownToLineStart() {
    printf '\e[%dB\r' "${1:-1}" > /dev/tty
}

cursorDownToColumn() {
    printf '\e[%dB\e[%dG' "${1}" "${2}" > /dev/tty
}

cursorTo() {
    printf '\e[%i;%iH' ${1} ${2:-0} > /dev/tty
}

cursorToColumn() {
    printf '\e[%dG' "${1}" > /dev/tty
}

cursorToLineStart() {
    printf '\r' > /dev/tty
}

cursorToColumnAndEraseToEndOfLine() {
    printf '\e[%dG\e[K' "${1}" > /dev/tty
}

cursorUpOneAndEraseLine() {
    echo -n $'\e[A\e[2K\r' > /dev/tty
}

cursorDownOneAndEraseLine() {
    echo -n $'\e[B\e[2K\r' > /dev/tty
}

eraseToEndOfLine() {
    echo -n $'\e[0K' > /dev/tty
}

eraseCurrentLine() {
    echo -n $'\e[2K\r' > /dev/tty
}

clearTerminal() {
    echo -n $'\e[2J\e[H' > /dev/tty
}

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



