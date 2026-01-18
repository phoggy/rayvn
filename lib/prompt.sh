#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library of user input functions.
# Intended for use via: require 'rayvn/prompt'

# Read user input.
#
# Usage: request <prompt> <resultVarName> [true/false cancel-on-empty] [timeout seconds] [true/false hidden]
# Output: resultVar set to input.
# Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

request() {
    local prompt="${1}"
    local resultVarName="${2}"
    local cancelOnEmpty="${3:-true}"
    local timeout="${4:-30}"
    local hide=${5:-false}
    local flags=()
    local hint
    local clearHint=
    [[ ${cancelOnEmpty} == true ]] && flags+=('--cancelOnEmpty')
    if [[ ${hide} == true ]]; then
        flags+=('--hide')
        hint='hidden'
    else
        flags+=('--clearHint')
        hint='type your answer here'
    fi

    # Configure and run

    _prompt --success '_promptInputSuccess' --result "${resultVarName}" --reserveRows 4 \
            --hint "${hint}" --prompt "${prompt}" --collect --timeout "${timeout}" ${flags[*]}
 }


# Read user input without echoing it to the terminal.
#
# Usage: requestHidden <prompt> <resultVarName> [true/false cancel-on-empty] [timeout seconds]
# Output: resultVar set to input.
# Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

requestHidden() {
    request "${1}" "${2}" "${3:-true}" "${4:-30}" true
}

# Choose from a list of options, using the arrow keys.
#
# Usage: choose <prompt> <choiceIndexVarName>  <timeout seconds> choice0 choice1 ... choiceN
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

choose() {
    local prompt="${1}"
    local resultVarName="${2}"
    local timeout="${3}"
    local choices=("${@:4}")

    _choosePaint() {
        cursorTo ${_cursorRow} 0
        for (( i=0; i <= _maxPromptIndex; i++ )); do
            if (( i == _currentPromptIndex)); then
                show bold ">" primary "${choices[${i}]}"
            else
                show primary "  ${choices[${i}]}"
            fi
        done
    }

    # Run it

    _select null _choosePaint "${prompt}" "${resultVarName}" "${timeout}" 'choices'
}

# Carousel chooser with fixed cursor in the middle and scrolling items.
# Assumes there are more items than can fit on screen.
#
# Usage: carousel <prompt> <choiceIndexVarName> <timeout> <useSeparator> choice0 choice1 ... choiceN
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

