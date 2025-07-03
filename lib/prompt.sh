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
        declare -gr _origStty=$(stty -g)
        declare -gr _cancelledMsgINT='cancelled (ctrl-c)'
        declare -gr _cancelledMsgEmpty='cancelled (no input)'
        declare -gr _cancelledMsgEsc='cancelled (escape)'
        declare -gr _cancelledMsgTimeout='cancelled (timeout)'

        # Shared global state (safe since bash is single threaded!).
        # Only valid during execution of public functions.

        declare -g _prompt
        declare -g _requiredLines
        declare -g _input
        declare -g _timeout
        declare -gi _inputRow
        declare -gi _inputColumn
        declare -gi _inputPositionValid=0

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

    _updateInput() {
        local color
        local -n inputVarRef="${1}"
        declare -i result=${2}
        if (( monitorPid > 0 )); then
            kill ${monitorPid} 2> /dev/null
            wait ${monitorPid} 2> /dev/null
        fi

        (( result == 0 )) && color="${ansi_cyan}" || color="${ansi_italic_red}"
        echo -n "${_cursorRestore}"
        echo "${color}${inputVarRef}${ansi_normal}"
        stty "${_origStty}"
        return ${result}
    }

    _startCancelMonitor() {
        (
            trap 'exit 130' INT
            sleep "${_timeout}"
            exit 124
        ) &
        monitorPid=$!
    }

    _isCanceled() {
        if ! kill -0 ${monitorPid} 2> /dev/null; then
            wait ${monitorPid}
            exitCode=$?
            case ${exitCode} in
                130) _updateInput _cancelledMsgINT 1 ;;
                124) _updateInput _cancelledMsgTimeout 1 ;;
                *) local msg="cancelled (error ${exitCode})"; _updateInput msg 1 ;;
            esac
            return 0
        fi
        return 1
    }

    local key monitorPid=0 exitCode
    declare -i checkCount=0
    echo -n "${_cursorSave}"
    stty cbreak -echo
     _input=''

    _startCancelMonitor

    while true; do
        if (( ++checkCount >= 4 )); then
            checkCount=0
            if _isCanceled; then
                return 1
            fi
        fi

        if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
            case "${key}" in
                '' | $'\n' | $'\r')  # Enter
                    if [[ -z "${_input// /}" ]]; then
                        _updateInput _cancelledMsgEmpty 1
                        return 1
                    else
                        _updateInput _input 0
                        return 0
                    fi
                    ;;
                $'\177'| $'\b')  # Backspace
                    if [[ -n "${_input}" ]]; then
                        _input="${_input%?}"
                        printf '\b \b'
                    fi
                    ;;
                 $'\e')  # Escape
                    _updateInput _cancelledMsgEsc 1
                    return 1
                    ;;
                *)
                    if [[ "${key}" =~ [[:print:]] ]]; then
                        _input+="${key}"
                        printf '%s' "${key}"
                    fi
                    ;;
            esac
        fi
    done
}
