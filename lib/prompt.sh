#!/usr/bin/env bash
# shellcheck disable=SC2155

# Library of user input functions.
# Intended for use via: require 'rayvn/prompt'

# Read user input.
#
# Usage: request <prompt> <resultVarName> [true/false cancel-on-empty] [timeout seconds] [true/false hidden]
#
# The seconds counter is reset to 0 on every key press, so timeout applies only to inactivity.
#
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
            --reserveRows 4 --collect "${args[@]}" \
            --success '_textPromptSuccess'
 }

# Read user input without echoing it to the terminal.
#
# Usage: requestHidden <prompt> <resultVarName> [true/false cancelOnEmpty] [timeout seconds]
#
# The seconds counter is reset to 0 on every key press, so timeout applies only to inactivity.
#
# Output: resultVar set to input.
# Exit codes: 0 = success, 1 = empty input & cancel-on-empty=true, 124 = timeout, 130 = user canceled (ESC pressed)

secureRequest() {
    request "${1}" "${2}" "${3:-true}" "${4:-${_defaultPromptTimeout}}" true
}

# Ask the user to confirm a side-by-side choice, e.g. 'yes' or 'no'.
#
# Usage: confirm <prompt> <answer1> <answer2> <choiceIndexVarName> [true/false defaultAnswerTwo] [timeout seconds]
#
# Answer 1 will be selected first by default. For an important action (e.g. deleting / creating something), consider
# making it a *little* harder to select the positive choice so that two key presses (arrow and enter) are required.
# There are two ways to accomplish this:
#
#    1. Pass the negative answer first, or
#    2. Pass 'true' for defaultAnswerTwo to maintain a consistent answer sequence across invocations
#
# The seconds counter is reset to 0 on every key press, so timeout applies only to inactivity.
#
# Output: choiceIndexVar set to 0 for answer 1 or 1 for answer 2
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

confirm() {
    local prompt="${1}"
    local promptChoices=("${2}" "${3}")
    local resultVarName="${4}"
    local defaultAnswerTwo="${5:-false}"
    local timeout="${6:-${_defaultPromptTimeout}}"
    local startIndex=0
    local display=()
    [[ ${defaultAnswerTwo} == true ]] && startIndex=1

    _confirmInit() {
        display[0]="${ show -n success "${_promptDisplayChoices[0]}"; } ${_promptDisplayChoices[1]}${_promptHint}"
        display[1]="${_promptDisplayChoices[0]} ${ show -n success "${_promptDisplayChoices[1]}"; }${_promptHint}"
        _promptClearHint=0
    }

    _confirmPaint() {
        cursorTo "${_promptRow}" "${_promptCol}"
        echo -n "${display[${_promptChoiceIndex}]} "
    }

    _confirmLeft() {
        (( _promptChoiceIndex == 1 )) && _promptChoiceIndex=0
        _confirmPaint
    }

    _confirmRight() {
        (( _promptChoiceIndex == 0 )) && _promptChoiceIndex=1
        _confirmPaint
    }

    _prompt --prompt "${prompt}" --hint '↔ arrows to move, ESC to cancel'  --result "${resultVarName}" \
            --choices promptChoices --startIndex "${startIndex}" --doNotColorChoices --clearHint \
            --reserveRows 4 --timeout "${timeout}"  \
            --init _confirmInit --paint _confirmPaint --left _confirmLeft --right _confirmRight --success _arrowPromptSuccess
}

# Choose from a list of options using the arrow keys.
#
# Usage: choose <prompt> <choicesVarName> <resultIndexVarName> [true/false addSeparator] [startIndex] [numberChoices]
#               [maxVisible] [timeout seconds]
#
# If numberChoices is > 0 choices will be numbered, and if < 0, numbers will be added only if there are non-visible choices.
#
# If maxVisible is not passed, or is set to 0, uses all lines below the current cursor to display items; if < 0, clears and
# uses entire terminal.
#
# The seconds counter is reset to 0 on every key press, so timeout applies only to inactivity.
#
# Output: choiceIndexVar set to index of selected choice.
# Exit codes: 0 = success, 124 = timeout, 130 = user canceled (ESC pressed)

