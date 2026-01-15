#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library of user input functions.
# Intended for use via: require 'rayvn/prompt'

# Read user input.
#
# Usage: request <prompt> <resultVarName> [true/false cancel-on-empty] [timeout seconds]
# Output: resultVar set to input.
# Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

request() {
    local prompt="${1}"
    local -n resultRef="${2}"
    local cancelOnEmpty="${3:-true}"
    local timeout="${4:-30}"
    _prepareHint '  ' 'type your answer here' 1
    _preparePrompt "${prompt}" ${timeout} 4
    if _readPromptInput ${cancelOnEmpty}; then
        resultRef="${_promptInput}"
        return 0
    else
        return $?
    fi
}

# Read user input without echoing it to the terminal.
#
# Usage: requestHidden <prompt> <resultVarName> [true/false cancel-on-empty] [timeout seconds]
# Output: resultVar set to input.
# Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

requestHidden() {
    local prompt="${1}"
    local -n resultRef="${2}"
    local cancelOnEmpty="${3:-true}"
    local timeout="${4:-30}"
    local result=
    _prepareHint ' ' 'hidden' 0
    _preparePrompt "${prompt}" ${timeout} 4
    read -t ${timeout} -rs result                 # TODO: refactor read loop to make it generic so we can handle ESC here!

    if (( $? > 128 )); then
        _finalizePrompt _canceledMsgTimeout italic warning
        return ${_canceledOnTimeout}
    elif  [[ ${cancelOnEmpty} == true && ! -n ${result} ]]; then
        _finalizePrompt _canceledMsgEmpty italic warning
        return ${_canceledOnEmpty}
    fi
    echo
    resultRef="${result}"
}

# Choose from a list of options, using the arrow keys.
#
# Usage: choose <prompt> <choiceIndexVarName>  <timeout seconds> choice0 choice1 ... choiceN
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

choose() {
    local prompt="${1}"
    local -n choiceIndexRef="${2}"
    local timeout="${3}"
    local choices=("${@:4}")

    _choosePaint() {
        cursorTo ${_cursorRow} 0
        for (( i=0; i <= maxChoices; i++ )); do
            if (( i == currentChoice)); then
                show bold ">" primary "${choices[${i}]}"
            else
                show primary "  ${choices[${i}]}"
            fi
        done
    }

    # Run it

    _select _selectPrepare _choosePaint
}

# Carousel chooser with fixed cursor in the middle and scrolling items.
# Assumes there are more items than can fit on screen.
#
# Usage: carousel <prompt> <choiceIndexVarName> <timeout> <useSeparator> choice0 choice1 ... choiceN
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

