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
# Usage: requestHidden <prompt> <resultVarName> [true/false cancelOnEmpty] [timeout seconds]
# Output: resultVar set to input.
# Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

requestHidden() {
    request "${1}" "${2}" "${3:-true}" "${4:-${_defaultPromptTimeout}}" true
}

# Choose from a list of options, using the arrow keys.
#
# Usage: choose <prompt> <choicesArrayVarName> <resultVarName> [timeout seconds]
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

choose() {
    local prompt="${1}"
    local choicesVarName="${2}"
    local resultVarName="${3}"
    local timeout="${4:-${_defaultPromptTimeout}}"

    _choosePaint() {
        cursorTo "${_promptChoicesStartRow}" 0
        for (( i=0; i <= _promptMaxChoicesIndex; i++ )); do
            if (( i == _promptChoiceIndex)); then
                echo "  ${_promptChoicesCursor} ${_promptDisplayChoices[$i]}"
            else
                echo "    ${_promptDisplayChoices[$i]}"
            fi
        done
    }

    _chooseUp() {
        (( _promptChoiceIndex == 0 )) && _promptChoiceIndex="${_promptMaxChoicesIndex}" || (( _promptChoiceIndex-- ))
        _choosePaint
    }

    _chooseDown() {
        (( _promptChoiceIndex == "${_promptMaxChoicesIndex}" )) && _promptChoiceIndex=0 || (( _promptChoiceIndex++ ))
        "${_promptPaintFunction}"
        _choosePaint
    }

    # Configure and run it. Don't use --reserveRows N so that it will be set automatically

    _prompt --paint _choosePaint --up _chooseUp --down _chooseDown --success _arrowPromptSuccess \
            --hint 'use arrows to move' --prompt "${prompt}" --choices "${choicesVarName}" --numberChoices \
            --timeout "${timeout}" --result "${resultVarName}"
}

# Carousel chooser with scrolling items.
# Usage: carousel <prompt> <choicesVarName> <resultIndexVarName> [true/false addSeparator] [startIndex] [maxVisible] [timeout seconds]
# If maxVisible is not passed, or is set to 0, uses all lines below the current cursor to display items; if < 0, clears and
# uses entire terminal.
#
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