choose() {
    local prompt="${1}"
    local choicesVarName="${2}"
    local resultVarName="${3}"
    local addSeparator="${4:-false}"
    local startIndex="${5:-0}"
    local numberChoices="${6:-0}"
    local maxVisibleItems="${7:-0}"
    local timeout="${8:-${_defaultPromptTimeout}}"
    local totalVisibleItems
    local rowsPerItem
    local cursorRow
    local windowStart
    local previousCursorRow
    local previousWindowStart
    local reserveRows
    local args=()
    local nonVisibleItems=0

    # Before calling _prompt, we need to know the correct # of rows to
    # reserve. First, get the itemCount, rowsPerItem and extraLines

    local -n choicesArray="${choicesVarName}"
    local itemCount="${#choicesArray[@]}"
    [[ ${addSeparator} == true ]] && rowsPerItem=2 || rowsPerItem=1
    local extraLines=${ (( rowsPerItem == 1 )) && echo 2 || echo 1; }

    # Determine totalVisibleItems

    if (( maxVisibleItems > 0 )); then
        if (( maxVisibleItems > itemCount )); then
            totalVisibleItems=${itemCount}
        else
            totalVisibleItems=${maxVisibleItems}
        fi
    else
        # Clear the screen if maxVisibleItems is negative

        (( maxVisibleItems < 0 )) && clear

        # Calculate based on terminal height and item count

        local availableRows=$(tput lines)
        local visibleRows=$(( availableRows - 6 ))
        totalVisibleItems=$(( visibleRows / rowsPerItem ))
        (( totalVisibleItems > itemCount )) && totalVisibleItems=${itemCount}
    fi

    # Calculate rows to reserve

    reserveRows=$(( (totalVisibleItems * rowsPerItem) + extraLines ))

    # Count non-visible items

    (( totalVisibleItems < itemCount )) && nonVisibleItems=$(( itemCount - totalVisibleItems ))

    # Decide whether to number the items

    if (( numberChoices > 0 )); then
        args+=('--numberChoices')
    elif (( numberChoices < 0 && nonVisibleItems )); then
        args+=('--numberChoices') # we have non-visible items
    fi

    # Update hint if there are non-visible items

    (( nonVisibleItems )) && hint+=", ${nonVisibleItems} items not visible"

    _chooseInit() {
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

    _choosePaint() {
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

    _chooseUp() {
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
        _choosePaint
    }

    _chooseDown() {
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
        _choosePaint
    }

    # Configure and run

    _prompt --prompt "${prompt}" --hint '↑↓ arrows to move, ESC to cancel' --result "${resultVarName}" \
            --choices "${choicesVarName}" --startIndex "${startIndex}" \
            --reserveRows "${reserveRows}" --timeout "${timeout}" "${args[@]}" \
            --init _chooseInit --paint _choosePaint --up _chooseUp --down _chooseDown --success _arrowPromptSuccess
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

    declare -g _promptInitFunction
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
    declare -g _promptChoicesVarName
    declare -ga _promptDisplayChoices
    declare -g _promptChoicesStartRow
    declare -g _promptChoicesCursor
    declare -g _promptDoNotColorChoices
    declare -g _promptMaxChoicesIndex
    declare -g _promptSuccessColor
}

SECTION="--+-+-----+-++(-++(---++++(---+( generic support functions )+---)++++---)++-)++-+------+-+--"

# Configure and execute prompt
_prompt() {

    # Set API input defaults

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
    _promptChoicesVarName=
    _promptChoices=()
    _promptNumberChoices=0
    _promptChoiceIndex=0

    # Set Callback function defaults

    _promptInitFunction=
    _promptPaintFunction=
    _promptUpKeyFunction=
    _promptDownKeyFunction=
    _promptLeftKeyFunction=
    _promptRightKeyFunction=
    _promptSuccessFunction=

    # Set internal state defaults

    _prompt=
    _promptHint=
    _promptInput=
    _promptRow=
    _promptCol=
    _promptTimeoutCheckCount=0
    _promptChoicesCursor=
    _promptDoNotColorChoices=0
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
            --init) shift; _promptInitFunction="$1" ;;
            --paint) shift; _promptPaintFunction="$1" ;;
            --success) shift; _promptSuccessFunction="$1" ;;
            --result) shift; _promptResultVarName="$1" ;;
            --reserveRows) shift; _promptReserveRows="$1" ;;
            --up) shift; _promptUpKeyFunction="$1" ;;
            --down) shift; _promptDownKeyFunction="$1" ;;
            --left) shift; _promptLeftKeyFunction="$1" ;;
            --right) shift; _promptRightKeyFunction="$1" ;;
            --timeout) shift; _promptTimeoutSeconds="$1" ;;
            --startIndex) shift; _promptChoiceIndex="$1" ;;
            --choices) shift; _promptChoicesVarName="$1" ;;
            --numberChoices) _promptNumberChoices=1  ;;
            --doNotColorChoices) _promptDoNotColorChoices=1 ;;
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

    # Prepare and execute

    _preparePrompt
    _executePrompt
}

