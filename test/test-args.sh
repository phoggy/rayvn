#!/usr/bin/env bash

main() {
    init "$@"

    testDefaultSpec
    testCustomSpec

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
    declare -a expectedArguments=([0]="true" [1]="foo" [2]="bar")
    assertParse spec expectedOptions expectedArguments "${passArgs[@]}"

}

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
    local expectedArgCount=${#expectedArgsRef[@]}
    local option i expectedValue value

    # Assert lengths

    if (( ${#_argsParsedOptions[@]} != expectedOptionsCount )); then
        fail "expected ${ declare -p "$1"; }, got ${ declare -p "${_argsParsedOptions}"; }"
    fi
    if (( ${#_argsParsedArguments[@]} != expectedArgCount )); then
        fail "expected ${ declare -p "$2"; }, got ${ declare -p "${_argsParsedArguments}"; }"
    fi

    # Assert options

    for option in "${!expectedOptionsRef[@]}"; do
        local expectedValue=${expectedOptionsRef["${option}"]}
        local value=${_argsParsedOptions["${option}"]}
        assertEqual "${value}" "${expectedValue}" "for option '${option}'"
    done

    # Assert args

    for (( i = 0; i < expectedArgCount; i++ )); do
        local expectedValue=${expectedArgsRef[i]}
        local value=${_argsParsedArguments[i]}
        assertEqual "${value}" "${expectedValue}" "for argument '$i'"
    done
}

_minStringLength4() {
    checked=1 error=
    (( ${#1} > 3 )) || error="$1 must be 4 characters or longer"
}

source rayvn.up 'rayvn/test' 'rayvn/args'
main "$@"
