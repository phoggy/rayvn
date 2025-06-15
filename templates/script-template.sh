#!/usr/bin/env bash

usage() {
    echo
    echo "$(ansi bold does, uh... $(ansi italic something))."
    echo
    echo "Usage: $(ansi bold ${scriptName}) <options>"
    echo
    echo "Options:"
    echo
    echo "    -h, --help        Print this help message and exit."
    echo "    -v                Print the version and exit."
    echo "    --version         Print the version with release date and exit."
    echo
    bye "${@}"
}

main() {
    init "${@}"
    doSomething
    ${libraryCall}
}

# shellcheck disable=SC2155
init() {
    declare -r scriptName=$(basename "${0}")

    while (( ${#} > 0 )); do
        case "${1}" in
            -h | --help) usage ;;
            -v) projectVersion ${quotedName}; exit 0 ;;
            --version) projectVersion ${quotedName} true; exit 0 ;;
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug noLog ;;
            *) usage "Unknown option: ${1}" ;;
        esac
        shift
    done

    # CHECK INPUTS
}

# TODO remove me!
doSomething() {
    echo "🌱 $(ansi bold_yellow doSomething here!) 🌱 "
}

source rayvn.up --add ${quotedName} 'rayvn/core' ${qualifiedName}

main "${@}"


