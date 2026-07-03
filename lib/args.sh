#!/usr/bin/env bash

# Argument parsing.
# Use via: require 'rayvn/args'

# Argument Specification
#
# An argument spec is an array declaring named/typed options (e.g. --count 5 --file /etc/passwd), named/boolean flags (e.g. -f)
# and typed or untyped positional arguments. Parsed options and flags are accessed by name, arguments by position.
#
# For example:
#
#     local argSpec=( "--name|-n:str" "--force|-f"  "--count:+int"  "bool" '*' )
#
# The * wildcard positional argument allows any number of untyped values to follow. This is intended to support cases like
# that of tar args with -C dir interspersed and requires the caller to validate them.
#
#      type: str | int | +int | bool | file | dir
#    option: --name[|alias]:type                    TODO: allow multiple aliases??
#      flag: --name[|alias]
#      spec: [option | flag | type]... [*]
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
# An argument spec can be processed at runtime or once
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


# CLI Specification
#
# A map of command args to handler functions, where the function is defined as a handler function name followed by
# its argument spec in parens:
#
#   handlerFnName( spec )
#
# For example:
#
#    declare -A cliSpec=(
#        ['passphrase']="newPassphrase(--words|-w:+int --separator|-s:str --count|-c:+int)"
#        ['password']="newPassword(--length|-l:+int)"
#    )
#
# CLI specifications can only be processed by generateParser().
#
# Note that if there are command aliases, they can be added as a copy, e.g. to support 'pass' as an alias for
# 'passphrase':
#
#    declare -A cliSpec=(
#        ['passphrase']="newPassphrase(--words|-w:+int --separator|-s:str --count|-c:+int)"
#        ['pass']="newPassphrase(--words|-w:+int --separator|-s:str --count|-c:+int)"
#        ['password']="newPassword(--length|-l:+int)"
#    )



# Arg Parser Styles
#
# Support three templates
#
#    local (imperative) EXISTS
#    shared (declarative: args spec) CREATE
#    shared CLI (declarative: cmd spec) CREATE
#
# TODO Add: rayvn args SCRIPT_PATH: gen/regen


# ◇ Parse argument specifications. Assumes that the following variables are defined and will fill them:
#
#   declare -A _argsOptionNames
#   declare -A _argsOptionTypes
#   declare -a _argsArgumentTypes
#
# · ARGS
#
#   argsSpec (arrayRef)     Arguments specification.

parseArgumentSpec() {
    local specVar=$1
    local specType; specType=${ _getSpecType; }
    [[ ${specType} == argument ]] || fail "CLI specification not supported"
    _parseArgumentSpec "${specVar}"; shift
}

# ◇ Parse argument specification and arguments.
#
# · ARGS
#
#   argsSpec (arrayRef)     Arguments specification.
#   args (array)            The arguments to parse.

parseArgumentSpecAndArgs() {
    local specVar=$1
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes

    parseArgumentSpec "${specVar}"; shift
    _parseArguments "$@"
}

# ◇ Generate a parser for either an argument or CLI spec. Both assume a usage() function exists
#   to handle the -h and --help arguments. CLI specs also assume the existence of ${handler}Usage
#   functions to support command help.
#
# · ARGS
#
#   project (string)    The project name, used to handle the -v and --version arguments.
#   specVar (arrayRef)  The name of the arguments specification array or CLI specification map.

generateParser() {
    local project=$1
    local specVar=$2
    local specType; specType=${ _getSpecType true; }
    local generator; [[ ${specType} == argument ]] && generator=_genArgumentParser || generator=_genCommandParser

    # Gen begin delimiter

    echo "${_beginParseSection}"; echo

    # Gen parser

    ${generator} "${project}" "${specVar}"

    # Gen end delimiter

    echo; echo "${_endParseSection}"; echo
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/args' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_args() {

    # Generated code delimiters

    declare -gr _beginParseSection="ARGS_PARSER_BEGIN=\"━━━━🚫━━━━━━━━━━━━━━━━━━━━━━━ 🚫 🔽 BEGIN generated code: DO NOT EDIT 🔽 🚫 ━━━━━━━━━━━━━━━━━━━━━━━━━━🚫━━━━\""
    declare -gr   _endParseSection="ARGS_PARSER_END=\"━━━━━━🚫━━━━━━━━━━━━━━━━━━━━━━━━ 🚫 🔼 END generated code: DO NOT EDIT 🔼 🚫 ━━━━━━━━━━━━━━━━━━━━━━━━━━━🚫━━━━\""

    # Default type map

    declare -gAr _argsDefaultTypeMap=( ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt ['bool']=assertBool
                                       ['file']=assertFile ['dir']=assertDirectory )

    # Selected type map. User can override

    declare -g argsTypeMap=_argsDefaultTypeMap

    # Parse results

    declare -gA _argsParsedOptions
    declare -ga _argsParsedArguments
}

_getSpecType() {
    [[ -n ${specVar} ]] || invalidArgs "parser specification required"
    local _type; _type="${ declare -p "${specVar}" 2> /dev/null | cut -d' ' -f2; }"
    if [[ -z "${_type}" ]]; then
        fail "${specVar} var is not defined"
    elif [[ ${_type} == -a* ]]; then
        echo "argument"
    elif [[ ${_type} == -A* ]]; then
        echo "CLI"
    else
        fail "unsupported parser specification type: ${specVar}"
    fi
}

_genArgumentParser() {

    # Gen parser function

    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes
    _genParseFunction "$2"
}

_genCommandParser() {
    local project="$1"
    local -n _commandSpec="$2"
    declare -A _argsOptionNames
    declare -A _argsOptionTypes
    declare -a _argsArgumentTypes
    declare -A handlers=()
    local command handler usage fnSpec tmpSpec argsSpec=()

    # Gen main parser function

    echo "parseCommand() {"
    echo "    parseCommonOptions ${project} \"\$@\"; shift \$?"
    echo "    while (( \$# )); do"
    echo "        case \"\$1\" in"
    for command in "${!_commandSpec[@]}"; do
        fnSpec="${_commandSpec[${command}]}"
        handler="${fnSpec%(*}"
        usage="${handler}Usage"
        handler="parse${handler^}Args"
        echo "            ${command}) shift; ${handler} \"\$@\" ;;"
    done
    echo "            -h | --help) \"${usage}\" ;;"
    echo "            *) usage \"unknown command: \"\$1\" ;;"
    echo "        esac"
    echo "    done"
    echo "}"
    echo

    # Gen command parser functions

    for command in "${!_commandSpec[@]}"; do
        fnSpec="${_commandSpec[${command}]}"
        handler="${fnSpec%(*}"
        tmpSpec="${fnSpec#*(}"
        argsSpec+=("${tmpSpec%*)}")
        _genParseFunction argsSpec "${handler}"
        echo
    done
}

_genParseFunction() {
    [[ -n $1 ]] || invalidArgs "arguments specification required"
    local specVar="$1"
    local name="${2:-}"
    _parseArgumentSpec "${specVar}"
    {
        echo "parse${name^}Args() {"
        echo "    ${ declare -p _argsOptionNames; }"
        echo "    ${ declare -p _argsOptionTypes; }"
        echo "    ${ declare -p _argsArgumentTypes; }"
        echo '    _parseArguments "$@"'
        echo '}'
    }
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


