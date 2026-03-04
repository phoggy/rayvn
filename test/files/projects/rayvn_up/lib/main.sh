#!/usr/bin/env bash

# Test library.
# Use via: require 'rayvn-up/main'

testMainLibraryFunction () {
    _testMainPrivateFunction
}

_init_function_rayvn_up_main() {
    require 'rayvn/core' # Add other required library names here.
    echo "library init_function_rayvn_up_main() called"
}

_testMainPrivateFunction() {
    show bold "_testMainPrivateFunction here!"
}