carousel() {
    local prompt="${1}"
    local choicesVarName="${2}"
    local resultVarName="${3}"
    local addSeparator="${4:-false}"
    local startIndex="${5:-0}"
    local maxVisibleItems="${6:-0}"
    local timeout="${7:-${_defaultPromptTimeout}}"

    if (( maxVisibleItems < 0 )); then
        clear
        maxVisibleItems=0
    fi

    local totalVisibleItems
    local rowsPerItem
    local cursorRow
    local windowStart
    local previousCursorRow
    local previousWindowStart
    local reserveRows

    # Calculate rowsPerItem and totalVisibleItems before calling _prompt
    # so we can pass the correct reserveRows value
    [[ ${addSeparator} == true ]] && rowsPerItem=2 || rowsPerItem=1

    if (( maxVisibleItems > 0 )); then
        totalVisibleItems=${maxVisibleItems}
    else
        # Calculate based on terminal height
        local termHeight=$(tput lines)
        local visibleRows=$(( termHeight - 6 ))
        totalVisibleItems=$(( visibleRows / rowsPerItem ))
    fi

    # Calculate rows to reserve (items * rows per item)
    reserveRows=$(( totalVisibleItems * rowsPerItem + 1 ))

    _carouselInit() {
        # Don't show more items than exist (prevents duplicates)
        local totalItems=$(( _promptMaxChoicesIndex + 1 ))
        if (( totalVisibleItems > totalItems )); then
            totalVisibleItems=${totalItems}
        fi

        # Clamp _promptChoiceIndex to valid range
        if (( _promptChoiceIndex < 0 )); then
            _promptChoiceIndex=0
        elif (( _promptChoiceIndex > _promptMaxChoicesIndex )); then
            _promptChoiceIndex=${_promptMaxChoicesIndex}
        fi

        # Initialize cursor and window position based on startIndex
        if (( _promptChoiceIndex < totalVisibleItems )); then
            # Item fits in first window - no scrolling needed
            cursorRow=${_promptChoiceIndex}
            windowStart=0
        else
            # Need to scroll - position item at top of window
            # But clamp windowStart so we don't scroll past the list end
            local maxWindowStart=$(( _promptMaxChoicesIndex - totalVisibleItems + 1 ))
            if (( maxWindowStart < 0 )); then maxWindowStart=0; fi

            if (( _promptChoiceIndex <= maxWindowStart )); then
                # Can show item at top without scrolling past end
                windowStart=${_promptChoiceIndex}
                cursorRow=0
            else
                # Would scroll past end - position window at end, adjust cursor
                windowStart=${maxWindowStart}
                cursorRow=$(( _promptChoiceIndex - windowStart ))
            fi
        fi
        previousCursorRow=-1
        previousWindowStart=-1
    }

    _carouselPaint() {
        # Check if we need full repaint (window scrolled) or just cursor move
        if (( windowStart != previousWindowStart )); then
            # Window scrolled - redraw all items without clearing all to reduce flicker
            local row=${_promptChoicesStartRow}

            for (( offset=0; offset < totalVisibleItems; offset++ )); do
                local i=$(( (windowStart + offset) % (_promptMaxChoicesIndex + 1) ))

                cursorTo ${row} 0
                eraseToEndOfLine
                if (( offset == cursorRow )); then
                    echo -n "  ${_promptChoicesCursor} ${_promptDisplayChoices[$i]}"
                else
                    echo -n "    ${_promptDisplayChoices[$i]}"
                fi

                (( row++ ))

                # Add separator line if needed
                if [[ ${addSeparator} == true && ${offset} -lt $((totalVisibleItems - 1)) ]]; then
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
                local row=$(( _promptChoicesStartRow + rowOffset ))

                # Redraw old cursor line (remove cursor)
                local i=$(( (windowStart + previousCursorRow) % (_promptMaxChoicesIndex + 1) ))
                cursorTo ${row} 0
                eraseToEndOfLine
                echo -n "    ${_promptDisplayChoices[$i]}"
            fi

            # Calculate new row position
            local rowOffset=$(( cursorRow * rowsPerItem ))
            local row=$(( _promptChoicesStartRow + rowOffset ))

            # Redraw new cursor line (add cursor)
            local i=$(( (windowStart + cursorRow) % (_promptMaxChoicesIndex + 1) ))
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
            (( _promptChoiceIndex-- ))
        else
            # Cursor at top, scroll window up
            (( _promptChoiceIndex-- ))
            if (( _promptChoiceIndex < 0 )); then
                _promptChoiceIndex=${_promptMaxChoicesIndex}
            fi
            windowStart=$(( (_promptChoiceIndex + (_promptMaxChoicesIndex + 1)) % (_promptMaxChoicesIndex + 1) ))
        fi
        _carouselPaint
    }

    _carouselDown() {
        if (( cursorRow < totalVisibleItems - 1 && _promptChoiceIndex < _promptMaxChoicesIndex )); then
            # Move cursor down within window
            (( cursorRow++ ))
            (( _promptChoiceIndex++ ))
        else
            # Cursor at bottom, scroll window down
            (( _promptChoiceIndex++ ))
            if (( _promptChoiceIndex > _promptMaxChoicesIndex)); then
                _promptChoiceIndex=0
            fi
            windowStart=$(( (_promptChoiceIndex - cursorRow + (_promptMaxChoicesIndex + 1)) % (_promptMaxChoicesIndex + 1) ))
        fi
        _carouselPaint
    }

    # Configure and run

    _prompt --init _carouselInit --paint _carouselPaint --up _carouselUp --down _carouselDown --success _arrowPromptSuccess \
            --hint 'use arrows to move' --prompt "${prompt}" --choices "${choicesVarName}" --startIndex "${startIndex}" \
            --numberChoices --reserveRows "${reserveRows}" --timeout "${timeout}"\
            --result "${resultVarName}"
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
        _promptClearHint=0
        returnOnEmpty=true
        _promptHint=" ${ show -n dim italic "[" ;}${ show -n italic cyan "${answerOne}" ;}${ show -n dim italic "/${answerTwo}]" ;}"
    elif [[ ${answerTwo} == *'=default' ]]; then
        answerTwo="${answerTwo%=default}"
        defaultAnswer=${answerTwo}
        _promptClearHint=0
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

    declare -gr _promptCanceledMsgINT='canceled (ctrl-c)'
    declare -gr _promptCanceledMsgEmpty='canceled (no input)'
    declare -gr _promptCanceledMsgEsc='canceled (escape)'
    declare -gr _promptCanceledMsgTimeout='canceled (timeout)'
    declare -gr _promptCanceledOnEmptyError=1
    declare -gr _promptCanceledOnTimeoutError=124
    declare -gr _promptCanceledOnEscError=130
    declare -gr _defaultPromptTimeout=30

    # Shared global state (safe since bash is single threaded!).
    # Only valid during execution of a public function.

    # API inputs

    declare -g _promptPlain
    declare -g _promptPlainHint
    declare -g _promptHintSpace
    declare -g _promptResultVarName
    declare -g _promptEcho
    declare -g _promptCancelOnEmpty
    declare -g _promptTimeoutSeconds
    declare -g _promptClearHint
    declare -g _promptReserveRows
    declare -g _promptCollectInput
    declare -ga _promptChoices
    declare -g _promptNumberChoices
    declare -g _promptChoiceIndex

    # Callback functions

    declare -g _promptPaintFunction
    declare -g _promptUpKeyFunction
    declare -g _promptDownKeyFunction
    declare -g _promptLeftKeyFunction
    declare -g _promptRightKeyFunction
    declare -g _promptSuccessFunction

    # Internal state

    declare -g _prompt
    declare -g _promptHint
    declare -g _promptInput
    declare -g _promptRow
    declare -g _promptCol
    declare -g _promptTimeoutCheckCount
    declare -ga _promptDisplayChoices
    declare -g _promptChoicesStartRow
    declare -g _promptChoicesCursor
    declare -g _promptMaxChoicesIndex
    declare -g _promptSuccessColor
}

