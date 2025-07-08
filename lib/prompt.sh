#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library of user input functions.
# Intended for use via: require 'rayvn/prompt'

require 'rayvn/core' 'rayvn/terminal'

request() {
    local prompt="${1}"
    local -n resultRef="${2}"
    local cancelOnEmpty="${3:-true}"
    _timeoutSeconds="${4:-30}"
    _setPrompt "${1}" 4
    if _readInput ${cancelOnEmpty}; then
        resultRef="${_userInput}"
        return 0
    else
        return 1
    fi
}

choose() {
    echo # TODO!
}

confirm() {
    local prompt="${1}"
    local answerOne="${2}"
    local answerTwo="${3}"
    local -n resultRef="${4}"
    _timeoutSeconds="${5:-30}"
    local hint=" ${ansi_dim}["${answerOne}/${answerTwo}"]${ansi_normal}"
    _setPrompt "${prompt}" 3 "${hint}"
    while (( SECONDS < _timeoutSeconds )); do
        if _readInput false; then
            local result="${_userInput,,}"
            if [[ ${result} == "${answerOne,,}" || ${result} == "${answerTwo,,}" ]]; then
                resultRef="${result}"
                return 0
            else

                # Update hint and retry

                hint="${ansi_bold_green}[${answerOne}/${answerTwo}]${ansi_normal}"
                cursorTo ${_cursorRow} ${_promptEnd}
                echo -n "${hint} "
                continue # retry
            fi
        else
            return 1
        fi
    done
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
declare -gi _promptEnd
declare -g _userInput
declare -g _timeoutSeconds

_setPrompt() {
    local prompt="${1}"
    local requiredLines="${2}"
    local hint="${3}"
    _prompt="${_questionPrefix}${ansi_bold}${prompt}${ansi_normal}${hint} "
    _promptEnd="${#prompt} + 4"
    echo -n "${_prompt}"
    reserveRows "${requiredLines}"
    SECONDS=0 # Reset bash seconds counter
}

_readInput() {
    local cancelOnEmpty=${1}

    _finalizeInput() {
        local -n inputVarRef="${1}"
        local colorName="ansi_${2}"
        cursorTo ${_cursorRow} ${_promptEnd}
        eraseToEndOfLine
        echo "${!colorName}${inputVarRef}${ansi_normal}"
        stty "${_originalStty}"
    }

    local key escSequence
    declare -i checkCount=0
    stty cbreak -echo
    _userInput=''
    SECONDS=0

    while true; do
        if (( ++checkCount >= 10 )); then
            if (( SECONDS >= _timeoutSeconds )); then
                _finalizeInput _cancelledMsgTimeout italic_red
                return 1
            fi
            checkCount=0
        fi

        if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
            case "${key}" in
                '' | $'\n' | $'\r')  # Enter
                    if [[ -z "${_userInput// /}" ]]; then
                       if [[ ${cancelOnEmpty} == true ]]; then
                            _finalizeInput _cancelledMsgEmpty red
                            return 1
                        fi
                        # ignore
                    else
                        _finalizeInput _userInput cyan
                        return 0
                    fi
                    ;;
                $'\177'| $'\b')  # Backspace
                    if [[ -n "${_userInput}" ]]; then
                        _userInput="${_userInput%?}"
                        printf '\b \b'
                    fi
                    ;;
                 $'\e')  # Escape
                    # If there's follow-up input, it's an escape sequence (e.g. up arrow) so just ignore it
                    if read -n1 -t 0.1 escSequence; then
                        # Consume the rest of the escape sequence
                        case "${escSequence}" in
                            '[')
                                # CSI sequence - read up to 3 more characters max
                                for ((i=0; i<3; i++)); do
                                    if ! read -n1 -t 0.1 key; then
                                        break  # Timeout
                                    fi
                                    # Break on typical final characters
                                    [[ "${key}" =~ [A-Za-z~] ]] && break
                                done
                                ;;
                            *)
                                # Other escape sequences might have different patterns
                                # For now just consume one more character
                                read -n1 -t 0.1 >/dev/null
                                ;;
                        esac
                    else
                        # No follow-up sp ESC key
                        _finalizeInput cancelledMsgEsc red
                        return 1
                    fi
                    ;;
                *)
                    if [[ "${key}" =~ [[:print:]] ]]; then
                        _userInput+="${key}"
                        printf '%s' "${key}"
                    fi
                    ;;
            esac
        fi
    done
}