carousel() {
    local prompt="${1}"
    local resultVarName="${2}"
    local timeout="${3}"
    local useSeparator="${4}"
    local choices=("${@:5}")
    local maxChoices="${#choices[@]}"
    local visibleRows reserveRows itemsAbove itemsBelow rowsPerItem displayStartRow separatorLine offset
    local maxLineLength=0
    local len stripped

    _carouselInit() {
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

        # Calculate maximum item length (strip escape sequences for accurate length)
        for (( i=0; i <= maxChoices; i++ )); do
            stripped="${ stripAnsi "${choices[${i}]}"; }"
            len=${#stripped}
            (( len > maxLineLength )) && maxLineLength=${len}
        done

        # Add 2 for the "> " prefix and 4 to extend the line on the right
        maxLineLength=$(( maxLineLength + 6 ))

        # Build separator line
        separatorLine=''
        for (( i=0; i < maxLineLength; i++ )); do
            separatorLine+='─'
        done
        separatorLine="${ show secondary "${separatorLine}" ;}"

        # Clear screen to allow for maximum visible lines

        clear
    }

    _carouselPaint() {
        # Move to display start
        cursorTo ${displayStartRow} 0

        # Paint items in a window around current selection
        for (( offset=-itemsAbove; offset <= itemsBelow; offset++ )); do
            # Calculate wrapped index
            i=$(( (_currentPromptIndex + offset + (maxChoices + 1) * 100) % (maxChoices + 1) ))

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

    # Configure and run

    _select _carouselInit _carouselPaint "${prompt}" "${resultVarName}" "${timeout}" 'choices'
}

# Request that the user choose 'yes' or 'no'. To have 'no'
#
# Usage: choose <prompt> <choiceVarName> ['no'] [timeout seconds]
# Output: choiceVar set to chosen answer.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

confirm() {
fail "confirm() not updated, TODO!" # TODO: update to use _readPrompt and left/right arrows to select

    # Do you want to continue? yes no

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
        _clearPromptHint=0
        returnOnEmpty=true
        _promptHint=" ${ show -n dim italic "[" ;}${ show -n italic cyan "${answerOne}" ;}${ show -n dim italic "/${answerTwo}]" ;}"
    elif [[ ${answerTwo} == *'=default' ]]; then
        answerTwo="${answerTwo%=default}"
        defaultAnswer=${answerTwo}
        _clearPromptHint=0
        returnOnEmpty=true
        _promptHint=" ${ show -n dim italic "[${answerOne}/" ;}${ show -n italic cyan "${answerTwo}" ;}${ show -n dim italic "]" ;}"
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

    declare -g _plainPromptHint
    declare -g _prompt
    declare -g _plainPrompt
    declare -g _promptRow
    declare -gi _promptCol
    declare -g _promptHint
    declare -g _promptHintSpace
    declare -ga _promptChoices
    declare -g _clearPromptHint
    declare -g _timeoutSeconds
    declare -gi _timeoutCheckCount
    declare -g _promptResultVarName
    declare -g _promptInput
    declare -g _promptEcho
    declare -g _promptPaintFunction
    declare -g _promptSuccessFunction

    declare -g _cancelOnEmpty

    declare -g _upKeyHandler
    declare -g _upKeyFunction

    declare -g _downKeyHandler
    declare -g _downKeyFunction

    declare -g _leftKeyHandler
    declare -g _leftKeyFunction

    declare -g _rightKeyHandler
    declare -g _rightKeyFunction

    declare -g _collectInput
    declare -g _promptReserveRows
    declare -g _promptClearRows

    declare -ga choices
    declare -g _currentPromptIndex
    declare -g _maxPromptIndex
}


# Configure and run prompt
_prompt() {

    # Set defaults then update from arguments

    local initFunction='null'
    local choicesVarName

    _promptInput=
    _promptPaintFunction=
    _promptSuccessFunction=
    _promptResultVarName=
    _promptEcho=1
    _cancelOnEmpty=0
    _upKeyHandler=0
    _upKeyFunction=
    _downKeyHandler=0
    _downKeyFunction=
    _leftKeyHandler=0
    _leftKeyFunction=
    _rightKeyHandler=0
    _rightKeyFunction=
    _collectInput=0
    _promptClearRows=0
    _promptReserveRows=0
    _currentPromptIndex=0
    _maxPromptIndex=0
    _prompt=
    _plainPrompt=
    _plainPromptHint=
    _promptHint=
    _promptHintSpace=' '
    _promptChoices=()
    _clearPromptHint=
    _timeoutSeconds=60 # long default
    _timeoutCheckCount=0

    while (( $# )); do
        case "$1" in
            --prompt) shift; _plainPrompt="$1" ;;
            --hint) shift; _plainPromptHint="$1" ;;
            --hintSpace) shift; _promptHintSpace="$1" ;;
            --clearHint) _clearPromptHint=1 ;;
            --init) shift; initFunction="$1" ;;
            --paint) shift; _promptPaintFunction="$1" ;;
            --success) shift; _promptSuccessFunction="$1" ;;
            --result) shift; _promptResultVarName="$1" ;;
            --reserveRows) shift; _promptReserveRows="$1" ;;
            --choices) shift; choicesVarName="$1" ;;
            --hide) _promptEcho=0 ;;
            --cancelOnEmpty) _cancelOnEmpty=1 ;;
            --collect) _collectInput=1 ;;
            --up) shift; _upKeyHandler=1; _upKeyFunction="$1" ;;
            --down) shift; _downKeyHandler=1; _downKeyFunction="$1" ;;
            --left) shift; _leftKeyHandler=1; _leftKeyFunction="$1" ;;
            --right) shift; _rightKeyHandler=1; _rightKeyFunction="$1" ;;
            --timeout) shift; _timeoutSeconds="$1" ;;
            --maxIndex) shift; _maxPromptIndex="$1" ;;
            *) fail "Unknown configuration option: $1" ;;
        esac
        shift
    done

    [[ -n ${_promptSuccessFunction} ]] || fail "success function is required"
    [[ -n ${_promptResultVarName} ]] || fail "result var name is required"

    # Init choices if supplied

    if [[ -n "${choicesVarName}" ]]; then
        local -n choicesRef="${choicesVarName}"
        _promptChoices=("${choicesRef[@]}")
        _maxPromptIndex=$(( ${#choicesRef[@]} - 1 ))
        _promptReserveRows=$(( _maxPromptIndex + 3 ))
    fi

    # Call init function if set

    [[ ${initFunction} != 'null' ]] && "${initFunction}"

    # Reset bash seconds counter

    SECONDS=0

    # Prepare and execute

    _preparePrompt
    _executePrompt
}

_preparePrompt() {

    # Initialize & show hint and prompt

    _promptHint="${_promptHintSpace}${ show -n muted italic "[${_plainPromptHint}]" ;}"
    _prompt="${ show -n bold success "?" plain bold "${_plainPrompt}" ;}${_promptHint} "
    echo -n "${_prompt}"

    # Reserve rows below prompt and set prompt row/col

    reserveRows "${_promptReserveRows}"
    _promptRow=${_cursorRow}
    _promptCol="${#_plainPrompt} + 4" # exclude hint, include prefix & trailing space

    # Move the cursor before the hint if it is supposed to be overwritten

    (( _overwritePromptHint )) && printf '\e[%dG' ${_promptCol}

    # Are we preparing for select?

    if (( _maxPromptIndex )); then

        # Yes, do a bit more
        cursorHide
        echo
        (( _cursorRow++ )) # adjust for echo
    fi

    # Paint if function is set

    [[ -n ${_promptPaintFunction} ]] && "${_promptPaintFunction}"
}

_executePrompt() {
    stty cbreak -echo
    while true; do
        if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
            (( _clearPromptHint )) && _clearHint

            case "${key}" in
                '' | $'\n' | $'\r') # Enter
                    if (( _cancelOnEmpty )) && [[ -z "${_promptInput// /}" ]]; then
                        _finalizePrompt _canceledMsgEmpty italic warning
                        return "${_canceledOnEmpty}"
                    else
                        ${_promptSuccessFunction}
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
                    _finalizePrompt _canceledMsgEsc italic warning
                    return "${_canceledOnEsc}"
                fi
                ;;

            $'\177' | $'\b') # Backspace
                if (( _collectInput )) && [[ -n "${_promptInput}" ]]; then
                    _promptInput="${_promptInput%?}"
                    (( _promptEcho )) && printf '\b \b'
                fi
                ;;

            *)
                if (( _collectInput )) && [[ "${key}" =~ [[:print:]] ]]; then
                    _promptInput+="${key}"
                    (( _promptEcho )) && echo -n "${key}"
                fi
                ;;
            esac
        fi

        _hasPromptTimerExpired && return "${_canceledOnTimeout}"
    done
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
        return 1 # No, so ESC
    fi
}

