#!/usr/bin/env bash

# Library of common functions.
# Intended for use via: require 'rayvn-up/main'

testMainLibraryFunction () {
    _testMainPrivateFunction
}

_init_function_rayvn_up_main() {
    require 'rayvn/core' # Add other required library names here.
    echo "library init_function_rayvn_up_main() called"
}

_testMainPrivateFunction() {
    echo "$(ansi bold _testMainPrivateFunction here!)"
}