_preparePrompt() {

    # Initialize/show hint and prompt

    _promptHint="${_promptHintSpace}${ show -n muted italic "[${_promptPlainHint}]" ;}"
    _prompt="${ show -n bold success "?" plain bold "${_promptPlain}" ;}${_promptHint} "
    echo -n "${_prompt}"

    # Reserve rows below prompt and set prompt row/col

    reserveRows "${_promptReserveRows}"
    _promptRow=${_cursorRow}
    _promptCol=$(( ${#_promptPlain} + 4 )) # exclude hint, include prefix & trailing space

    # Move the cursor before the hint if it is supposed to be overwritten

    (( _promptClearHint )) && cursorToColumn "${_promptCol}"

    # Do we have choices?

    if [[ -n ${_promptChoicesVarName} ]]; then

        # Yes, hide the cursor, prepare choices and set start row

        cursorHide
        _preparePromptChoices
        _promptChoicesStartRow=$(( _promptRow + 2 )) # ignored in confirm()

    elif (( _promptEcho == 0 )); then

        # No, but we are hiding the input so hide the cursor

        cursorHide
    fi

    # Call init function if provided

    [[ -n ${_promptInitFunction} ]] && "${_promptInitFunction}"

    # Call paint if function is set

    [[ -n ${_promptPaintFunction} ]] && "${_promptPaintFunction}"
}

_preparePromptChoices() {
    local -n choicesRef="${_promptChoicesVarName}"
    _promptChoices=("${choicesRef[@]}")
    _promptMaxChoicesIndex=$(( ${#_promptChoices[@]} - 1 ))
    _promptChoicesCursor="${ show bold '>'; }"

    # Set reserve rows if not set already

    (( ! _promptReserveRows )) && _promptReserveRows=$(( _promptMaxChoicesIndex + 3 ))

    # Were we explicitly told not to color choices?

    if (( _promptDoNotColorChoices )); then

        _promptDisplayChoices=("${_promptChoices[@]}")
        _promptSuccessColor='primary'

    elif containsAnsi "${_promptChoices[0]}"; then

        # No but they are already colored, so don't color the display choices or the finalized prompt

        _promptDisplayChoices=("${_promptChoices[@]}")
        _promptSuccessColor=''

    else

        # No, so color the display choices and the finalized prompt

        for (( i=0; i <= _promptMaxChoicesIndex; i++  )); do
            _promptDisplayChoices[$i]="${ show primary "${_promptChoices[$i]}"; }"
        done
        _promptSuccessColor='primary'
    fi

    # Number the choices if we are supposed to

    if (( _promptNumberChoices && _promptMaxChoicesIndex )); then
        local number
        local places=${ numericPlaces $(( _promptMaxChoicesIndex + 1 )) 1; }
        for (( i=0; i <= _promptMaxChoicesIndex; i++ )); do
            number="${ printNumber $(( $i +1 )) ${places} ; }"
            _promptDisplayChoices[$i]="${ show dim "${number}." plain "${_promptDisplayChoices[${i}]}"; }"
        done
    fi
}

_executePrompt() {
    SECONDS=0 # Reset seconds counter
    stty cbreak -echo

    while true; do
        if IFS= read -t 0.1 -r -n1 key 2> /dev/null; then
            (( _promptClearHint )) && _clearHint

            case "${key}" in
                '' | $'\n' | $'\r') # Enter
                    if ((_promptCancelOnEmpty)) && [[ -z "${_promptInput// /}" ]]; then
                        _finalizePrompt _promptCanceledMsgEmpty italic warning
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
                    _finalizePrompt _promptCanceledMsgEsc italic warning
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
    _promptClearHint=0
    cursorToColumnAndEraseToEndOfLine ${_promptCol}
}

_hasPromptTimerExpired() {
    if (( ++_promptTimeoutCheckCount >= 10 )); then
        if (( SECONDS >= _promptTimeoutSeconds)); then
            _finalizePrompt _promptCanceledMsgTimeout italic warning
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
    local messageVarName="${1}"
    local formats=("${@:2}")
    local -n resultMessageRef="${messageVarName}"
    local isError isSecure
    local column=${_promptCol}

    if [[ ${messageVarName} =~ _promptCancel ]]; then
        isError=1
        isSecure=0 # Force it so we overwrite hint and echo error msg
    else
        isError=0
        isSecure=${ (( _promptEcho )) && echo 0 || echo 1; }
    fi

    # If this was hidden input, we want to keep the hint.
    # Reposition cursor to after the prompt/hint and save it.

    (( isSecure )) && (( column += ( ${#_promptPlainHint} + 2 ) ))
    cursorTo ${_promptRow} ${column}
    cursorSave

    # Clear any text after the prompt

    eraseToEndOfLine
    if (( _promptMaxChoicesIndex )); then
        cursorDownOneAndEraseLine
        for (( i=0; i <= _promptMaxChoicesIndex; i++ )); do
            cursorDownOneAndEraseLine
        done
    fi

    # Restore cursor and show result message if not hidden

    cursorRestore
    (( ! isSecure )) && show "${formats[@]}" "${resultMessageRef}" || echo

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
