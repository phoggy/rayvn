#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library of user input functions.
# Intended for use via: require 'rayvn/prompt'

request() {
    local prompt="${1}"
    local -n resultRef="${2}"
    local cancelOnEmpty="${3:-true}"
    local timeout="${4:-30}"
    _prepareHint '  ' 'type your answer here' 1
    _preparePrompt "${prompt}" ${timeout} 4
    if _readPromptInput ${cancelOnEmpty}; then
        resultRef="${_userInput}"
        return 0
    else
        return 1
    fi
}

choose() {
    local prompt="${1}"
    local -n choiceIndexRef="${2}"
    local timeout="${3}"
    local choices=("${@:4}")
    local max=$(( ${#choices[@]} - 1 ))
    local reserve=$(( max + 3 ))
    local current=0
    local key i
    local selected=

    prepare() {
        _prepareHint ' ' 'use arrows to move'
        _preparePrompt "${prompt}" ${timeout} ${reserve}
        cursorHide
        echo
        (( _cursorRow++ )) # adjust for echo
    }

    paint() {
        cursorTo ${_cursorRow} 0
        for (( i=0; i <= max; i++ )); do
            if (( i == current)); then
                echo "${ansi_bold}> ${ansi_cyan}${choices[${i}]}${ansi_normal}"
            else
                echo "  ${ansi_cyan}${choices[${i}]}${ansi_normal}"
            fi
        done
    }

    up() {
        if (( current == 0 )); then
            current=${max}
        else
            (( current-- ))
        fi
        paint
    }

    down() {
        if (( current == ${max} )); then
            current=0
        else
            (( current++ ))
        fi
        paint
    }

    pick() {
        paint
        stty cbreak -echo
        while true; do
            if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
                case "${key}" in
                    '' | $'\n' | $'\r')

                        # Enter
                        selected="${choices[${current}]}"
                        choiceIndexRef=${current}
                        break ;;

                    $'\e') # Escape, maybe a sequence

                        if _readPromptEscapeSequence key; then
                            case "${key}" in
                                'u') up ;;   # up arrow
                                'd') down ;; # down arrow
                                 *) ;;       # ignore others
                            esac
                        else
                            finalize 1 # ESC
                            return 1
                        fi
                        ;;

                    *) # ignore anything else
                        ;;
                esac
            fi

            if _hasPromptTimerExpired; then
                finalize 1
                return 1
            fi
        done
    }

    finalize() {
        local failed="${1}"

        # Clear choices

        cursorTo ${_promptRow} ${_promptCol}
        for (( i=0; i <= max; i++ )); do
            cursorDownOneAndEraseLine
        done
        cursorTo $(( _promptRow+1 )) 0

        # Finalize the prompt if success (already done if failed).

        (( ! failed )) && _finalizePrompt selected cyan
    }

    # Run it

    prepare
    pick || return 1
    finalize 0
    return 0
}

