#!/usr/bin/env bash

# Library of common functions.
# Intended for use via: require ${qualifiedName}

# TODO replace me!
my${libraryName}LibraryFunction () {
    _my${libraryName}PrivateFunction
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN '${projectName}/${name}' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_${projectName}_${name}() {
    require 'rayvn/core' # Add other required library names here.
    echo "library init_${projectName}_${name}() called" # TODO remove/replace me!
}

# TODO remove/replace me!
_my${libraryName}PrivateFunction() {
    echo "$(ansi bold _my${libraryName}PrivateFunction here!)"
}

