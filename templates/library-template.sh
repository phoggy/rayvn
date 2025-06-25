#!/usr/bin/env bash

# Library of common functions.
# Intended for use via: require ${qualifiedName}

require 'rayvn/core'

# TODO replace me!
my${libraryName}LibraryFunction () {
    _my${libraryName}PrivateFunction
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_${projectName}_${name}() {
    echo "library init_${projectName}_${name}() called"
}

# TODO remove/replace me!
_my${libraryName}PrivateFunction() {
    echo "$(ansi bold _my${libraryName}PrivateFunction here!)"
}