confirm() {
    local prompt="${1}"
    local answerOne="${2}"
    local answerTwo="${3}"
    local -n resultRef="${4}"
    local timeout="${5:-30}"
    _prepareHint ' ' "${answerOne}/${answerTwo}"
    _preparePrompt "${prompt}" ${timeout} 3

    while true; do
        if _readPromptInput false; then

            local result="${_userInput,,}"
            debug "confirm answer: ${_userInput}"
            if [[ ${result} == "${answerOne,,}" || ${result} == "${answerTwo,,}" ]]; then
                resultRef="${result}"
                return 0
            else

                # Update hint and retry

                hint="${ansi_bold_green}[${answerOne}/${answerTwo}]${ansi_normal}"
                cursorTo ${_cursorRow} ${_promptCol}
                echo -n "${hint} "
              #  continue
            fi
        else
            return 1
        fi
    done
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/prompt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_prompt() {
    require 'rayvn/core' 'rayvn/terminal'
}

declare -gr _questionPrefix="${ansi_bold_green}?${ansi_normal} "
declare -gr _promptPrefix="${ansi_bold_blue}>${ansi_normal} "
declare -gr _cancelledMsgINT='cancelled (ctrl-c)'
declare -gr _cancelledMsgEmpty='cancelled (no input)'
declare -gr _cancelledMsgEsc='cancelled (escape)'
declare -gr _cancelledMsgTimeout='cancelled (timeout)'

# Shared global state (safe since bash is single threaded!).
# Only valid during execution of public functions.

declare -g _hint
declare -g _prompt
declare -g _promptRow
declare -gi _promptCol
declare -g _plainPrompt
declare -g _overwriteHint
declare -g _timeoutSeconds
declare -gi _timeoutCheckCount
declare -g _userInput

_prepareHint() {
    local initialSpace="${1}"
    local hint="${2}"
    _overwriteHint="${3:0}"
    _hint="${initialSpace}${ansi_dim}${ansi_italic}[${hint}]${ansi_normal}"
}

_preparePrompt() {
    _plainPrompt="${1}"
    local timeout="${2}"
    local requiredLines="${3}"
    _prompt="${_questionPrefix}${ansi_bold}${_plainPrompt}${ansi_normal}${_hint} "
    echo -n "${_prompt}"
    reserveRows "${requiredLines}"
    _promptRow=${_cursorRow}
    _promptCol="${#_plainPrompt} + 4" # exclude hint, include prefix & trailing space
    (( _overwriteHint)) && printf '\e[%dG' ${_promptCol} # move cursor before hint
    _timeoutSeconds=${timeout}
    _timeoutCheckCount=0
    _userInput=
    (())
    SECONDS=0 # Reset bash seconds counter
}

_hasPromptTimerExpired() {
    if (( ++_timeoutCheckCount >= 10 )); then
        if (( SECONDS >= _timeoutSeconds )); then
            _finalizePrompt _cancelledMsgTimeout italic_red
            debug "${_timeoutSeconds} second timeout for prompt '${_plainPrompt}'"
            return 0
        fi
        _timeoutCheckCount=0
    fi
    return 1
}

_readPromptInput() {
    local cancelOnEmpty=${1}
    local key esc
    stty cbreak -echo # turn off buffering and input echo
    _userInput=
    cursorShow

    while true; do
        if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
            (( _overwriteHint )) && _clearHint
            case "${key}" in
            '' | $'\n' | $'\r') # Enter
                if [[ -z "${_userInput// /}" ]]; then
                    if [[ ${cancelOnEmpty} == true ]]; then
                        _finalizePrompt _cancelledMsgEmpty red
                        return 1
                    fi
                    # ignore
                else
                    _finalizePrompt _userInput cyan
                    return 0
                fi
                ;;
            $'\177' | $'\b') # Backspace
                if [[ -n "${_userInput}" ]]; then
                    _userInput="${_userInput%?}"
                    printf '\b \b'
                fi
                ;;
            $'\e') # Escape
                _readPromptEscapeSequence esc || return 1
                ;;
            *)
                if [[ "${key}" =~ [[:print:]] ]]; then
                    _userInput+="${key}"
                    printf '%s' "${key}"
                fi
                ;;
            esac
        fi

        _hasPromptTimerExpired && return 1

    done
}

_clearHint() {
    _overwriteHint=0
    printf '\e[%dG\e[K' ${_promptCol}
}

_readPromptEscapeSequence() {
    local -n resultVar="${1}"
    local c

    # Is there more input?

    if read -n1 -t 0.1 c; then

        # Yes, it is an escape sequence

        case "${c}" in

            '[') # CSI sequence, read up to 3 more characters and process last

                for (( i = 0; i < 3; i++ )); do
                    if ! read -n1 -t 0.1 c; then
                        break # timeout, assume we already read the last char
                    fi

                    case "${c}" in
                        'A') resultVar='u'; break ;;  # Up
                        'B') resultVar='d'; break ;;  # Down
                        'C') resultVar='r'; break ;;  # Right
                        'D') resultVar='l'; break ;;  # Left
                          *) resultVar='?'; break ;;  # Unknown/don't care
                    esac
                done
                ;;

            *)  # Non-CSI escape sequence, consume and log it if debug is enabled.
                #
                # NOTE: it is certainly possible that reading these extra characters will
                # break subsequent input, but ctrl-c is always available. Could simply
                # fail here if it becomes an issue.

                local debugBuffer="${c}"
                while read -n1 -t 0.05 c; do
                    debugBuffer+="${c}"
                done
                debugBinary "Unknown keyboard ESC sequence: " "${debugBuffer}"
                resultVar='?'
            ;;
        esac
        return 0
    else

        # No, so ESC
        _finalizePrompt _cancelledMsgEsc red
        return 1
    fi
}

_finalizePrompt() {
    local -n inputVarRef="${1}"
    local colorName="ansi_${2}"
    cursorTo ${_promptRow} ${_promptCol}
    eraseToEndOfLine
    echo "${!colorName}${inputVarRef}${ansi_normal}"
    stty "${_originalStty}"
}
