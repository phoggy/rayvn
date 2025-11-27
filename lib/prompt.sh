#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library of user input functions.
# Intended for use via: require 'rayvn/prompt'

# Read user input.
#
# Usage: request <prompt> <resultVarName> [true/false cancel-on-empty] [timeout seconds]
# Output: resultVar set to input.
# Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user cancelled (ESC pressed)

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
        return $?
    fi
}

# Choose from a list of options, using the arrow keys.
#
# Usage: choose <prompt> <choiceIndexVarName>  <timeout seconds> choice0 choice1 ... choiceN
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user cancelled (ESC pressed)

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

    _prepare() {
        _prepareHint ' ' 'use arrows to move'
        _preparePrompt "${prompt}" ${timeout} ${reserve}
        cursorHide
        echo
        (( _cursorRow++ )) # adjust for echo
    }

    _paint() {
        cursorTo ${_cursorRow} 0
        for (( i=0; i <= max; i++ )); do
            if (( i == current)); then
                show bold ">" primary "${choices[${i}]}"
            else
                show primary "  ${choices[${i}]}"
            fi
        done
    }

    _up() {
        if (( current == 0 )); then
            current=${max}
        else
            (( current-- ))
        fi
        _paint
    }

    _down() {
        if (( current == ${max} )); then
            current=0
        else
            (( current++ ))
        fi
        _paint
    }

    _pick() {
        _paint
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
                                'u') _up ;;   # up arrow
                                'd') _down ;; # down arrow
                                 *) ;;        # ignore others
                            esac
                        else
                            _finalize 1 # ESC
                            return ${_canceledOnEsc}
                        fi
                        ;;

                    *) # ignore anything else
                        ;;
                esac
            fi

            if _hasPromptTimerExpired; then
                _finalize 1
                return ${_canceledOnTimeout}
            fi
        done
    }

    _finalize() {
        local failed="${1}"

        # Clear choices

        cursorTo ${_promptRow} ${_promptCol}
        for (( i=0; i <= max; i++ )); do
            cursorDownOneAndEraseLine
        done
        cursorTo $(( _promptRow+1 )) 0

        # Finalize the prompt if success (already done if failed).

        (( ! failed )) && _finalizePrompt selected primary
    }

    # Run it

    _prepare
    _pick || return $?
    _finalize 0
    return 0
}

# Request that the user confirm one of two choices. By default, the user must type one of the two
# answers. If one of the answers should be considered a default when only the <enter> key is pressed,
# that answer should have '=default' appended to it (e.g. yes=default).
#
# Usage: choose <prompt> <answerOne> <answerTwo> <choiceVarName> [timeout seconds]
# Output: choiceVar set to chosen answer.
# Exit codes: 0 = success, 124 = timeout, 130 = user cancelled (ESC pressed)

confirm() {
    local prompt="${1}"
    local answerOne="${2}"
    local answerTwo="${3}"
    local -n resultRef="${4}"
    local timeout="${6:-30}"
    local defaultAnswer=
    local returnOnEmpty=''

    if [[ ${answerOne} == *'=default' ]]; then
        answerOne="${answerOne%=default}"
        defaultAnswer=${answerOne}
        _overwriteHint=0
        returnOnEmpty=true
        _hint=" ${ show -n dim italic "[" ;}${ show -n italic cyan "${answerOne}" ;}${ show -n dim italic "/${answerTwo}]" ;}"
    elif [[ ${answerTwo} == *'=default' ]]; then
        answerTwo="${answerTwo%=default}"
        defaultAnswer=${answerTwo}
        _overwriteHint=0
        returnOnEmpty=true
        _hint=" ${ show -n dim italic "[${answerOne}/" ;}${ show -n italic cyan "${answerTwo}" ;}${ show -n dim italic "]" ;}"
    else
        _prepareHint ' ' "${answerOne}/${answerTwo}"
    fi

    _preparePrompt "${prompt}" ${timeout} 3

    while true; do
        if _readPromptInput false ${returnOnEmpty}; then

            local result="${_userInput,,}"
            if [[ ${result} == "${answerOne,,}" || ${result} == "${answerTwo,,}" ]]; then
                resultRef="${result}"
                return 0
            elif [[ -n ${defaultAnswer} && ${result} == '' ]]; then
                _finalizePrompt defaultAnswer primary
                resultRef="${defaultAnswer}"
                return 0
            else

                # Update hint and retry

                hint="${ show -n bold green "[${answerOne}/${answerTwo}]" ;}"
                cursorTo ${_cursorRow} ${_promptCol}
                echo -n "${hint} "
              #  continue
            fi
        else
            return $?
        fi
    done
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/prompt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_prompt() {
    require 'rayvn/core' 'rayvn/terminal'

    declare -gr _cancelledMsgINT='cancelled (ctrl-c)'
    declare -gr _cancelledMsgEmpty='cancelled (no input)'
    declare -gr _cancelledMsgEsc='cancelled (escape)'
    declare -gr _cancelledMsgTimeout='cancelled (timeout)'
    declare -gr _canceledOnEmpty=1
    declare -gr _canceledOnTimeout=124
    declare -gr _canceledOnEsc=130

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
}

_prepareHint() {
    local initialSpace="${1}"
    local hint="${2}"
    _overwriteHint="${3:0}"
    _hint="${initialSpace}${ show -n muted italic "[${hint}]" ;}"
}

_preparePrompt() {
    _plainPrompt="${1}"
    local timeout="${2}"
    local requiredLines="${3}"
    _prompt="${ show -n bold success "?" plain bold "${_plainPrompt}" ;}${_hint} "
    echo -n "${_prompt}"
    reserveRows "${requiredLines}"
    _promptRow=${_cursorRow}
    _promptCol="${#_plainPrompt} + 4" # exclude hint, include prefix & trailing space
    (( _overwriteHint)) && printf '\e[%dG' ${_promptCol} # move cursor before hint
    _timeoutSeconds=${timeout}
    _timeoutCheckCount=0
    _userInput=
    SECONDS=0 # Reset bash seconds counter
}

_hasPromptTimerExpired() {
    if (( ++_timeoutCheckCount >= 10 )); then
        if (( SECONDS >= _timeoutSeconds )); then
            _finalizePrompt _cancelledMsgTimeout italic warning
            debug "${_timeoutSeconds} second timeout for prompt '${_plainPrompt}'"
            return 0
        fi
        _timeoutCheckCount=0
    fi
    return ${_canceledOnTimeout}
}

_readPromptInput() {
    local cancelOnEmpty=${1}
    local returnOnEmpty="${2:-''}"
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
                        _finalizePrompt _cancelledMsgEmpty italic warning
                        return ${_canceledOnEmpty}
                    elif [[ ${returnOnEmpty} == true ]]; then
                        return 0
                    fi
                    # ignore
                else
                    _finalizePrompt _userInput primary
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
                _readPromptEscapeSequence esc || return ${_canceledOnEsc}
                ;;
            *)
                if [[ "${key}" =~ [[:print:]] ]]; then
                    _userInput+="${key}"
                    printf '%s' "${key}"
                fi
                ;;
            esac
        fi

        _hasPromptTimerExpired && return ${_canceledOnTimeout}

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
        _finalizePrompt _cancelledMsgEsc italic warning
        return 1
    fi
}

_finalizePrompt() {
    local -n inputVarRef="${1}"
    local formats=("${@:2}")
    cursorTo ${_promptRow} ${_promptCol}
    eraseToEndOfLine
    show "${formats[@]}" "${inputVarRef}"
    stty "${_originalStty}"
}
