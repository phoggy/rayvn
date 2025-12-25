#!/usr/bin/env bash

# shellcheck disable=SC2120,SC2155

# Library supporting terminal operations
# Intended for use via: require 'rayvn/terminal'

cursorHide() {
    echo -n "${_cursorHide}"
}

cursorShow() {
    echo -n "${_cursorShow}"
}

cursorPosition() {
    local -n rowVarRef="${1}"
    local -n colVarRef="${2}"
    local response=''
    local c

    stty -icanon -echo min 1 time 0
    echo -n ${_cursorPosition} > /dev/tty

    # Read the response character by character until we get 'R'

    while IFS= read -r -n1 c </dev/tty; do
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
    echo -n "${_cursorSave}"
}

cursorRestore() {
    echo -n "${_cursorRestore}"
}

cursorUp() {
    echo -n "${_cursorUp}"
}

cursorTo() {
    printf '\e[%i;%iH' ${1} ${2:-0}
}

cursorUpOneAndEraseLine() {
    echo -n "${_cursorUpOneAndEraseLine}"
}

cursorDownOneAndEraseLine() {
    echo -n "${_cursorDownOneAndEraseLine}"
}

eraseToEndOfLine() {
    echo -n "${_eraseToEndOfLine}"
}

eraseCurrentLine() {
    echo -n "${_eraseCurrentLine}"
}

clearTerminal() {
    echo -n "${_clearTerminal}"
}

reserveRows() {
    local requiredRows="${1:-2}"
    local terminalHeight=$(tput lines)
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
        printf '\n%.0s' $(seq 1 ${scrollRows})

        # Restore cursor to adjusted row and original column

        cursorTo ${_cursorRow} ${_cursorCol}
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/terminal' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_terminal() {
    require 'rayvn/core'
    ((isInteractive)) || return 0  # Silently succeed when not interactive

    # Save original terminal settings (only when interactive)
    [[ ${_originalStty} ]] || declare -gr _originalStty="$(stty -g)"
}

declare -grx _eraseToEndOfLine=$'\e[0K'
declare -grx _eraseCurrentLine=$'\e[2K\r' # \r leaves cursor ar line start
declare -grx _cursorUpOneAndEraseLine=$'\e[A\e[2K\r'
declare -grx _cursorDownOneAndEraseLine=$'\e[B\e[2K\r'
declare -grx _clearTerminal=$'\e[2J\e[H'

declare -gr _cursorHide=$'\e[?25l'
declare -gr _cursorShow=$'\e[?25h'
declare -gr _cursorUp=$'\e[A'
declare -gr _cursorDown=$'\e[B'
declare -gr _cursorPosition=$'\e[6n'
declare -gr _cursorSave=$'\e[s'
declare -gr _cursorRestore=$'\e[u'
declare -gr _cursorParsePattern=$'\e\\[([0-9]+);([0-9]+)R'
declare -gi _cursorRow=
declare -gi _cursorCol=


# Untested, probably not needed
#
#declare -gi _cursorRowStack=()
#declare -gi _cursorColStack=()
#declare -gi _cursorStackLength=0
#
#cursorPush() {
#    local row col
#    cursorPosition row col
#    _cursorRowStack[_cursorStackLength]=("${row}")
#    _cursorColStack[_cursorStackLength]=("${col}")
#    (( _cursorStackIndex+=1 ))
#}
#
#cursorPop() {
#    if (( _cursorStackIndex > 0 )); then
#        (( _cursorStackIndex-=1 ))
#        printf '\e[%d;%dH' ${_cursorRowStack[_cursorStackIndex]} ${_cursorColStack[_cursorStackIndex]}
#        if (( _cursorStackIndex == 0 )); then
#            # clear stack
#            _cursorRowStack=()
#            _cursorColStack=()
#        fi
#    fi
#}


