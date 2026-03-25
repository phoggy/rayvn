#!/usr/bin/env rayvn-bash
# shellcheck shell=bash

usage() {
    echo
    show bold "does, uh..." off italic "something" off "."
    echo
    show "Usage:" bold "${scriptName}" off "<options>"
    echo
    echo "Options:"
    echo
    echo "    -h, --help        Print this help message and exit."
    echo "    -v                Print the version and exit."
    echo "    --version         Print the version with release date and exit."
    echo
    echo "Debug Options:"
    echo
    echo "    --debug           Enable debug, write output to log file and show on exit."
    echo "    --debug-new       Enable debug, clear log file, write output to log file and show on exit."
    echo "    --debug-out       Enable debug, write output to the current terminal."
    echo "    --debug-tty TTY   Enable debug, write output to the specified TTY (e.g., /dev/ttys001)."
    echo "    --debug-tty .     Enable debug, write output to the TTY path read from the '${HOME}/.debug.tty' file."
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
        case "$1" in
            -h | --help) usage ;;
            -v) projectVersion ${quotedName}; exit 0 ;;
            --version) projectVersion ${quotedName} true; exit 0 ;;
            --debug) setDebug --showLogOnExit ;;
            --debug-new) setDebug --clearLog --showLogOnExit ;;
            --debug-out) setDebug --tty "${ tty; }" ;;
            --debug-tty) shift; setDebug --tty "$1" ;;
            *) usage "Unknown option: $1" ;;
        esac
        shift
    done

    # CHECK INPUTS
}

# TODO remove me!
doSomething() {
    show "🌱" bold yellow "doSomething here!" off "🌱"
}

source rayvn.up 'rayvn/core' ${qualifiedName} || exit
main "$@"


