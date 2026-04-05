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
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    # TODO add other initialization here
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
