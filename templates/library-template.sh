#!/usr/bin/env bash

# My library.
# Intended for use via: require ${qualifiedName}

# IMPORTANT: Any output when sourcing libraries is treated as an error. This is required since
#            parse/definition time errors (e.g. syntax) rarely result in a non-zero exit code,
#            even with -e set. Combined with the lack of a clearly identifiable pattern in error
#            messages means that rayvn cannot distinguish between true errors and normal output.
#
#            Top level code (i.e. code not in a function) is therefore strongly discouraged, and
#            any initialization code should be confined to _init_${project}_${library} functions
#            where normal error handling can occur.

# TODO replace me!
my${libraryNameInitialCap}LibraryFunction() {
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

