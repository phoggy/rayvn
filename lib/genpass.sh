#!/usr/bin/env bash

# Library supporting password/phrase generation
# Intended for use via: require 'core/genpass'

require 'core/base'

init_core_genpass() {
    declare -A dependencies=(

        [mrld_min]='0.1.0'
        [mrld_brew]=true
        [mrld_brew_tap]='phoggy/mrld'
        [mrld_install]='https://github.com/phoggy/mrld'
        [mrld_version]='versionExtract'
    )

    assertExecutables dependencies
}

readonly passphraseWordsFile="${rayvnRootDir}/etc/words.txt"     # TODO FIX: should point to sage/etc dir.

randomIndex() {
    local -i maxIndex="${1}"
    local -n resultInt=${2}
    local -i randomInt

    if [[ ! ${checkedDevUrandom} ]]; then
        declare -grx hasDevUrandom=$(ls /dev/urandom > /dev/null && echo -n 'true' || echo -n '')
        declare -grx checkedDevUrandom='true'
        if [[ ! ${hasDevUrandom} ]]; then
            warn "generated passwords/phrases *may* not be random enough: use ${webPasswordGenUrl}"
        fi
    fi
    if [[ ${hasDevUrandom} ]]; then
        randomInt=$(head -c4 /dev/urandom | od -An -tu4)
    else
        randomInt=${SRANDOM}
    fi
    resultInt=$(( ${randomInt} % ${maxIndex} ))
}

generatePassword() {
    local -i minLength="${1:-24}"
    local -i maxLength="${2:-32}"
    local -i passwordLength=$(( ${minLength} + ( ${RANDOM} % ( ${maxLength} - ${minLength} ) ) ))
    local charSet=( a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z \
                    0 1 2 3 4 5 6 7 8 9 '!' '@' '#' '$' '%' '^' '&' '*' )
    local -i charSetLen=${#charSet[@]}
    local -i i
    local -i index
    local password=''

    for (( i = 0; i < ${passwordLength}; i++ )); do
        randomIndex ${charSetLen} index
        password+=${charSet[${index}]}
    done
    echo "${password}"
}

# inhabit purely accuse lifts waiver
# lofty banners bites wonderful discard
# loaned germs shouting novel demise
# pests sutures levels unlimited steward
# longest boar mammary cruel pamphlet
# expects copies duff occasions trails
# forge manhood scant armored endocrine
# tier forte reminders fabrication fix
# doctorate seized peg pedagogy dental
# maiden refused adorned starring norms
# goals ecosystem dual decimal bachelor
# renewed hawks overtly widen shells
# component slab depending mad tenderly
# dwell killing biopsy coloration quasi
# dominions wired download wrong delete
# planet amply narrowed magical galaxy



generatePassphrase() {
    local -i wordCount="${1:-5}"
    local separator="${2:- }"
    local -i index
    local passphrase=''
    _ensureWordList

    for (( i = 0; i < ${wordCount}; i++ )); do
        randomIndex ${effLongWordListLen} index
        passphrase+=${effLongWordList[${index}]}
        (( i < ${wordCount}-1 )) && passphrase+=${separator}
    done
    echo "${passphrase}"
}

_ensureWordList() {
    if [[ ! ${effLongWordList} ]]; then
        local list
        local hash=
        local shasumArg=
        if echo "test" | shasum -U &> /dev/null; then
            shasumArg='-U'
        elif echo "test" | shasum -p &> /dev/null; then
            shasumArg='-p'
        else
            warn "cannot verify wordlist: use ${webPasswordGenUrl}"
        fi
        if [[ ${shasumArg} ]]; then
            local hash=$(shasum -a 256 ${shasumArg} "${passphraseWordsFile}" | cut -d' ' -f1)
            if [[ ${hash} != '7b8ddbd2d364b3824d52e4d1f658ee1f6e16f67bd1f361249170b1644ec90442' ]]; then
                fail "word list has been tampered with!"
            fi
        fi
        readarray -s 1 -t list < "${passphraseWordsFile}" || fail
        declare -grx effLongWordList=( "${list[@]}" )
        declare -grxi effLongWordListLen=${#effLongWordList[@]}
        if (( ${effLongWordListLen} != 7776 )); then
            fail "word list has been tampered with!"
        fi
    fi
}