SECTION="--+-+-----+-++(-++(---++++(---+( generic support functions )+---)++++---)++-)++-+------+-+--"

# Configure and execute prompt
_prompt() {

    # Set defaults

    local initFunction='none'
    local choicesVarName
    local numericChoices=0

    # API inputs

    _promptPlain=
    _promptPlainHint=
    _promptHintSpace=' '
    _promptResultVarName=
    _promptEcho=1
    _promptCancelOnEmpty=0
    _promptTimeoutSeconds="${_defaultPromptTimeout}"
    _promptClearHint=
    _promptReserveRows=0
    _promptCollectInput=0
    _promptChoices=()
    _promptNumberChoices=0
    _promptChoiceIndex=0

    # Callback functions

    _promptPaintFunction=
    _promptUpKeyFunction=
    _promptDownKeyFunction=
    _promptLeftKeyFunction=
    _promptRightKeyFunction=
    _promptSuccessFunction=

    # Internal state

    _prompt=
    _promptHint=
    _promptInput=
    _promptRow=
    _promptCol=
    _promptTimeoutCheckCount=0
    _promptChoicesCursor=
    _promptDisplayChoices=()
    _promptChoicesStartRow=0
    _promptMaxChoicesIndex=0
    _promptSuccessColor='primary'

    # Update defaults from arguments

    while (( $# )); do
        case "$1" in
            --prompt) shift; _promptPlain="$1" ;;
            --hint) shift; _promptPlainHint="$1" ;;
            --hintSpace) shift; _promptHintSpace="$1" ;;
            --init) shift; initFunction="$1" ;;
            --paint) shift; _promptPaintFunction="$1" ;;
            --success) shift; _promptSuccessFunction="$1" ;;
            --result) shift; _promptResultVarName="$1" ;;
            --reserveRows) shift; _promptReserveRows="$1" ;;
            --choices) shift; _setPromptChoices "$1" ;;
            --up) shift; _promptUpKeyFunction="$1" ;;
            --down) shift; _promptDownKeyFunction="$1" ;;
            --left) shift; _promptLeftKeyFunction="$1" ;;
            --right) shift; _promptRightKeyFunction="$1" ;;
            --timeout) shift; _promptTimeoutSeconds="$1" ;;
            --startIndex) shift; _promptChoiceIndex="$1" ;;
            --numberChoices) _promptNumberChoices=1; _updateNumericPromptChoices  ;;
            --hide) _promptEcho=0 ;;
            --cancelOnEmpty) _promptCancelOnEmpty=1 ;;
            --clearHint) _promptClearHint=1 ;;
            --collect) _promptCollectInput=1 ;;
            *) fail "Unknown configuration option: $1" ;;
        esac
        shift
    done

    [[ -n ${_promptSuccessFunction} ]] || fail "success function is required"
    [[ -n ${_promptResultVarName} ]] || fail "result var name is required"

    # Call init function if provided

    [[ ${initFunction} != 'none' ]] && "${initFunction}"

    # Prepare and execute

    _preparePrompt
    _executePrompt
}

