#!/usr/bin/env bash

# Library supporting password/phrase input
# Intended for use via: require 'rayvn/readpass'

require 'rayvn/core'
require 'rayvn/pwned'

init_rayvn_readpass() {
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
