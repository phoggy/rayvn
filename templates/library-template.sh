#!/usr/bin/env bash

# Library of common functions.
# Intended for use via: require ${qualifiedName}

require 'rayvn/core'

# TODO replace me!
myCoreLibraryFunction () {
    _myPrivateFunction
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

# TODO remove/replace me!
_myPrivateFunction() {
    echo "$(ansi bold _myPrivateFunction here!)"
}

