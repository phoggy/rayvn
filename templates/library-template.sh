#!/usr/bin/env bash

# Library of common functions.
# Intended for use via: require ${qualifiedName}

# TODO replace me!
my${libraryNameInitialCap}LibraryFunction () {
    _my${libraryNameInitialCap}PrivateFunction
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN '${projectName}/${libraryName}' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_${projectName}_${libraryName}() {
    require 'rayvn/core' # Add other required library names here.
    echo "library init_${projectName}_${libraryName}() called" # TODO remove/replace me!
}

# TODO remove/replace me!
_my${libraryNameInitialCap}PrivateFunction() {
    echo "$(ansi bold _my${libraryNameInitialCap}PrivateFunction here!)"
}

