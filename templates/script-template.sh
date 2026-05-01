#!/usr/bin/env rayvn-bash
# shellcheck shell=bash

usage() {
    echo
    show bold "does" italic "something" glue "."
    echo
    show "Usage:" bold "${scriptName}" "[options]"
    echo
    echo "Options:"
    echo
    commonOptions 21 true # description column, show debug options
    bye "$@"
}

main() {
    init "$@"
    doSomething
    ${libraryCall}
}

# shellcheck disable=SC2155
init() {
    while (( $# )); do
        case "$1" in
            -h | --help) usage ;;
            -v) projectVersion ${quotedName}; exit 0 ;;
            --version) projectVersion ${quotedName} true; exit 0 ;;
            --debug*) setDebug "$@"; shift $? ;;
            *) usage "Unknown option: $1" ;;
        esac
        shift
    done

    # CHECK INPUTS
}

# TODO remove me!
doSomething() {
    show "🌱" bold yellow "doSomething here!" "🌱"
}

source rayvn.up  ${qualifiedName} || exit
main "$@"