carousel() {
    local prompt="${1}"
    local -n choiceIndexRef="${2}"
    local timeout="${3}"
    local useSeparator="${4}"
    local choices=("${@:5}")
    local visibleRows itemsAbove itemsBelow rowsPerItem displayStartRow separatorLine offset
    local maxLength=0

    _carouselPrepare() {
        local len stripped

        # Calculate display parameters
        _carouselCalculateDisplay

        # Calculate maximum item length (strip escape sequences for accurate length)
        for (( i=0; i <= maxChoices; i++ )); do
            stripped="${ stripAnsi "${choices[${i}]}"; }"
            len=${#stripped}
            (( len > maxLength )) && maxLength=${len}
        done

        # Add 2 for the "> " prefix and 4 to extend the line on the right
        maxLength=$(( maxLength + 6 ))

        # Build separator line
        separatorLine=''
        for (( i=0; i < maxLength; i++ )); do
            separatorLine+='─'
        done
        separatorLine="${ show secondary "${separatorLine}" ;}"

        # Clear screen to allow for maximum visible lines and prepare

        clear
        _selectPrepare
    }

    _carouselCalculateDisplay() {
        # Get terminal height
        local termHeight=$(tput lines)

        # Reserve space for prompt and margins
        visibleRows=$(( termHeight - 6 ))
        reserveRows=$(( visibleRows + 3 ))

        # Rows per item (1 for item, +1 if separator)
        [[ ${useSeparator} == true ]] && rowsPerItem=2 || rowsPerItem=1

        # Calculate items above and below cursor (cursor is in middle)
        local totalItems=$(( visibleRows / rowsPerItem ))
        itemsAbove=$(( totalItems / 2 ))
        itemsBelow=$(( totalItems - itemsAbove - 1 ))

        # Position for items
        displayStartRow=3
    }

    _carouselPaint() {
        # Move to display start
        cursorTo ${displayStartRow} 0

        # Paint items in a window around current selection
        for (( offset=-itemsAbove; offset <= itemsBelow; offset++ )); do
            # Calculate wrapped index
            i=$(( (currentChoice + offset + (maxChoices + 1) * 100) % (maxChoices + 1) ))

            # Show separator line above cursor item (only once, when we reach cursor)
            (( offset == 0 )) && echo "${separatorLine}"

            # Show the item
            if (( offset == 0 )); then
                # This is the cursor position (middle)
                show bold ">" primary "${choices[${i}]}"
            else
                show primary "  ${choices[${i}]}"
            fi

            # Show separator line below cursor item (only once, immediately after cursor)
            (( offset == 0 )) && echo "${separatorLine}"

            # Add blank separator line if requested (but not adjacent to cursor separators)
            [[ ${useSeparator} == true && ${offset} -lt ${itemsBelow} && ${offset} != -1 && ${offset} != 0 ]] && echo
        done
    }

    # Run it

    _select _carouselPrepare _carouselPaint
}

# Request that the user confirm one of two choices. By default, the user must type one of the two
# answers. If one of the answers should be considered a default when only the <enter> key is pressed,
# that answer should have '=default' appended to it (e.g. yes=default).
#
# Usage: choose <prompt> <answerOne> <answerTwo> <choiceVarName> [timeout seconds]
# Output: choiceVar set to chosen answer.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

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

            local result="${_promptInput,,}"
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
            fi
        else
            return $?
        fi
    done
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/prompt' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_prompt() {
    require 'rayvn/core' 'rayvn/terminal'

    declare -gr _canceledMsgINT='canceled (ctrl-c)'
    declare -gr _canceledMsgEmpty='canceled (no input)'
    declare -gr _canceledMsgEsc='canceled (escape)'
    declare -gr _canceledMsgTimeout='canceled (timeout)'
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
    declare -g _promptInput
    declare -g _echoPromptInput

    declare -g _cancelOnEmpty
    declare -g _returnOnEmpty

    declare -g _upKeyHandler
    declare -g _upKeyFunction

    declare -g _downKeyHandler
    declare -g _downKeyFunction

    declare -g _leftKeyHandler
    declare -g _leftKeyFunction

    declare -g _rightKeyHandler
    declare -g _rightKeyFunction

    declare -g _collectInput

    declare -g _finalizeFunction
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
    (( _overwriteHint )) && printf '\e[%dG' ${_promptCol} # move cursor before hint
    _preparePromptTimer
}

_preparePromptTimer() {
    _timeoutSeconds=${timeout}
    _timeoutCheckCount=0
    _promptInput=
    SECONDS=0 # Reset bash seconds counter
}

_hasPromptTimerExpired() {
    if (( ++_timeoutCheckCount >= 10 )); then
        if (( SECONDS >= _timeoutSeconds )); then
            _finalizePrompt _canceledMsgTimeout italic warning
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
    _promptInput=
    cursorShow

    while true; do
        if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
            (( _overwriteHint )) && _clearHint
            case "${key}" in
            '' | $'\n' | $'\r') # Enter
                if [[ -z "${_promptInput// /}" ]]; then
                    if [[ ${cancelOnEmpty} == true ]]; then
                        _finalizePrompt _canceledMsgEmpty italic warning
                        return ${_canceledOnEmpty}
                    elif [[ ${returnOnEmpty} == true ]]; then
                        return 0
                    fi
                    # ignore
                else
                    _finalizePrompt _promptInput primary
                    return 0
                fi
                ;;
            $'\177' | $'\b') # Backspace
                if [[ -n "${_promptInput}" ]]; then
                    _promptInput="${_promptInput%?}"
                    printf '\b \b'
                fi
                ;;
            $'\e') # Escape
                _readPromptEscapeSequence esc || return ${_canceledOnEsc}
                ;;
            *)
                if [[ "${key}" =~ [[:print:]] ]]; then
                    _promptInput+="${key}"
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
        _finalizePrompt _canceledMsgEsc italic warning
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

# Select function shared by choose() and carousel()

