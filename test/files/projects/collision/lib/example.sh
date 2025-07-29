#!/usr/bin/env bash

# Library of common functions.
# Intended for use via: require 'function_collision/example'

myExampleLibraryFunction () {
    _myExamplePrivateFunction
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'function_collision/example' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_function_collision_example() {
    require 'rayvn/core' # Add other required library names here.
    echo "library init_function_collision_example() called"
}

_myExamplePrivateFunction() {
    echo "$(ansi bold _myExamplePrivateFunction here!)"
}

