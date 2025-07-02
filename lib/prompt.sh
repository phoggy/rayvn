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

hideCursor() {
    echo -n ${_cursorHide}
}

showCursor() {
    echo -n ${_cursorShow}
}

cursorUp() {
    echo -n ${_cursorUp}
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_prompt() {
    if ((terminalSupportsAnsi)); then
        declare -gr _questionPrefix="${ansi_bold_green}?${ansi_normal} "
        declare -gr _promptPrefix="${ansi_bold_blue}>${ansi_normal} "
        declare -gr _cursorHide="$(printf '\e[?25l')"
        declare -gr _cursorShow="$(printf '\e[?25h')"
        declare -gr _cursorUp="$(printf '\e[A')"
        declare -gr _cursorPosition="$(printf '\e[6n')"

        # Shared global state (safe since bash is single threaded!).
        # Only valid during execution of public function.

        declare -g _prompt
        declare -g _promptLength
        declare -g _input
        declare -g _timeout
        declare -gi _inputStartRow
        declare -gi _inputStartColumn
        declare -gi _inputStartValid=0
        declare -g _origStty
    else
        fail "'rayvn/prompts' library requires a terminal"
    fi
}

_setPrompt() {
    _prompt="${_questionPrefix}${ansi_bold}${1}${ansi_normal} "
    _promptLength="${#1}"
    (( _promptLength+= 3 ))

    _getCursorPosition
    (( _inputStartColumn+=${_promptLength} ))
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
        _inputStartRow=${BASH_REMATCH[1]}
        _inputStartColumn=${BASH_REMATCH[2]}
        _inputStartValid=1
    else
        _inputStartValid=0 # Could not read for some reason!
    fi
}

_readInput() {
    local cancelledMsg=
    if ! read -t ${_timeout} -r -p "${_prompt}" _input; then
        cancelledMsg='cancelled (timeout)'
        _updateInput cancelledMsg "${ansi_italic_red}"
        return 1
    elif [[ -z "${_input// /}" ]]; then
        cancelledMsg='cancelled (no input)'
        _updateInput cancelledMsg "${ansi_italic_red}"
        return 1 # empty
    fi

    _updateInput _input "${ansi_cyan}"
    return 0
}

_updateInput() {
    if (( _inputStartValid )); then
        local -n inputVarRef="${1}"
        local color="${2}"
        hideCursor
        printf '\e[%s;%sH' "${_inputStartRow}" "${_inputStartColumn}"
        echo "${color}${inputVarRef}${ansi_normal}"
        showCursor
    fi
}
