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
    local timeout="${4:-${_defaultPromptTimeout}}"
    local hide=${5:-false}
    local args=()
    local hint
    local clearHint=
    [[ ${cancelOnEmpty} == true ]] && args+=('--cancelOnEmpty')
    if [[ ${hide} == true ]]; then
        hint='hidden'
        args+=('--hide')
    else
        hint='type your answer here'
        args+=('--clearHint')
    fi

    # Configure and run

    _prompt --prompt "${prompt}" --hint "${hint}" --result "${resultVarName}" --timeout "${timeout}" \
            --reserveRows 4 --collect "${args[@]}" --success '_textPromptSuccess'
 }

# Read user input without echoing it to the terminal.
#
# Usage: requestHidden <prompt> <resultVarName> [true/false cancel-on-empty] [timeout seconds]
# Output: resultVar set to input.
# Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

requestHidden() {
    request "${1}" "${2}" "${3:-true}" "${4:-${_defaultPromptTimeout}}" true
}

# Choose from a list of options, using the arrow keys.
#
# Usage: choose <prompt> <choicesArrayVarName> <resultVarName> <timeout seconds>
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

choose() {
    local prompt="${1}"
    local choicesVarName="${2}"
    local resultVarName="${3}"
    local timeout="${4:-${_defaultPromptTimeout}}"

    _choosePaint() {
        cursorTo $(( _cursorRow + 2 )) 0
        for (( i=0; i <= _maxPromptChoicesIndex; i++ )); do
            if (( i == _currentPromptChoiceIndex)); then
                echo "  ${_promptChoicesCursor} ${_promptDisplayChoices[$i]}"
            else
                echo "    ${_promptDisplayChoices[$i]}"
            fi
        done
    }

    _chooseUp() {
        (( _currentPromptChoiceIndex == 0 )) && _currentPromptChoiceIndex="${_maxPromptChoicesIndex}" || (( _currentPromptChoiceIndex-- ))
        _choosePaint
    }

    _chooseDown() {
        (( _currentPromptChoiceIndex == "${_maxPromptChoicesIndex}" )) && _currentPromptChoiceIndex=0 || (( _currentPromptChoiceIndex++ ))
        "${_promptPaintFunction}"
        _choosePaint
    }

    # Configure and run it. Don't use --reserveRows N so that it will be set automatically

    _prompt --paint _choosePaint --up _chooseUp --down _chooseDown --success _arrowPromptSuccess \
            --hint 'use arrows to move' --prompt "${prompt}" --choices "${choicesVarName}" --numberChoices \
            --timeout "${timeout}" --result "${resultVarName}"
}

# Carousel chooser with fixed cursor in the middle and scrolling items.
# Assumes there are more items than can fit on screen.
#
# Usage: carousel <prompt> <choiceIndexVarName> <timeout> <useSeparator> choice0 choice1 ... choiceN
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

