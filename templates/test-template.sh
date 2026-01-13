#!/usr/bin/env bash

main() {
    init "$@"

    testFoo
    testBar

    return 0
}

init() {

    # Process args

    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${terminal}" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done

    # TODO other initialization here
}

# TODO replace me!
testFoo() {
    assertNotEqual "foo" "bar" # See rayvn/lib/test.sh for more
}

# TODO remove/replace me!
testBar() {
    assertEqualIgnoreCase "bar" "Bar"
}

source rayvn.up 'rayvn/test'
main "$@"