_select() {
    local prepareFunction="${1}"
    local paintFunction="${2}"
    local maxChoices=$(( ${#choices[@]} - 1 ))
    local currentChoice=0
    local reserveRows=$(( maxChoices + 3 ))
    local selected
    local key i

    _configureReadPrompt --up '_selectUp' --down '_selectDown' --finalize '_selectFinalize' --returnOnEmpty
    ${prepareFunction}
    ${paintFunction}
    _readPrompt || return $?
    return 0
}

_selectPrepare() {
    _prepareHint ' ' 'use arrows to move'
    _preparePrompt "${prompt}" ${timeout} ${reserveRows}
    cursorHide
    echo
    (( _cursorRow++ )) # adjust for echo
}

_selectUp() {
    (( currentChoice == 0 )) && currentChoice=${maxChoices} || (( currentChoice-- ))
    ${paintFunction}
}

_selectDown() {
    (( currentChoice == ${maxChoices} )) && currentChoice=0 || (( currentChoice++ ))
    ${paintFunction}
}

_selectFinalize() {
    local failed="${1}"

    # Clear choices

    cursorTo ${_promptRow} ${_promptCol}
    for (( i=0; i <= maxChoices; i++ )); do
        cursorDownOneAndEraseLine
    done
    cursorTo $(( _promptRow+1 )) 0

    # Finalize the prompt if success (already done if failed).

    if (( ! failed )); then
        selected="${choices[${currentChoice}]}"
        choiceIndexRef=${currentChoice}
        _finalizePrompt selected primary
    fi
}

_configureReadPrompt() {

    # Clear all then set from arguments

    _echoPromptInput=0
    _cancelOnEmpty=0
    _returnOnEmpty=0
    _upKeyHandler=0
    _upKeyFunction=
    _downKeyHandler=0
    _downKeyFunction=
    _leftKeyHandler=0
    _leftKeyFunction=
    _rightKeyHandler=0
    _rightKeyFunction=
    _collectInput=0
    _finalizeFunction=
    _promptInput=

    while (( $# )); do
        case "$1" in
            --echo) _echoPromptInput=1 ;;
            --cancelOnEmpty) _cancelOnEmpty=1 ;;
            --returnOnEmpty) _returnOnEmpty=1 ;;
            --collect) _collectInput=1 ;;
            --up) shift; _upKeyHandler=1; _upKeyFunction="$1" ;;
            --down) shift; _downKeyHandler=1; _downKeyFunction="$1" ;;
            --left) shift; _leftKeyHandler=1; _leftKeyFunction="$1" ;;
            --right) shift; _rightKeyHandler=1; _rightKeyFunction="$1" ;;
            --finalize) shift; _finalizeFunction="$1" ;;
            *) fail "Unknown configuration option: $1" ;;
        esac
        shift
    done

    [[ -n "${_finalizeFunction}" ]] || fail "finalize function name is required"
}

_readPrompt() {
    stty cbreak -echo
    while true; do
        if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
            (( _overwriteHint )) && _clearHint

            case "${key}" in
                '' | $'\n' | $'\r') # Enter
                    if [[ -z "${_promptInput// /}" ]]; then
                        if (( _cancelOnEmpty )); then
                            _finalizePrompt _canceledMsgEmpty italic warning
                            return ${_canceledOnEmpty}
                        elif (( _returnOnEmpty )); then
                            ${_finalizeFunction} 0
                            return 0
                        fi
                    else
                        ${_finalizeFunction} 0
                        return 0
                    fi
                    ;;

            $'\e') # Escape, maybe a sequence

                if _readPromptEscapeSequence key; then
                    case "${key}" in
                        'u') (( _upKeyHandler )) && ${_upKeyFunction} ;;       # up arrow
                        'd') (( _downKeyHandler )) && ${_downKeyFunction} ;;   # down arrow
                        'l') (( _leftKeyHandler )) && ${_leftKeyFunction} ;;   # left arrow
                        'r') (( _rightKeyHandler )) && ${_rightKeyFunction} ;; # right arrow
                        *) ;; # ignore others
                    esac
                else
                    ${_finalizeFunction} 1 # ESC
                    return ${_canceledOnEsc}
                fi
                ;;

            $'\177' | $'\b') # Backspace
                if (( _collectInput )) && [[ -n "${_promptInput}" ]]; then
                    _promptInput="${_promptInput%?}"
                    (( _echoPromptInput )) && printf '\b \b'
                fi
                ;;

            *)
                if (( _collectInput )) && [[ "${key}" =~ [[:print:]] ]]; then
                    _promptInput+="${key}"
                    (( _echoPromptInput )) && printf '%s' "${key}"
                fi
                ;;
            esac
        fi

        _hasPromptTimerExpired && return ${_canceledOnTimeout}
    done
}

