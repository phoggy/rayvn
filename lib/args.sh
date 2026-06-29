#!/usr/bin/env bash

# Command parsing.
# Use via: require 'rayvn/args'


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

# TODO: add function to generate a parseArgs() function that has *filled* locals for spec vars and can be pasted in to script!
#        prompt at rayvn new for parser style
#
#        Arg Parser Styles
#
#        local (imperative)
#        shared (declarative: args spec)
#        shared CLI (declarative: cmd spec)
#
#        Local template parse function uses parseCommonArgs.
#
#        Canonical spec name in init()
#
#        declare -gr _argSpec OR
#        declare -gAr _cmdSpec
#
#
#        rayvn args PATH: gen/regen
#
#
#        Gen cmd handler funcs if missing, add TODO for remove or update existing and list them in output
#
#        Gen per cmd parser funcs, in own section:
#
#        _parseFooArgs() {
#            locals for all spec state
#            parseArguments spec
#        }
#
#        For non CLI
#
#        _parseArgs() {
#            locals for all spec state
#            parseArguments spec
#        }
#
#        To track changes, gen/regen _isParserStale() function with local SHA(s). Map for cmd, constant for script.



# ◇ Parse argument specification and arguments
#
# · ARGS
#
#   argsSpec (arrayRef)     Arguments specification.
#   args (array)            The arguments to parse.

parseSpecAndArguments() {
 declare -p _typeValidators
    declare -gA _optionNames    # Can be in a parse stub
    declare -gA _optionTypes    # Can be in a parse stub
    declare -ga _argumentTypes  # Can be in a parse stub

    _parseArgumentSpec "$1"; shift
    _parseArguments "$@"
}



PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/args' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_args() {
    declare -gAr _typeValidators=( ['str']='any' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
                                   ['file']=assertFile ['dir']=assertDirectory )
    declare -gA _parsedOptions
    declare -ga _parsedArguments
}

_parseArgumentSpec() {
    local -n _specRef="$1"
 echo; echo "PARSING SPEC: ${_specRef[*]}"; echo
    local _spec _type _argIndex=0
    _optionNames=()
    _optionTypes=()
    _argumentTypes=()

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
            _optionNames+=([${option}]="${option}")
            [[ -n ${alias} ]] && _optionNames+=([${alias}]="${option}")

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

    set +x; echo "DONE PARSING SPEC"; echo
    declare -p _optionNames _optionTypes _argumentTypes
}

_isKnownType() {
    local validator="${_typeValidators[${_type}]}"
    [[ -n ${validator} ]] || invalidArgs "${_spec} has unknown type: ${_type}"
}

_parseArguments() {
    echo; echo "PARSING ARGS: $*"; echo
    declare -p _optionNames _optionTypes _argumentTypes

    local maxIndex=${#_argumentTypes[@]}
    local _anyArgIndex=1024
    _parsedOptions=()
    _parsedArguments=()

    local option type validator argIndex=0 value
    while (( $# > 0 )); do
        option=${_optionNames[$1]}
        if [[ -n ${option} ]]; then

            # Option or flag. Do we have a type?

            type="${_optionTypes[${option}]}"
            if [[ -n ${type} ]]; then

                # Yes, so option: validate the type of the arg and store it

                [[ -z "$2" || -n ${_optionNames[$2]} ]] && fail "missing value for ${option}"
                value=$2
                validator=${_typeValidators[${type}]}
                [[ ${validator} != 'any' ]] && ${validator} ${value}
                [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
                _parsedOptions+=([${option}]=${value})   # TODO: strip - prefix??
                shift 2

            else

                # No, it's a flag so just store it

                _parsedOptions+=([${option}]="")         # TODO: strip - prefix??
                shift
            fi

        elif (( argIndex < maxIndex )); then

            if (( argIndex < _anyArgIndex )); then

                # Typed argument so validate and store

                value=$1
                type=${_argumentTypes[${argIndex}]}
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
        else
            fail "unknown argument: $1"
        fi
    done

    set +x; echo; echo "DONE PARSING"; echo
    declare -p _parsedOptions _parsedArguments
}


