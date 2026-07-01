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
# Options and flags accept an optional name as alias and each must be prefixed with one or more '-'.
#
# An empty spec means no arguments are allowed. A "*" in a spec must be the last item and means that all remaining
# arguments are allowed and are untyped.
#
# Type checking is performed via a map of types to a type check function (single arg). A '*' type is unchecked. The default
# map is:
#
#    declare -gAr _argsDefaultTypeMap=( ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
#                                       ['file']=assertFile ['dir']=assertDirectory )
#
# Custom types can be supported by creating a custom map and setting argsTypeMap to the name of the custom map var:
#
#    declare -gAr myTypeMap=( ['str']=assertMyString ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
#                             ['file']=assertFile ['dir']=assertDirectory )
#    argsTypeMap=myTypeMap
#
#    assertMyString() {
#       (( ${#1} > 3 )) || fail "$1 must be 4 characters or longer" # or whatever
#    }
#
# Function specs are accepted only for the command pattern.

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
#        Add: rayvn args SCRIPT_PATH: gen/regen
#
#
#        Gen cmd handler funcs if missing, add TODO for remove or update existing and list them in output
#
#        Gen per cmd parser funcs, in own section:
#
#        _parseFooArgs() {
#            declare -Ar _argsOptionNames=([--count]="--count" [-f]="--force" [-n]="--name" [--name]="--name" [--force]="--force" )
#            declare -Ar _argsOptionTypes=([--count]="+int" [--name]="str" )
#            declare -ar _argsArgumentTypes=([0]="bool" [1]="*")
#            parseArguments spec
#        }
#
#        For non CLI, just name function "_parseArgs"
#
#        To track changes, gen/regen _isParserStale() function with local SHA(s). Map for cmd, constant for script.


# ◇ Parse argument specifications. Assumes that the following variables are already available (usually in a generated stub):
#
#   declare -A _argsOptionNames
#   declare -A _argsOptionTypes
#   declare -a _argsArgumentTypes
#
# · ARGS
#
#   argsSpec (arrayRef)     Arguments specification.

parseArgumentSpec() {
    [[ -n $1 ]] || invalidArgs "arguments specification required"
    _parseArgumentSpec "$1"
}

genArgumentParser() {
    [[ -n $1 ]] || invalidArgs "arguments specification required"
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes
    _parseArgumentSpec "$1"
    {
        echo "_parseArgs() {"
        echo "    ${ declare -p _argsOptionNames; }"
        echo "    ${ declare -p _argsOptionTypes; }"
        echo "    ${ declare -p _argsArgumentTypes; }"
        echo '    _parseArguments "$@"'
        echo '}'
    }
}

# ◇ Parse argument specification and arguments.
#
# · ARGS
#
#   argsSpec (arrayRef)     Arguments specification.
#   args (array)            The arguments to parse.

parseSpecAndArguments() {
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes

    _parseArgumentSpec "$1"; shift
    _parseArguments "$@"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/args' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_args() {
    declare -gAr _argsDefaultTypeMap=( ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
                                       ['file']=assertFile ['dir']=assertDirectory )

    # User can set this to a custom type map
    declare -g argsTypeMap=_argsDefaultTypeMap # TODO document

    # Parse results
    declare -gA _argsParsedOptions
    declare -ga _argsParsedArguments
}

_parseArgumentSpec() {
    local -n _typeMap="${argsTypeMap}"
    local -n _specRef="$1"

#   echo; echo "PARSING SPEC: ${_specRef[*]}"; echo
    local _spec _type _argIndex=0 _starArgIndex=1024

    _argsOptionNames=()
    _argsOptionTypes=()
    _argsArgumentTypes=()

    for _spec in "${_specRef[@]}"; do
        if [[ ${_spec} == -* ]]; then

            # option or flag

            local options="${_spec%:*}"
            local option=${options%|*}
            local alias=; [[ ${options} == *\|* ]] && alias="${options##*|}"
            if [[ ${_spec} == *:* ]]; then
                _type="${_spec##*:}"
                _isKnownType
                _argsOptionTypes+=([${option}]=${_type})
            fi
            _argsOptionNames+=([${option}]="${option}")
            [[ -n ${alias} ]] && _argsOptionNames+=([${alias}]="${option}")

        else

            # argument

            _type="${_spec}"
            if [[ ${_type} == '*' ]]; then
                _starArgIndex="${#_argsArgumentTypes[@]}"
                _argsArgumentTypes+=("*")
            elif (( _argIndex < _starArgIndex )); then
                _isKnownType
                _argsArgumentTypes+=("${_type}")
            fi
            (( _argIndex++ ))
        fi
    done

  #  set +x; echo "DONE PARSING SPEC"; echo; declare -p _argsOptionNames _argsOptionTypes _argsArgumentTypes
}

_isKnownType() {
    local typeChecker="${_typeMap[${_type}]}"
    [[ -n ${typeChecker} ]] || invalidArgs "${_spec} has unknown type: ${_type}"
}

_parseArguments() {
    local -n _typeMap="${argsTypeMap}"
#    echo; echo "PARSING ARGS: $*"; echo; declare -p _typeMap _argsOptionNames _argsOptionTypes _argsArgumentTypes

    local maxIndex=${#_argsArgumentTypes[@]}
    local argIndex=0 typedArg=1
    local option type typeChecker value
    _argsParsedOptions=()
    _argsParsedArguments=()

    while (( $# > 0 )); do
        option=${_argsOptionNames[$1]}
        if [[ -n ${option} ]]; then

            # Option or flag. Do we have a type?

            type="${_argsOptionTypes[${option}]}"
            if [[ -n ${type} ]]; then

                # Yes, so option: validate the type of the arg and store it

                [[ -z "$2" || -n ${_argsOptionNames[$2]} ]] && fail "missing value for ${option}"
                value=$2
                typeChecker=${_typeMap[${type}]}
                [[ ${typeChecker} != '*' ]] && ${typeChecker} ${value}
                [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
                _argsParsedOptions+=([${option##*-}]=${value})
                shift 2

            else

                # No, it's a flag so just store it

                _argsParsedOptions+=([${option##*-}]='1')
                shift
            fi

        elif (( typedArg == 0 || argIndex < maxIndex )); then

            value=$1

            if (( typedArg )); then

                type=${_argsArgumentTypes[${argIndex}]}
                if [[ ${type} == * ]]; then

                    # Any type, so treat further args as untyped

                    typedArg=0
                else

                    # Validate and convert bool if needed

                    typeChecker=${_typeMap[${type}]}
                    [[ ${typeChecker} != '*' ]] && ${typeChecker} ${value}
                    [[ ${type} == 'bool' ]] && booleanAsInteger ${value} value
                fi
            fi

            _argsParsedArguments+=("${value}")
            (( argIndex++ ))
            shift
        else
            fail "unknown argument: $1"
        fi
    done

#    set +x; echo; echo "DONE PARSING"; echo; declare -p _argsParsedOptions _argsParsedArguments
}