_setPromptChoices() {
    local -n choicesRef="$1"
    _promptChoices=("${choicesRef[@]}")
    _promptMaxChoicesIndex=$(( ${#_promptChoices[@]} - 1 ))
    _promptChoicesCursor="${ show bold '>'; }"

    # Set reserve rows if not set already

    (( ! _promptReserveRows )) && _promptReserveRows=$(( _promptMaxChoicesIndex + 3 ))

    # Are the choices already colored?

    if containsAnsi "${_promptChoices[0]}"; then

        # Yes, so don't color the display choices or the finalized prompt

        _promptDisplayChoices=("${_promptChoices[@]}")
        _promptSuccessColor=''
    else

        # No, so color the display choices and the finalized prompt

        for (( i=0; i <= _promptMaxChoicesIndex; i++  )); do
            _promptDisplayChoices[$i]="${ show primary "${_promptChoices[$i]}"; }"
        done
        _promptSuccessColor='primary'
    fi

    # Make sure they are numbered if requested and not done already

    _updateNumericPromptChoices
}

_updateNumericPromptChoices() {
    if (( _promptNumberChoices && _promptMaxChoicesIndex )); then
        local number
        local places=${ numericPlaces $(( _promptMaxChoicesIndex + 1 )) 1; }
        for (( i=0; i <= _promptMaxChoicesIndex; i++ )); do
            number="${ printNumber $(( $i +1 )) ${places} ; }"
            _promptDisplayChoices[$i]="${ show dim "${number}." plain "${_promptDisplayChoices[${i}]}"; }"
        done
        _promptNumberChoices=0 # don't do this again
    fi
}

_preparePrompt() {

    # Initialize & show hint and prompt

    _promptHint="${_promptHintSpace}${ show -n muted italic "[${_promptPlainHint}]" ;}"
    _prompt="${ show -n bold success "?" plain bold "${_promptPlain}" ;}${_promptHint} "
    echo -n "${_prompt}"

    # Reserve rows below prompt and set prompt row/col

    reserveRows "${_promptReserveRows}"
    _promptRow=${_cursorRow}
    _promptCol=$(( ${#_promptPlain} + 4 )) # exclude hint, include prefix & trailing space

    # Move the cursor before the hint if it is supposed to be overwritten

    (( _overwritePromptHint )) && cursorToColumn "${_promptCol}"

    # Are we preparing for select?

    if (( _promptMaxChoicesIndex )); then

        # Yes, hide the cursor

        cursorHide
        _promptChoicesStartRow=$(( _promptRow + 2 ))
    fi

    # Paint if function is set

    [[ -n ${_promptPaintFunction} ]] && "${_promptPaintFunction}"
}

_executePrompt() {
    SECONDS=0 # Reset seconds counter
    stty cbreak -echo

    while true; do
        if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
            ((_promptClearHint)) && _clearHint

            case "${key}" in
                '' | $'\n' | $'\r') # Enter
                    if ((_promptCancelOnEmpty)) && [[ -z "${_promptInput// /}" ]]; then
                        _finalizePrompt _canceledMsgEmpty italic warning
                        return "${_promptCanceledOnEmptyError}"
                    else
                        ${_promptSuccessFunction}
                        return 0
                    fi
                    ;;

            $'\e') # Escape, maybe a sequence

                if _readPromptEscapeSequence key; then
                    case "${key}" in
                        'u') [[ -v _promptUpKeyFunction ]] && ${_promptUpKeyFunction} ;;       # up arrow
                        'd') [[ -v _promptDownKeyFunction ]] && ${_promptDownKeyFunction} ;;   # down arrow
                        'l') [[ -v _promptLeftKeyFunction ]] && ${_promptLeftKeyFunction} ;;   # left arrow
                        'r') [[ -v _promptRightKeyFunction ]] && ${_promptRightKeyFunction} ;; # right arrow
                        *) ;; # ignore others
                    esac
                    SECONDS=0 # Reset timer
                else
                    _finalizePrompt _canceledMsgEsc italic warning
                    return "${_promptCanceledOnEscError}"
                fi
                ;;

            $'\177' | $'\b') # Backspace
                if ((_promptCollectInput)) && [[ -n "${_promptInput}" ]]; then
                    _promptInput="${_promptInput%?}"
                    (( _promptEcho )) && printf '\b \b'
                    SECONDS=0 # Reset timer
                fi
                ;;

            *)
                if ((_promptCollectInput)) && [[ "${key}" =~ [[:print:]] ]]; then
                    _promptInput+="${key}"
                    (( _promptEcho )) && echo -n "${key}"
                    SECONDS=0 # Reset timer
                fi
                ;;
            esac
        fi

        _hasPromptTimerExpired && return "${_promptCanceledOnTimeoutError}"
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
                        *)   resultVar='?'; break ;;  # Unknown/don't care
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
    _promptClearHint=0
    cursorToColumnAndEraseToEndOfLine ${_promptCol}
}

_hasPromptTimerExpired() {
    if (( ++_promptTimeoutCheckCount >= 10 )); then
        if (( SECONDS >= _promptTimeoutSeconds)); then
            _finalizePrompt _canceledMsgTimeout italic warning
            return 0
        fi
        _promptTimeoutCheckCount=0
    fi
    return ${_promptCanceledOnTimeoutError}
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
    if (( _promptMaxChoicesIndex )); then
        cursorDownOneAndEraseLine
        for (( i=0; i <= _promptMaxChoicesIndex; i++ )); do
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
    _promptInput="${_promptChoices[${_promptChoiceIndex}]}"
    _promptSuccess "${_promptChoiceIndex}"
}