_clearHint() {
    _overwritePromptHint=0
    _clearPromptHint=0
    printf '\e[%dG\e[K' ${_promptCol}
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

_promptInputSuccess() {
    _promptSuccess "${_promptInput}"
}

_promptSuccess() {
    local result="${1}"
    local -n resultVarRef="${_promptResultVarName}"
    _finalizePrompt _promptInput primary
    resultVarRef="${result}"
    return 0
}

_finalizePrompt() {
    local -n resultMessageRef="${1}"
    local formats=("${@:2}")

    # Reposition cursor to after the prompt and save it

    cursorTo ${_promptRow} ${_promptCol}
    cursorSave

    # Clear any text after the prompt

    eraseToEndOfLine
    for (( i=0; i <= _maxPromptIndex; i++ )); do
        cursorDownOneAndEraseLine
    done

    # Restore cursor and show result message

    cursorRestore
    show "${formats[@]}" "${resultMessageRef}"

    # Restore terminal settings

    stty "${_originalStty}"
}

SECTION="--+-+-----+-++(-++(---++++(---+( choose/carousel support )+---)++++---)++-)++-+------+-+--"

_select() {
    local initFunction="${1}"
    local paintFunction="${2}"
    local prompt="${3}"
    local resultVarName="${4}"
    local timeout="${5}"
    local choicesVarName=${6}

    # Configure and run

    _prompt --init "${initFunction}" --paint "${paintFunction}" --success '_promptSelectSuccess'  \
            --result "${resultVarName}" --timeout "${timeout}" \
            --hint 'use arrows to move' --prompt "${prompt}" --choices ${choicesVarName} \
            --up '_selectUp' --down '_selectDown'
}

_selectUp() {
    (( _currentPromptIndex == 0 )) && _currentPromptIndex="${_maxPromptIndex}" || (( _currentPromptIndex-- ))
    "${_promptPaintFunction}"
}

_selectDown() {
    (( _currentPromptIndex == "${_maxPromptIndex}" )) && _currentPromptIndex=0 || (( _currentPromptIndex++ ))
    "${_promptPaintFunction}"
}

_promptSelectSuccess() {
    _promptInput="${choices[${_currentPromptIndex}]}"
    _promptSuccess "${_currentPromptIndex}"
}
