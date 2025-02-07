#!/usr/bin/env bash

# Library supporting password/phrase input
# Intended for use via: require 'core/readpass'

require 'core/base'
require 'core/pwned'

init_core_readpass() {
    declare -A dependencies=(

        [mrld_min]='0.1.0'
        [mrld_brew]=true
        [mrld_brew_tap]='phoggy/mrld'
        [mrld_install]='https://github.com/phoggy/mrld'
        [mrld_version]='versionExtract'
    )

    assertExecutables dependencies
}

readVerifiedPassword() {
    local p1 p2
    local -n resultVar="${1}"
    local timeout="${2:-30}"
    readPassword "Password" p1 "${timeout}" true || fail
    [[ ${p1} == '' ]] && fail "cancelled"
    readPassword "  Verify" p2 "${timeout}" false || fail
    [[ ${p1} == "${p2}" ]] || fail "entries do not match"
    resultVar="${p1}"
}

readPassword() {
    local result count=0 mask key
    local prompt="$(ansi cyan "${1}: ")"
    local -n resultVar="${2}"
    local timeout="${3:-30}"
    local checkResult="${4:-true}"
    local cancelled=
    local visible=true
    local show=true
    local score=
    local pwned=
    resultVar=''

    case ${passwordVisibility} in
        none) unset visible show; prompt="$(ansi cyan "${1}") $(ansi dim [hidden]) " ;;
        hide) unset show ;;
        show) show=true ;;
        *) fail "unknown visibility mode: ${passwordVisibility}"
    esac

    # Prompt and disable typing echo on the terminal

    echo -n "${prompt}" > ${terminal}

    # Process one character at a time

    while :; do
        [[ ${visible} ]] && echo -n "${mask}" > ${terminal}
        IFS= read -s -n 1 -t ${timeout} key < ${terminal}

        if (( $? >= 128  )); then                # timeout
            cancelled=true
            break
        elif [[ ${key} =~ [[:print:]] ]]; then   # valid character
            count=$((count+1))
            [[ ${show} ]] && mask=${key} || mask='*'
            result+=${key}
        elif [[ ${key} == $'\177' ]]; then       # backspace
            if (( ${count} > 0 )); then
                count=$((count-1))
                mask=$'\b \b'
                result="${result%?}"
            else
                mask=''
            fi
        elif [[ ${key} == $'\e' ]] ; then        # ESC
            cancelled=true;
            break
        elif [[ ${key} == '' ]] ; then           # enter
            break
        fi
    done

    # Mask password if we did not do so above

    if [[ ${show} ]]; then
        printRepeat $'\b' ${count}
        printRepeat '*' ${count}
    fi

    [[ ${result} == '' ]] && cancelled=true

    if [[ ! ${cancelled} ]]; then

        # Check result if requested

        if [[ ${checkResult} == true ]]; then
            IFS=',' read -r -a score <<< "$(echo "${result}" | mrld -t)"
            echo -n "  ⮕  ${score[0]} (${score[1]}/4), ${score[2]} to crack" > ${terminal}
            hasNotBeenPwned "${result}"; pwned=${?}
        fi
    fi
    print # complete the line

    # Return the result if not cancelled and not pwned

#print "pwned: ${pwned}, expertMode: ${expertMode}"
    if [[ ! ${cancelled} ]]; then
        if [[ ${pwned} == 1 ]]; then
            warn "Could not check if this password/phrase has been breached!"
            if [[ ${expertMode} ]]; then
                resultVar="${result}"
            fi
        elif [[ ${pwned} == 2 ]]; then
            error "This password/phrase is present in a large set of breached passwords so is not safe to use!"
        else
            resultVar="${result}"
        fi
    fi
}


# TODO: buggy , probably timing issues due to cost of external mrld command fork.
#       Fix, implement in rust, or remove.
#readPasswordLiveScore() {
#    local result count=0 mask key
#    local prompt="$(ansi cyan "${1}: ")"
#    local -n resultVar="${2}"
#    local visibility="${3:-none}"
#    local timeout="${4:-30}"
#    local score="${5}"
#    local cancelled=
#    local visible=true
#    local show=true
#    local cursorPosition
#    local estimateRow
#    local estimateColumn
#    local estimateOffset=20
#    local estimate
#    resultVar=''
#
#    case ${visibility} in
#        none) unset visible show ;;
#        hide) unset show ;;
#        show) show=true ;;
#        *) fail "unknown visibility mode: ${visibility}"
#    esac
#
#    # Prompt and disable typing echo on the terminal
#
#    echo -n "${prompt}" > ${terminal}
#
#    # Capture the cursor position and compute estimate row and column
#
#    if [[ ${score} ]]; then
#        cursorPosition=$(cursorPosition) # row;col format
#        estimateRow=$(( ${cursorPosition%;*} + 1 ))
#        estimateColumn=$(( ${cursorPosition#*;} + ${estimateOffset} ))
#    fi
#
#    # Process one character at a time
#
#    while :; do
#        if [[ ${score} && ${result} != '' ]]; then
#            tput civis # hide cursor
#            estimate=$(echo "${result}" | mrld)
#            if [[ ${show} ]]; then
#                if (( ${#result} > ${estimateOffset} - 1 )); then
#                    estimateOffset=$((${estimateOffset} + 10))
#                    estimateColumn=$((${estimateColumn} + 10))
#                    tput el # erase to end of line
#                fi
#            fi
#            tput sc    # save cursor
#            tput cup ${estimateRow} ${estimateColumn}
#            echo -n "  ⮕  ${estimate}"
#            tput el    # erase to end of line
#            tput rc    # restore cursor
#            tput cnorm # show cursor
#        fi
#
#        [[ ${visible} ]] && echo -n "${mask}" > ${terminal}
#        IFS= read -s -n 1 -t ${timeout} key < ${terminal}
#
#        if (( $? >= 128  )); then                # timeout
#            cancelled=true
#            break
#        elif [[ ${key} =~ [[:print:]] ]]; then   # valid character
#            count=$((count+1))
#            [[ ${show} ]] && mask=${key} || mask='*'
#            result+=${key}
#        elif [[ ${key} == $'\177' ]]; then       # backspace
#            if (( ${count} > 0 )); then
#                count=$((count-1))
#                mask=$'\b \b'
#                result="${result%?}"
#            else
#                mask=''
#            fi
#        elif [[ ${key} == $'\e' ]] ; then        # ESC
#            cancelled=true;
#            break
#        elif [[ ${key} == '' ]] ; then           # enter
#            break
#        fi
#    done
#
#    # Mask password if we did not do so above
#
#    if [[ ${show} ]]; then
#        printRepeat $'\b' ${count}
#        printRepeat '*' ${count}
#    fi
#
#    # Clear any remaining estimate
#
#    tput el
#
#    # Send a newline and return the result if not cancelled
#
#    print
#    [[ ! ${cancelled} ]] && resultVar="${result}"
#}

describe() {
    print "${@}"
    print
}

mismatchError() {
    local error="${1}"
    local remaining=${2}
    local retries='retries'
    (( ${remaining} == 1 )) && retries='retry'
    print "$(ansi red "${error}") (${remaining} ${retries} remain)"
    print
}
