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
    local option type validator argIndex=0 alias
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

                validator=${_typeValidators[${type}]}
                [[ ${validator} != 'any' ]] && ${validator} $2
                _parsedOptions+=([${option}]=$2)
                shift 2

            else

                # No, it's a flag so just store it

                _parsedOptions+=([${option}]="")
                shift
            fi

        elif (( argIndex < _anyArgIndex )); then

            # Typed argument so validate and store

            type=${_argumentTypes[argIndex]}
            validator=${_typeValidators[${type}]}
            [[ ${validator} != 'any' ]] && ${validator} $1
            _parsedArguments+=("$1")
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








# Signature Specification
#
#       type: str | int | bool | file | dir | str[] | int[] | bool[] | file[] | dir[]
#     option: --name[|-n]:type
#       flag: --name[|-n]
#        arg: type | option | flag
#       func: funcName([arg]...)
#
# The bool type accepts true|1 false|0 as input and maps it to 1 or 0 for simpler tests (( myFlag )). Flags are
# implicitly bool. Functions are accepted only for the command pattern.



#    declare -A commandHandlers=(
#        ['pass']="newPassphrase(--words|-w:int --separator|-s:str --count|-c:int)"
#        ['passphrase']="newPassphrase(--words|-w:int --separator|-s:str --count|-c:int)"
#        ['password']="newPassword(--count|-c:int)"
#        ['pwned']="checkPass(str)"
#        ['keys']="newKeys(--name|-n:str --force|-f --no-verify --no-advice --no-doc --key-info|-k:file --template|-t:file \
#                          --css|-c:file --output-dir|-o:dir)"
#        ['keygen']="newKeys(--name|-n:str --force|-f --no-verify --no-advice --no-doc --key-info|-k:file --template|-t:file \
#                            --css|-c:file --output-dir|-o:dir)"
#        ['paper']="newPaperKeys(--key-info|-k:file --template|-t:file --css|-c:file --output-dir|-o:dir file)"
#        ['paper-keys']="newPaperKeys(--key-info|-k:file --template|-t:file --css|-c:file --output-dir|-o:dir file)"
#        ['archive']="newArchive(--file|-f:file{} -C:dir --dir|-d:dir[])" # TODO: how retain -C position??
#    )
#
#    newSecureArchive ([-C DIR] INPUT...) -i PATH (-r RECIPIENT | -R PATH)... [-f] [-n NAME] [--zone ZONE] [-u TEXT] [-o DIR]
#
#    SO: just don't list -C as an option!!!!!




# OPTION 1 (current implementation)
#
# Simplified version of option 3 with no type info or validation, just the handler function name
#
#    declare -gAr commandHandlers=(
#        ['pass']="newPassphrase"
#        ['passphrase']="newPassphrase"
#        ['password']="newPassword"
#        ['pwned']=checkPass"newPassword"
#        ['keys']="newKeys"
#        ['keygen']="newKeys"
#        ['paper']="newPaperKeys"
#        ['paper-keys']="newPaperKeys"
#        ['archive']="newArchive"
#    )
#
#    On return, commandHandler holds the function name and the commandOptions map contains parse results (with any
#    arguments in the 'arguments' value).
#
# OPTION 2
#
# Parse and validate input into global map, handling common options. Caller looks up values by name from map.
#
# parseCliOptions()
#
#    opt: --name[|-n...]:type
#   flag: --name[|-n...]                 # type is bool
#    arg: name:type
#   type: str | int | bool | file | dir
#
# For options and flags, the first name is used as the name after stripping '-' chars.
#
# The bool type accepts true|1 false|0 as input and maps it to 1 or 0 for simpler tests (( myFlag )). Flags are
# implicitly bool.
#
# Example
#
# myCommand(--words|-w:int --separator|-s:str --count|-c:int --myFlag|-f privateKey:file publicKey:file)
#
# Limitations
#
# Arguments are unordered so, e.g., the tar -C syntax model cannot be supported.
#
# OPTION 3
#
# Parse and validate input to positional args, handling common options, and execute a function with the args. Supports
# command pattern parsing with a separate api function. Invoked functions can perform additional validation if needed and
# are responsible for setting defaults.
#
# Signature Specification
#
#       type: str | int | bool | file | dir | str[] | int[] | bool[] | file[] | dir[]
#     option: --name[|-n]:type
#       flag: --name[|-n]
#        arg: type | option | flag
#       func: funcName([arg]...)
#
# The bool type accepts true|1 false|0 as input and maps it to 1 or 0 for simpler tests (( myFlag )). Flags are
# implicitly bool. Functions are accepted only for the command pattern.
#
# API
#
#     parseCliOptions("${myCommandSpec}", "$@")  # parses input into internal state.
#     invokeCli("myCommand")                     # invokes myCommand with parsed args.
#
# For the command pattern the first arg is assumed to be a command selector, therefore a map is required with one or more
# selectors as the keys and a function spec as values:
#
#    declare -A commandHandlers=(
#        ['pass']="newPassphrase(--words|-w:int --separator|-s:str --count|-c:int)"
#        ['passphrase']="newPassphrase(--words|-w:int --separator|-s:str --count|-c:int)"
#        ['password']="newPassword(--count|-c:int)"
#        ['pwned']="checkPass(str)"
#        ['keys']="newKeys(--name|-n:str --force|-f --no-verify --no-advice --no-doc --key-info|-k:file --template|-t:file \
#                          --css|-c:file --output-dir|-o:dir)"
#        ['keygen']="newKeys(--name|-n:str --force|-f --no-verify --no-advice --no-doc --key-info|-k:file --template|-t:file \
#                            --css|-c:file --output-dir|-o:dir)"
#        ['paper']="newPaperKeys(--key-info|-k:file --template|-t:file --css|-c:file --output-dir|-o:dir file)"
#        ['paper-keys']="newPaperKeys(--key-info|-k:file --template|-t:file --css|-c:file --output-dir|-o:dir file)"
#        ['archive']="newArchive(--file|-f:file{} -C:dir --dir|-d:dir[])" # TODO: how retain -C position??
#    )
#
#    parseCliOptions(commandHandlers, "$@")  # The map is passed by reference
#    invoke()                                # fail if funcName not parsed
#
# To process common options, the following functions are assumed to exist (in addition to those in rayvn/core):
#
#    1. usage() for any -h or --help flags prior to a command name.
#    2. myFunctionUsage() any -h or --help flags following a command name for myFunction().


