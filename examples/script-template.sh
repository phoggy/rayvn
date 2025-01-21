#!/usr/bin/env bash

readonly VERSION='SOMETHING 0.0.0'

usage() {
    echo
    echo "$(ansi bold SOMETHING)."
    echo
    echo "DESCRIPTION".
    echo
    echo "Usage: $(ansi bold ${scriptName}) <options> WHATEVER"
    echo
    echo "Options:"
    echo
    echo "    -h, --help                       Display usage and exit."
    echo "    --version                        Display version and exit."
    echo
    bye "${@}"
}

main() {
    init "${@}"
    doSomething
}

init() {
    assertBashVersion
    readonly scriptName=$(basename "${0}")

    while (( ${#} > 0 )); do
        case "${1}" in
            -h | --help) usage ;;
            --version) version ${VERSION} ;;
            -*) usage "Unknown option: ${1}" ;;
            *) addFile "${1}"
        esac
        shift
    done

    # CHECK INPUTS
}

doSomething() {
    echo "🌱 $(ansi bold_yellow SOMETHING) 🌱 "
}

source "${HOME}/.rayvn/boot.sh" 2> /dev/null || { echo 'rayvn not installed' && exit 0; }
require 'core/base'
main "${@}"


