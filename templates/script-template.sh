#!/usr/bin/env bash

usage() {
    echo
    show bold "does, uh..." plain italic "something" plain "."
    echo
    show "Usage:" bold "${scriptName}" plain "<options>"
    echo
    echo "Options:"
    echo
    echo "    -h, --help        Print this help message and exit."
    echo "    -v                Print the version and exit."
    echo "    --version         Print the version with release date and exit."
    echo
    echo "Debug Options:"
    echo
    echo "    --debug           Enable debug logging, show on exit"
    echo "    --debug-new       Enable debug logging with cleared log, show on exit"
    echo "    --debug-out       Send debug output to current terminal"
    echo "    --debug-tty TTY   Send debug output to specific terminal (e.g., /dev/ttys001)"
    echo "    --debug-tty .     Read tty path from \${HOME}/.debug.tty file"
    echo
    bye "$@"
}

main() {
    init "$@"
    doSomething
    ${libraryCall}
}

# shellcheck disable=SC2155
init() {
    declare -r scriptName="${0##*/}"

    while (( $# )); do
        case "${1}" in
            -h | --help) usage ;;
            -v) projectVersion ${quotedName}; exit 0 ;;
            --version) projectVersion ${quotedName} true; exit 0 ;;
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${ tty; }" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
            *) usage "Unknown option: ${1}" ;;
        esac
        shift
    done

    # CHECK INPUTS
}

# TODO remove me!
doSomething() {
    show "🌱" bold yellow "doSomething here!" plain "🌱"
}

source rayvn.up --add ${quotedName} 'rayvn/core' ${qualifiedName} || exit
main "$@"