carousel() {
    local prompt="${1}"
    local choicesVarName="${2}"
    local resultVarName="${3}"
    local useSeparator="${4}"
    local timeout="${5:-${_defaultPromptTimeout}}"

    # Get terminal height
    local termHeight=$(tput lines)

    # Reserve space for prompt and margins
    local visibleRows=$(( termHeight - 6 ))

    # Rows per item (1 for item, +1 if separator)
    local rowsPerItem
    [[ ${useSeparator} == true ]] && rowsPerItem=2 || rowsPerItem=1

    # Calculate total visible items
    local totalVisibleItems=$(( visibleRows / rowsPerItem ))

    # Position for items
    local displayStartRow=3

    # Initialize cursor at top and window at start

    local cursorRow=0
    local windowStart=0
    local previousCursorRow=-1
    local previousWindowStart=-1

    # Clear screen to allow for maximum visible lines
    clear # TODO: only do this if remaining visible rows is < available. IOW, don't take up the whole window by default!

    _carouselPaint() {

        # Check if we need full repaint (window scrolled) or just cursor move
        if (( windowStart != previousWindowStart )); then
            # Window scrolled - redraw all items without clearing first to reduce flicker
            local row=${displayStartRow}

            for (( offset=0; offset < totalVisibleItems; offset++ )); do
                local i=$(( (windowStart + offset) % (_maxPromptChoicesIndex + 1) ))

                cursorTo ${row} 0
                eraseToEndOfLine
                if (( offset == cursorRow )); then
                    echo -n "  ${_promptChoicesCursor} ${_promptDisplayChoices[$i]}"
                else
                    echo -n "    ${_promptDisplayChoices[$i]}"
                fi

                (( row++ ))

                # Add separator line if needed
                if [[ ${useSeparator} == true && ${offset} -lt $((totalVisibleItems - 1)) ]]; then
                    cursorTo ${row} 0
                    eraseToEndOfLine
                    echo -n ""
                    (( row++ ))
                fi
            done
        else
            # Partial update - only cursor moved within window
            if (( previousCursorRow >= 0 )); then
                # Calculate row position accounting for separators
                local rowOffset=$(( previousCursorRow * rowsPerItem ))
                local row=$(( displayStartRow + rowOffset ))

                # Redraw old cursor line (remove cursor)
                local i=$(( (windowStart + previousCursorRow) % (_maxPromptChoicesIndex + 1) ))
                cursorTo ${row} 0
                eraseToEndOfLine
                echo -n "    ${_promptDisplayChoices[$i]}"
            fi

            # Calculate new row position
            local rowOffset=$(( cursorRow * rowsPerItem ))
            local row=$(( displayStartRow + rowOffset ))

            # Redraw new cursor line (add cursor)
            local i=$(( (windowStart + cursorRow) % (_maxPromptChoicesIndex + 1) ))
            cursorTo ${row} 0
            eraseToEndOfLine
            echo -n "  ${_promptChoicesCursor} ${_promptDisplayChoices[$i]}"
        fi

        # Update previous positions
        previousCursorRow=${cursorRow}
        previousWindowStart=${windowStart}
    }

    _carouselUp() {
        if (( cursorRow > 0 )); then
            # Move cursor up within window
            (( cursorRow-- ))
            (( _currentPromptChoiceIndex-- ))
        else
            # Cursor at top, scroll window up
            (( _currentPromptChoiceIndex-- ))
            if (( _currentPromptChoiceIndex < 0 )); then
                _currentPromptChoiceIndex=${_maxPromptChoicesIndex}
            fi
            windowStart=$(( (_currentPromptChoiceIndex + (_maxPromptChoicesIndex + 1)) % (_maxPromptChoicesIndex + 1) ))
        fi
        _carouselPaint
    }

    _carouselDown() {
        if (( cursorRow < totalVisibleItems - 1 )); then
            # Move cursor down within window
            (( cursorRow++ ))
            (( _currentPromptChoiceIndex++ ))
        else
            # Cursor at bottom, scroll window down
            (( _currentPromptChoiceIndex++ ))
            if (( _currentPromptChoiceIndex > _maxPromptChoicesIndex )); then
                _currentPromptChoiceIndex=0
            fi
            windowStart=$(( (_currentPromptChoiceIndex - cursorRow + (_maxPromptChoicesIndex + 1)) % (_maxPromptChoicesIndex + 1) ))
        fi
        _carouselPaint
    }

    # Configure and run

    _prompt --paint _carouselPaint --up _carouselUp --down _carouselDown --success _arrowPromptSuccess \
            --hint 'use arrows to move' --prompt "${prompt}" --choices "${choicesVarName}" --numberChoices \
            --reserveRows "${totalVisibleItems}" --timeout "${timeout}" --result "${resultVarName}"
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
    local timeout="${6:-${_defaultPromptTimeout}}"
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
    declare -gr _defaultPromptTimeout=30

    # Shared global state (safe since bash is single threaded!).
    # Only valid during execution of public functions.

    declare -g _plainPromptHint
    declare -g _prompt
    declare -g _plainPrompt
    declare -g _promptRow
    declare -gi _promptCol
    declare -g _promptHint
    declare -g _promptHintSpace
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

    declare -ga _promptChoices
    declare -ga _promptDisplayChoices
    declare -g _promptSuccessColor
    declare -g _promptChoicesCursor
    declare -g _currentPromptChoiceIndex
    declare -g _maxPromptChoicesIndex
}

SECTION="--+-+-----+-++(-++(---++++(---+( generic support functions )+---)++++---)++-)++-+------+-+--"

