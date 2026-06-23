#!/usr/bin/env bash

# CLI utilities.
# Use via: require 'rayvn/cli'

# OPTION 1 (current implementation)
#
# Simplified version of option 3 with no type info or validation, only a simplified signature passed.
#
#    declare -gAr commandHandlers=(
#        ['pass']="newPassphrase(words separator count)"
#        ['passphrase']="newPassphrase(words separator count)"
#        ['password']="newPassword(count)"
#        ['pwned']=checkPass"newPassword(arguments)"
#        ['keys']="newKeys(name)"
#        ['keygen']="newKeys(name)"
#        ['paper']="newPaperKeys(arguments)"
#        ['paper-keys']="newPaperKeys(arguments)"
#        ['archive']="newArchive(arguments)"
#    )
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
# The bool type accepts true/1 false/0 as input and maps it to 0 or 1 for simpler test (( myFlag )).
#
# Example
# myCommand(--words|-w:int --separator|-s:str --count|-c:int --myFlag|-f privateKey:file publicKey:file)
#
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
# The bool type accepts true/1 false/0 as input and maps it to 0 or 1 for simpler testing (( myFlag )). Flags are
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
#        ['archive']="newArchive(--file|-f:file{} --dir|-d:dir[])"
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
parseCliOptions() {
    local -n _handlersRef=$1
    local _expectedArgs=$2; shift 2
    local _option

    declare -g commandHandler
    declare -g commandSignature
    declare -gA commandOptions=()

    [[ $1 ]] || usage
    while (( $# > 0 )); do
        case "$1" in
            -h | --help) [[ -z ${commandHandler} ]] && usage || _setCommandHelp ;;
            -v) projectVersion valt; exit 0 ;;
            --version) projectVersion valt true; exit 0 ;;
            --debug*) setDebug "$@"; shift $? ;;
            -*) _setCommandOption "$1" ;;
            *) [[ -z ${commandHandler} ]] && _setCommand "$1" "${_handlersRef["$1"]}" || _setCommandOption "$1" ;;
        esac
        shift
    done

debug; debug "PARSE RESULTS"; debug; debugVar commandHandler commandSignature commandOptions _expectedArgs
    local args=(${commandOptions['arguments']})
    local argCount="${#args[@]}"
debug; debug ARGS; debugVar args argCount

    if (( argCount != _expectedArgs )); then
        (( argCount > 0 )) && fail "unknown arguments: ${args[*]}" || fail "missing $(( _expectedArgs - argCount )) arguments"
    fi
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/cli' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_cli() {
    :
}

_setCommand() {
    debug; debug "_setCommand $1 $2"
    command="$1"
    commandSignature="$2"
    commandHandler="${2%(*}"
    [[ -n "${commandSignature}" ]] || usage "unknown command: $1"
}

_setCommandHelp() {
    debug; debug "_setCommandHelp"
    commandHandler="${commandHandler}Usage"
    declare -f "${commandHandler}" > /dev/null || fail "missing ${commandHandler} function"
}

_setCommandOption() {
    debug; debug "_setCommandOption $1, existing option: '${_option}'"
    if [[ -n "${_option}" ]]; then
        debug "adding new value: ${_option} $1"
        _addCommandOption "${_option}" "$1"
    elif [[ "$1" == -* ]]; then
        _option="${1//-/}"
        debugVar _option
        if (( ${#_option} > 0 )); then
            debug "adding new key: ${_option}"
            local existing="${commandOptions[${_option}]}"
            [[ -n "${existing}" ]] && fail "--${_option} passed more than once"
            commandOptions+=(["${_option}"]="")
            debugVar commandOptions
        else
            debug "adding new '-*' argument: $1"
            _addCommandOption "arguments" "$1"
        fi
    else
        debug "adding new argument: $1"
        _addCommandOption "arguments" "$1"
    fi
}

_addCommandOption() {
debug; debug "_addCommandOption $1 $2"
    local _key=$1
    local _value=$2
    local _args="${commandOptions[${_key}]}"
    [[ -n ${_args} ]] && _args="${_args} ${_value}" || _args="${_value}"
    commandOptions+=(["${_key}"]="${_args}")
    _option=
    debugVar commandOptions
}
