#!/usr/bin/env bash

# Library supporting age file encryption via rage
# Intended for use via: require 'rayvn/age'

require 'rayvn/core'

init_rayvn_age() {
    declare -A dependencies=(

        [rage_min]='0.11.1'
        [rage_brew]=true
        [rage_brew_tap]='str4d.xyz/rage https://str4d.xyz/rage'
        [rage_install]='https://github.com/str4d/rage'
        [rage_version]='versionExtract'
    )

    assertExecutables dependencies
}

readonly ageFileExtension='age'
readonly tarFileExtension='tar.xz'

showAgeKeyPairAdvice() {
    echo "Your new private key will be encrypted. You will be prompted to enter a 'passphrase', twice, and it is very"
    echo "important that you use a strong one. The following are examples of passwords and passphrases, with estimated"
    echo "times to crack using modern systems:"
    echo
    echo "   $(ansi bold_cyan My dog Oscar)                    ⮕  $(ansi bold_green easy) to remember $(ansi red non-random) & $(ansi red short):  6 days to crack"
    echo "   $(ansi bold_cyan 'BkZB&XWGj%3Tx')                   ⮕  $(ansi bold_red hard) to remember random password:     31 years to crack"
    echo "   $(ansi bold_cyan repossess thursday flaky lazy)   ⮕  $(ansi bold fair) to remember random passphrase:   centuries to crack"
    echo
    echo "   See $(ansi blue ${webPasswordGenUrl}) to generate and/or test strength of either type."
    echo "   See $(ansi blue "${webHaveIBeenPwnedUrl}") to check if a password/phrase has leaked in a breach."
    echo
    echo "Choosing a good passphrase requires randomness, and we humans are very bad at that. There's a famous $(ansi magenta xkcd)"
    echo "comic on this subject ($(ansi blue ${webXkcdPasswordsUrl})) that ends with this:"
    echo
    echo "    \"Through 20 years of effort, we've successfully trained everyone to use passwords that"
    echo "     are hard for humans to remember, but easy for computers to guess.\""
    echo "                                                                           — Randall Munroe"
    echo
    echo "That comic makes another important point in the last cell: creating a mental scene to represent your"
    echo "passphrase is an excellent way to help remember it."
    echo
    echo "Please use a $(ansi bold_green strong) passphrase, preferably generated. When you enter it below, a srayvn will be shown"
    echo "so you can see the strength of your passphrase."
    echo
}

createAgeKeyPair() {
    useRayvnPinEntry
    local keyFile="${1}"
    local publicKeyFile="${2}"
    local key=$(rage-keygen 2> /dev/null)
    local publicKey=$(echo "${key}" | grep "public key: age1" | awk '{print $NF}')
    [[ -f ${keyFile} ]] && fail "${keyFile} should have been deleted!"

    echo "${key}" | rage -p -o "${keyFile}" -
    [[ -f ${keyFile} ]] || fail "canceled"
    echo "${publicKey}" > "${publicKeyFile}"
    unset key
    disableRayvnPinEntry
}

verifyAgeKeyPair() {
    local sampleText
    local keyFile="${1}"
    local publicKeyFile="${2}"
    local tempEncryptedFile=$(tempDirPath sample.age)
    useRayvnPinEntry

    setSampleText sampleText
    echo -n "${sampleText}" | rage -R "${publicKeyFile}" -o "${tempEncryptedFile}" || fail
    local decrypted=$(rage -d -i "${keyFile}" "${tempEncryptedFile}" 2> /dev/null)
    diff -u <(echo -n "${sampleText}") <(echo "${decrypted}") > /dev/null || fail "not verified (wrong passphrase?)"
    disableRayvnPinEntry
}

armorAgeFile() {
    local ageFile="${1}"
    local -n resultVar="${2}"
    local header=$(head -n 1 "${ageFile}")
    if [[ ${header} =~ ^age-encryption.org/v ]]; then
        # $'x' is bash magic for mapping escaped characters
        local result=$'-----BEGIN AGE ENCRYPTED FILE-----\n'
        result+="$(cat "${ageFile}" | base64 -b 65)"
        result+=$'\n'
        result+=$'-----END AGE ENCRYPTED FILE-----\n'
        resultVar=${result}
    else
        fail "${ageFile} does not appear to be an age encrypted file"
    fi
}

setSampleText() {
    local -n resultVar="${1}"
    if [[ ! ${resultVar} ]]; then
        IFS='' read -d '' -r resultVar <<'HEREDOC'
                                🌑🌒🌓🌔🌕🌖🌗🌘

            But the Raven, sitting lonely on the placid bust, spoke only
        That one word, as if his soul in that one word he did outpour.
            Nothing farther then he uttered—not a feather then he fluttered—
            Till I scarcely more than muttered “Other friends have flown before—
        On the morrow he will leave me, as my Hopes have flown before.”
                         Then the bird said “Nevermore.”

                                🌑🌒🌓🌔🌕🌖🌗🌘
HEREDOC
    fi
}

version() {
    echo "${1} {$(rage --version)}"
    bye
}