# Configure and run prompt
_prompt() {

    # Set defaults then update from arguments

    local initFunction='none'
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
    _promptReserveRows=0
    _prompt=
    _plainPrompt=
    _plainPromptHint=
    _promptHint=
    _promptHintSpace=' '
    _promptSuccessColor='primary'
    _clearPromptHint=
    _numberPromptChoices=0
    _timeoutSeconds="${_defaultPromptTimeout}"
    _timeoutCheckCount=0

    while (( $# )); do
        case "$1" in
            --prompt) shift; _plainPrompt="$1" ;;
            --hint) shift; _plainPromptHint="$1" ;;
            --hintSpace) shift; _promptHintSpace="$1" ;;
            --init) shift; initFunction="$1" ;;
            --paint) shift; _promptPaintFunction="$1" ;;
            --success) shift; _promptSuccessFunction="$1" ;;
            --result) shift; _promptResultVarName="$1" ;;
            --reserveRows) shift; _promptReserveRows="$1" ;;
            --choices) shift; _setPromptChoices "$1" ;;
            --up) shift; _upKeyHandler=1; _upKeyFunction="$1" ;;
            --down) shift; _downKeyHandler=1; _downKeyFunction="$1" ;;
            --left) shift; _leftKeyHandler=1; _leftKeyFunction="$1" ;;
            --right) shift; _rightKeyHandler=1; _rightKeyFunction="$1" ;;
            --timeout) shift; _timeoutSeconds="$1" ;;
            --maxIndex) shift; _maxPromptChoicesIndex="$1" ;;
            --numberChoices) _numberPromptChoices=1; _updateNumericPromptChoices  ;;
            --hide) _promptEcho=0 ;;
            --cancelOnEmpty) _cancelOnEmpty=1 ;;
            --clearHint) _clearPromptHint=1 ;;
            --collect) _collectInput=1 ;;
            *) fail "Unknown configuration option: $1" ;;
        esac
        shift
    done

    [[ -n ${_promptSuccessFunction} ]] || fail "success function is required"
    [[ -n ${_promptResultVarName} ]] || fail "result var name is required"

    # Call init function if provided

    [[ ${initFunction} != 'none' ]] && "${initFunction}"

    # Reset bash seconds counter

    SECONDS=0

    # Prepare and execute

    _preparePrompt
    _executePrompt
}

_setPromptChoices() {
    local -n choicesRef="$1"
    _currentPromptChoiceIndex=0
    _promptChoices=("${choicesRef[@]}")
    _maxPromptChoicesIndex=$(( ${#_promptChoices[@]} - 1 ))
    _promptChoicesCursor="${ show bold '>'; }"

    # Set reserve rows if not set already

    (( ! _promptReserveRows )) && _promptReserveRows=$(( _maxPromptChoicesIndex + 3 ))

    # Are the choices already colored?

    if containsAnsi "${_promptChoices[0]}"; then

        # Yes, so don't color the display choices or the finalized prompt

        _promptDisplayChoices=("${_promptChoices[@]}")
        _promptSuccessColor=''
    else

        # No, so color the display choices and the finalized prompt

        for (( i=0; i <= _maxPromptChoicesIndex; i++  )); do
            _promptDisplayChoices[$i]="${ show primary "${_promptChoices[$i]}"; }"
        done
        _promptSuccessColor='primary'
    fi

    # Make sure they are numbered if requested and not done already

    _updateNumericPromptChoices
}

_updateNumericPromptChoices() {
    if (( _numberPromptChoices )); then
        local number
        local places=${ numericPlaces $(( _maxPromptChoicesIndex + 1 )) 1; }
        for (( i=0; i <= _maxPromptChoicesIndex; i++ )); do
            number="${ printNumber $(( $i +1 )) ${places} ; }"
            _promptDisplayChoices[$i]="${ show dim "${number}." plain "${_promptDisplayChoices[${i}]}"; }"
        done
        _numberPromptChoices=0 # don't do this again
    fi
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

    if (( _maxPromptChoicesIndex )); then

        # Yes, hide the cursor

        cursorHide
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

_hasPromptTimerExpired() {                    # TODO option to reset SECONDS to 0 on any keystroke (e.g. for carousel)
    if (( ++_timeoutCheckCount >= 10 )); then
        if (( SECONDS >= _timeoutSeconds )); then
            _finalizePrompt _canceledMsgTimeout italic warning
            return 0
        fi
        _timeoutCheckCount=0
    fi
    return ${_canceledOnTimeout}
}

_promptSuccess() {
    local result="${1}"
    local -n resultVarRef="${_promptResultVarName}"
    resultVarRef="${result}"
    _finalizePrompt _promptInput "${_promptSuccessColor}"
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
    if (( _maxPromptChoicesIndex )); then
        for (( i=0; i <= _maxPromptChoicesIndex; i++ )); do
            cursorDownOneAndEraseLine
        done
    fi

    # Restore cursor and show result message

    cursorRestore
    show "${formats[@]}" "${resultMessageRef}"

    # Restore terminal settings

    stty "${_originalStty}"
}


SECTION="--+-+-----+-++(-++(---++++(---+( text input support )+---)++++---)++-)++-+------+-+--"

_textPromptSuccess() {
    _promptSuccess "${_promptInput}"
}

SECTION="--+-+-----+-++(-++(---++++(---+( arrow key selection support )+---)++++---)++-)++-+------+-+--"

_arrowPromptSuccess() {
    _promptInput="${_promptChoices[${_currentPromptChoiceIndex}]}"
    _promptSuccess "${_currentPromptChoiceIndex}"
}
