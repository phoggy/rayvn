#!/usr/bin/env bash

main() {
    init "$@"

    testDefaultSpec
    testCustomSpec
    testGenArgumentParser

    return 0
}

init() {

    # Process args

    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
}

testDefaultSpec() {
    local spec=( "--name|-n:str" "--force|-f"  "--count:+int"  "bool" '*' )
    local args=(-f --name bar --count 29 true foo bar)
    parseSpecAndArguments spec "${args[@]}"
}

testCustomSpec() {
    declare -A _customTypeMap=( ['str4']=_minStringLength4 ['str']='*' ['int']=assertInt ['+int']=assertPositiveInt
                                ['bool']=assertBool ['file']=assertFile ['dir']=assertDirectory )
    local argsTypeMap=_customTypeMap
    local spec=( "--name|-n:str4" "--force|-f"  "--count:+int"  "bool" '*' )

    local failArgs=(-f --name bar --count 29 true foo bar)   # should fail, 'bar' is too short
    assertParseFailed spec "bar must be 4 characters or longer" "${failArgs[@]}"


    local passArgs=(-f --name barf --count 29 true foo bar)  # should pass, 'barf' is 4 characters

    declare -A expectedOptions=([count]="29" [force]="1" [name]="barf" )
    declare -a expectedArguments=(true foo bar)
    assertParse spec expectedOptions expectedArguments "${passArgs[@]}"
}

testGenArgumentParser() {
    local spec=( "--name|-n:str" "--force|-f"  "--count:+int"  "bool" '*' )
    local parser; parser="${ generateParser spec; }"
    eval "${parser}" # should instantiate _parseArgs() function

    local args=(-f --name Bob --count 29 true foo bar)
    parseArgs "${args[@]}"

    declare -p _argsParsedOptions _argsParsedArguments

    declare -A expectedOptions=([count]="29" [force]="1" [name]="Bob" )
    declare -a expectedArguments=(true foo bar)
    assertExpectedParse expectedOptions expectedArguments
}

# TODO
#testGenCommandParser() {
#}


assertParse() {
    local specVarName="$1"
    local expectedOptionsVar="$2"
    local expectedArgsVar="$3"
    shift 3
    parseSpecAndArguments "${specVarName}" "$@"
    assertExpectedParse "${expectedOptionsVar}" "${expectedArgsVar}"
}

assertParseFailed() {
    local specVarName="$1"
    local expectedError="$2"
    shift 2
    local checked=0 error
    parseSpecAndArguments "${specVarName}" "$@"
    (( checked )) || fail "not checked!"
    assertEqual "${error}" "${expectedError}"
}

assertExpectedParse() {
    local -n expectedOptionsRef="$1"
    local -n expectedArgsRef="$2"
    local expectedOptionsCount=${#expectedOptionsRef[@]}
    local expectedArgsCount=${#expectedArgsRef[@]}
    local option i expectedValue value

    # Assert lengths

    if (( ${#_argsParsedOptions[@]} != expectedOptionsCount )); then
        fail "expected ${ declare -p "$1"; }, got ${ declare -p "${_argsParsedOptions}"; }"
    fi
    if (( ${#_argsParsedArguments[@]} != expectedArgsCount )); then
        fail "expected ${ declare -p "$2"; }, got ${ declare -p "${_argsParsedArguments}"; }"
    fi

    # Assert options

    for option in "${!expectedOptionsRef[@]}"; do
        local expectedValue=${expectedOptionsRef["${option}"]}
        local value=${_argsParsedOptions["${option}"]}
        assertEqual "${value}" "${expectedValue}" "option '${option}': expected '${expectedValue}', got '${value}'"
    done

    # Assert args

    for (( i = 0; i < expectedArgCount; i++ )); do
        local expectedValue=${expectedArgsRef[i]}
        local value=${_argsParsedArguments[i]}
        assertEqual "${value}" "${expectedValue}" "argument '$i': expected '${expectedValue}', got '${value}'"
    done
}

_minStringLength4() {
    checked=1 error=
    (( ${#1} > 3 )) || error="$1 must be 4 characters or longer"
}

source rayvn.up 'rayvn/test' 'rayvn/args'
main "$@"
