#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library of user input functions.
# Intended for use via: require 'rayvn/prompt'

require 'rayvn/core' 'rayvn/terminal'

request() {
    _setPrompt "${1}"
    local -n _requestResultVar="${2}"
    _timeout="${3:-30}"
    if _readInput; then
        _requestResultVar="${_input}"
        return 0
    else
        return 1
    fi
}

cursorHide() {
    echo -n ${_cursorHide}
}

cursorShow() {
    echo -n ${_cursorShow}
}

cursorSave() {
    echo -n ${_cursorSave}
}

# TODO: This will fail if scrolling occurs.
# Consider saving position to _savedCursorRows / _savedCursorColumns + _savedCursorCount
# and adding cursorPush() cursorPop() functions.
cursorRestore() {
    echo -n ${_cursorRestore}
}

cursorUp() {
    echo -n ${_cursorUp}
}

cursorTo() {
    printf '\e[%i;%iH' ${1} ${2}
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_prompt() {
    if (( terminalSupportsAnsi )); then
        declare -gr _questionPrefix="${ansi_bold_green}?${ansi_normal} "
        declare -gr _promptPrefix="${ansi_bold_blue}>${ansi_normal} "
        declare -gr _cursorHide=$'\e[?25l'
        declare -gr _cursorShow=$'\e[?25h'
        declare -gr _cursorUp=$'\e[A'
        declare -gr _cursorPosition=$'\e[6n'
        declare -gr _cursorSave=$'\e[s'
        declare -gr _cursorRestore=$'\e[u'  # NOTE! assumes no scrolling! See TODO on cursorRestore

        # Shared global state (safe since bash is single threaded!).
        # Only valid during execution of public functions.

        declare -g _prompt
        declare -g _requiredLines
        declare -g _input
        declare -g _timeout
        declare -gi _inputRow
        declare -gi _inputColumn
        declare -gi _inputPositionValid=0
        declare -g _origStty
    else
        fail "'rayvn/prompts' library requires a terminal"
    fi
}

_setPrompt() {
    local prompt="${1}"
    _requiredLines="${2:-2}"
    _prompt="${_questionPrefix}${ansi_bold}${prompt}${ansi_normal} "
    echo -n "${_prompt}"
    _ensureLinesAvailable
}

_ensureLinesAvailable() {
    _getCursorPosition
    declare -i terminalHeight=$(tput lines)
    declare -i remainingLines=$(( terminalHeight - _inputRow ))
    if (( remainingLines < _requiredLines )); then
        declare -i addLines=$(( _requiredLines - remainingLines ))
        printf '\n%.0s' $( seq 1 ${addLines} )
        # move to saved position, adjusting for added lines
        printf '\e[%i;%iH' $(( _inputRow - addLines )) "${_inputColumn}"
    fi
}

_getCursorPosition() {
    _origStty=$(stty -g)
    stty raw -echo
    echo -n ${_cursorPosition} > /dev/tty

    # Read the response character by character until we get 'R'
    local response='' char
    while IFS= read -r -n1 char < /dev/tty; do
        response+="${char}"
        [[ "${char}" == 'R' ]] && break
    done

    stty "${_origStty}"

    # Parse ESC[row;colR
    if [[ $response =~ \[([0-9]+)\;([0-9]+)R ]]; then
        _inputRow=${BASH_REMATCH[1]}
        _inputColumn=${BASH_REMATCH[2]}
        _inputPositionValid=1
    else
        _inputPositionValid=0 # Could not read for some reason!
    fi
}

_readInput() {
    local cancelledMsg=
    echo -n "${_cursorSave}"

    if ! read -t ${_timeout} -r _input; then
        cancelledMsg='cancelled (timeout)'
        _updateInput cancelledMsg "${ansi_italic_red}"
        return 1
    elif [[ -z "${_input// /}" ]]; then
        cancelledMsg='cancelled (no input)'
        _updateInput cancelledMsg "${ansi_italic_red}"
        return 1 # empty
    fi

    _updateInput _input "${ansi_cyan}"
}

_updateInput() {
    local -n inputVarRef="${1}"
    local color="${2}"
    echo -n "${_cursorRestore}"
    echo "${color}${inputVarRef}${ansi_normal}"
    return 0
}