# shellcheck disable=SC2206
parseCommand() {
    local _projectName=$1
    local -n _handlersRef=$2
    local _expectedArgs=$3; shift 3
    local _option

    declare -g commandHandler
    declare -gA commandOptions=()

    parseCommonOptions ${_projectName} "$@"; shift $?
    while (( $# > 0 )); do
        case "$1" in
            -h | --help) [[ -z ${commandHandler} ]] && usage || _setCommandHelp ;;
            -*) _setCommandOption "$1" ;;
            *) [[ -z ${commandHandler} ]] && _setCommand "$1" "${_handlersRef["$1"]}" || _setCommandOption "$1" ;;
        esac
        shift
    done

debug; debug "PARSE RESULTS"; debug; debugVar commandHandler commandOptions _expectedArgs
    local args=(${commandOptions['arguments']})
    local argCount="${#args[@]}"
debug; debug ARGS; debugVar args argCount

    if (( argCount != _expectedArgs )); then
        (( argCount > 0 )) && fail "unknown arguments: ${args[*]}" || fail "missing $(( _expectedArgs - argCount )) arguments"
    fi
}

#PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/cli' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"
#
#_init_rayvn_command() {
#    :
#}
#
#_setCommand() {
#    debug; debug "_setCommand $1 $2"
#    command="$1"
#    commandHandler="$2"
#    [[ -n "${commandHandler}" ]] || fail "command handler not found: $1"
#}
#
#_setCommandHelp() {
#    debug; debug "_setCommandHelp"
#    commandHandler="${commandHandler}Usage"
#    declare -f "${commandHandler}" > /dev/null || fail "missing ${commandHandler} function"
#}
#
#_setCommandOption() {
#    debug; debug "_setCommandOption $1, existing option: '${_option}'"
#    if [[ -n "${_option}" ]]; then
#        debug "adding new value: ${_option} $1"
#        _addCommandOption "${_option}" "$1"
#    elif [[ "$1" == -* ]]; then
#        _option="${1//-/}"
#        debugVar _option
#        if (( ${#_option} > 0 )); then
#            debug "adding new key: ${_option}"
#            local existing="${commandOptions[${_option}]}"
#            [[ -n "${existing}" ]] && fail "--${_option} passed more than once"
#            commandOptions+=(["${_option}"]="")
#            debugVar commandOptions
#        else
#            debug "adding new '-*' argument: $1"
#            _addCommandOption "arguments" "$1"
#        fi
#    else
#        debug "adding new argument: $1"
#        _addCommandOption "arguments" "$1"
#    fi
#}
#
#_addCommandOption() {
#debug; debug "_addCommandOption $1 $2"
#    local _key=$1
#    local _value=$2
#    local _args="${commandOptions[${_key}]}"
#    [[ -n ${_args} ]] && _args="${_args} ${_value}" || _args="${_value}"
#    commandOptions+=(["${_key}"]="${_args}")
#    _option=
#    debugVar commandOptions
#}
