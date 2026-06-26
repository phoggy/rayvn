#!/usr/bin/env bash

# Command parsing.
# Use via: require 'rayvn/command'


# Argument Specification
#
# An argument spec is a string declaring named/typed options (e.g. --count 5 --file /etc/passwd), named/boolean flags (e.g. -f)
# and typed or untyped positional arguments. Parsed options and flags are accessed by name, arguments by position.
#
# The * wildcard positional argument allows any number of untyped values to follow. This is intended to support cases like
# that of tar args with -C dir interspersed and requires the caller to validate them.
#
#      type: str | int | +int | bool | file | dir
#    option: --name[|alias]:type                    TODO: multiple aliases??
#      flag: --name[|alias]
#      spec: [option | flag | type]... [*]
#        fn: fnName( spec )
#
# The int type accepts both positive and negative values; use the +int type to accept only positive integers.
#
# The bool type accepts true|1 false|0 as input and maps it to 1 or 0 for simpler tests (( myFlag )). Flags are
# implicitly bool.
#
# Options and flags accept optional names as aliases; each must be prefixed with one or more '-'.
#
# An empty spec means no arguments are allowed. A "*" in a spec must be the last item and means that all remaining
# arguments are allowed and are untyped.
#
# Functions are accepted only for the command pattern.


# ◇ Parse arguments
#
# · ARGS
#
#   argsSpec (arrayRef)  Arguments specification.
#   args (array)         The arguments

parseArguments() {
    _optionNames=()
    _optionTypes=()
    _aliases=()
    _argumentTypes=()
    _anyArgIndex=1024
    _parsedOptions=()
    _parsedArguments=()

echo; echo "PARSING SPEC: $*"; echo
    _parseArgumentSpec "$1"; shift
    declare -p _optionNames _optionTypes _aliases _argumentTypes _anyArgIndex
 echo; echo "PARSING: $*"; echo
    local option type validator argIndex=0 alias value
    while (( $# > 0 )); do
        if [[ $1 == -* && -v _optionNames[$1] ]]; then

            # Option or flag. First get the type, checking alias if needed.

            option=$1
            type="${_optionTypes[${option}]}"
            if [[ -z  ${type} ]]; then
                alias=${_aliases[${option}]}
                if [[ -n ${alias} ]]; then
                    option=${alias}
                    type="${_optionTypes[${option}]}"
                fi
            fi

            # Do we have a type?

            if [[ -n ${type} ]]; then

                # Yes, so option: validate the type of the arg and store it

                value=$1
                validator=${_typeValidators[${type}]}
                [[ ${validator} != 'any' ]] && ${validator} ${value}
                [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
                _parsedOptions+=([${option}]=${value})
                shift 2

            else

                # No, it's a flag so just store it

                _parsedOptions+=([${option}]="")
                shift
            fi

        elif (( argIndex < _anyArgIndex )); then

            # Typed argument so validate and store

            value=$1
            type=${_argumentTypes[argIndex]}
            validator=${_typeValidators[${type}]}
            [[ ${validator} != 'any' ]] && ${validator} ${value}
            [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
            _parsedArguments+=("${value}")
            (( argIndex++ ))
            shift

        else

            # Untyped argument, just store it

            _parsedArguments+=("$1")
            (( argIndex++ ))
            shift
        fi
    done

    set +x; echo "DONE PARSING"
    declare -p _parsedOptions _parsedArguments

}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/command' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_command() {
    declare -gAr _typeValidators=( ['str']='any' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
                                   ['file']=assertFile ['dir']=assertDirectory )
    declare -gA _optionNames
    declare -gA _optionTypes
    declare -gA _aliases
    declare -ga _argumentTypes
    declare -g _anyArgIndex
    declare -gA _parsedOptions
    declare -ga _parsedArguments
}

_parseArgumentSpec() {
    local -n _specRef="$1"
    local _spec _type _argIndex=0
    for _spec in "${_specRef[@]}"; do
        if [[ ${_spec} == -* ]]; then

            # option or flag

            local options="${_spec%:*}"
            local option=${options%|*}
            local alias=; [[ ${options} == *\|* ]] && alias="${options##*|}"
            if [[ ${_spec} == *:* ]]; then
                _type="${_spec##*:}"
                _isKnownType
                _optionTypes+=([${option}]=${_type})
            fi
            _optionNames+=([${option}]='')
            if [[ -n ${alias} ]]; then
                _aliases+=([${alias}]=${option})      # TODO get rid of alias map, just use _optionNames by
                _optionNames+=([${alias}]='')         #      setting value to option!
            fi

        else

            # argument

            _type="${_spec}"
            if [[ ${_type} == '*' ]]; then
                _anyArgIndex="${#_argumentTypes[@]}"
            elif (( _argIndex < _anyArgIndex )); then
                _isKnownType
                _argumentTypes+=("${_type}")
            fi
            (( _argIndex++ ))
        fi
    done
}

_isKnownType() {
    local validator="${_typeValidators[${_type}]}"
    [[ -n ${validator} ]] || invalidArgs "${_spec} has unknown type: ${_type}"
}

