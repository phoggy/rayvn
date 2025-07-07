#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library of user input functions.
# Intended for use via: require 'rayvn/prompt'

require 'rayvn/core' 'rayvn/terminal'

request() {
    _setPrompt "${1}" 4
    local -n resultRef="${2:?'missing argument'}"
    _timeout="${3:-30}"
    if _readInput; then
        resultRef="${_input}"
        return 0
    else
        return 1
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

declare -gr _questionPrefix="${ansi_bold_green}?${ansi_normal} "
declare -gr _promptPrefix="${ansi_bold_blue}>${ansi_normal} "
declare -gr _cancelledMsgINT='cancelled (ctrl-c)'
declare -gr _cancelledMsgEmpty='cancelled (no input)'
declare -gr _cancelledMsgEsc='cancelled (escape)'
declare -gr _cancelledMsgTimeout='cancelled (timeout)'

# Shared global state (safe since bash is single threaded!).
# Only valid during execution of public functions.

declare -g _prompt
declare -g _input
declare -g _timeout

_setPrompt() {
    local prompt="${1}"
    local requiredLines="${2:-3}"
    _prompt="${_questionPrefix}${ansi_bold}${prompt}${ansi_normal} "
    echo -n "${_prompt}"
    reserveRows "${requiredLines}"
}

_readInput() {

    _updateInput() {
        local color
        local -n inputVarRef="${1}"
        declare -i result=${2}
#        if (( monitorPid > 0 )); then
#            kill ${monitorPid} 2> /dev/null
#            wait ${monitorPid} 2> /dev/null
#        fi

        (( result == 0 )) && color="${ansi_cyan}" || color="${ansi_italic_red}"
        cursorTo ${_cursorRow} ${_cursorCol}
      #  echo -n "${_cursorRestore}"
        echo "${color}${inputVarRef}${ansi_normal}"
        stty "${_originalStty}"
        return ${result}
    }

#    _startCancelMonitor() {
#        (
#            trap 'exit 130' INT
#            sleep "${_timeout}"
#            exit 124
#        ) &
#        monitorPid=$!
#    }
#
#    _isCanceled() {
#        if ! kill -0 ${monitorPid} 2> /dev/null; then
#            wait ${monitorPid}
#            exitCode=$?
#            case ${exitCode} in
#                130) _updateInput _cancelledMsgINT 1 ;;
#                124) _updateInput _cancelledMsgTimeout 1 ;;
#                *) local msg="cancelled (error ${exitCode})"; _updateInput msg 1 ;;
#            esac
#            return 0
#        fi
#        return 1
#    }

    local key monitorPid=0 exitCode
    declare -i checkCount=0
#    echo -n "${_cursorSave}"
    stty cbreak -echo
    _input=''
    SECONDS=0

    while true; do
        if (( ++checkCount >= 10 )); then
            if (( SECONDS >= _timeout )); then
                _updateInput _cancelledMsgTimeout 1
                return 1
            fi
            checkCount=0
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
