#!/usr/bin/env bash

main() {
    init "$@"

    # Argument spec + runtime parser tests
    testArgParserBasic
    testArgParserAliases
    testArgParserBoolConversion
    testArgParserEmptySpec
    testArgParserWildcard
    testArgParserTypeRejection
    testArgParserCustomTypeMap

    # Generated parser tests
    testGenArgumentParser
    testGenCliParser

    # Performance benchmark
    benchmarkParsers
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Argument spec + runtime parser tests
# ──────────────────────────────────────────────────────────────────────────────

testArgParserBasic() {
    local spec=("--name|-n:str" "--force|-f" "--count:+int" "bool" "*")
    declare -A expectedOptions=([name]="bar" [force]="1" [count]="29")
    declare -a expectedArgs=("1" "foo" "bar")
    assertParse spec expectedOptions expectedArgs -f --name bar --count 29 true foo bar
}

testArgParserAliases() {
    local spec=("--name|-n:str" "--force|-f" "--count|-c:+int")
    declare -A expectedOptions=([name]="Bob" [force]="1" [count]="5")
    declare -a expectedArgs=()
    assertParse spec expectedOptions expectedArgs -n Bob -f -c 5
}

testArgParserBoolConversion() {
    local spec=("--verbose|-v:bool")
    declare -A expected

    expected=([verbose]="1"); assertParseOptions spec expected --verbose true
    expected=([verbose]="0"); assertParseOptions spec expected --verbose false
    expected=([verbose]="1"); assertParseOptions spec expected --verbose 1
    expected=([verbose]="0"); assertParseOptions spec expected -v 0
}

testArgParserEmptySpec() {
    local spec=()
    assertParseFailsWith spec "unknown argument: foo" foo
}

testArgParserWildcard() {
    local spec=("*")
    declare -A expectedOptions=()
    declare -a expectedArgs=("foo" "bar" "baz")
    assertParse spec expectedOptions expectedArgs foo bar baz
}

testArgParserTypeRejection() {
    local spec

    spec=("--count:+int")
    assertParseFailsWith spec "must be a positive integer" --count -5
    assertParseFailsWith spec "must be a positive integer" --count abc

    spec=("--n:int")
    assertParseFailsWith spec "must be a positive or negative integer" --n 3.14

    spec=("--name:str")
    assertParseFailsWith spec "missing value for --name" --name

    spec=("str")
    assertParseFailsWith spec "unknown argument: bar" foo bar

    spec=("--flag:bool")
    assertParseFailsWith spec "must be boolean" --flag maybe

    spec=("--name:str")
    assertParseFailsWith spec "unknown argument: --bad" --name foo --bad
}

testArgParserCustomTypeMap() {
    declare -Ar _customTypeMap=(['str4']=_minStringLength4 ['str']='*' ['int']=assertInt
                                ['+int']=assertPositiveInt ['bool']=assertBool
                                ['file']=assertFile ['dir']=assertDirectory)
    local argsTypeMap=_customTypeMap
    local spec=("--name|-n:str4" "--force|-f" "--count:+int" "bool" "*")

    local failArgs=(-f --name bar --count 29 true foo bar)
    assertParseFailed spec "bar must be 4 characters or longer" "${failArgs[@]}"

    local passArgs=(-f --name barf --count 29 true foo bar)
    declare -A expectedOptions=([count]="29" [force]="1" [name]="barf")
    declare -a expectedArgs=("1" "foo" "bar")
    assertParse spec expectedOptions expectedArgs "${passArgs[@]}"
}

# ──────────────────────────────────────────────────────────────────────────────
# Generated parser tests
# ──────────────────────────────────────────────────────────────────────────────

testGenArgumentParser() {
    local spec=("--name|-n:str" "--force|-f" "--count:+int" "bool" "*")
    local parser; parser="${ generateParser rayvn spec; }"
    eval "${parser}"

    declare -A expectedOptions=([count]="29" [force]="1" [name]="Bob")
    declare -a expectedArgs=("1" "foo" "bar")

    parseArgs -f --name Bob --count 29 true foo bar
    assertExpectedParse expectedOptions expectedArgs
}

testGenCliParser() {
    declare -A cliSpec=(
        ['passphrase']="newPassphrase(--words|-w:+int --separator|-s:str --count|-c:+int)"
        ['password']="newPassword(--length|-l:+int)"
    )
    local parser; parser="${ generateParser valt cliSpec; }"
    eval "${parser}"

    usage() { fail "usage() unexpectedly called: $*"; }

    # Test passphrase command with long options

    declare -A expectedOptions=([words]="3" [separator]="-" [count]="5")
    declare -a expectedArgs=()
    parseCommand passphrase --words 3 --separator - --count 5
    assertExpectedParse expectedOptions expectedArgs

    # Test passphrase with short aliases

    expectedOptions=([words]="8" [separator]="." [count]="3")
    parseCommand passphrase -w 8 -s . -c 3
    assertExpectedParse expectedOptions expectedArgs

    # Test password command with long option

    expectedOptions=([length]="12")
    parseCommand password --length 12
    assertExpectedParse expectedOptions expectedArgs

    # Test password with short alias

    expectedOptions=([length]="24")
    parseCommand password -l 24
    assertExpectedParse expectedOptions expectedArgs

    unset -f usage parseCommand parseNewPassphraseArgs parseNewPasswordArgs
}

# ──────────────────────────────────────────────────────────────────────────────
# Performance benchmark
# ──────────────────────────────────────────────────────────────────────────────

benchmarkParsers() {
    local spec=("--name|-n:str" "--force|-f" "--count|-c:+int" "bool" "*")
    local parser; parser="${ generateParser rayvn spec; }"
    eval "${parser}"

    local iterations=500
    local args=(--force --name Bob --count 29 true foo bar)

    echo
    echo "=== Parser Performance Benchmark ==="
    echo
    benchmark _benchRuntime   ${iterations} "runtime-declarative" "${args[@]}"
    benchmark parseArgs       ${iterations} "generated-parser"    "${args[@]}"
    benchmark _benchHandCoded ${iterations} "hand-coded"          "${args[@]}"
    echo
}

_benchRuntime() {
    local spec=("--name|-n:str" "--force|-f" "--count|-c:+int" "bool" "*")
    parseArgumentSpecAndArgs spec "$@"
}

_benchHandCoded() {
    _argsParsedOptions=()
    _argsParsedArguments=()
    local argIndex=0 value
    while (( $# )); do
        case "$1" in
            --name | -n) _argsParsedOptions+=([name]="$2"); shift 2 ;;
            --force | -f) _argsParsedOptions+=([force]="1"); shift ;;
            --count | -c) assertPositiveInt "$2"; _argsParsedOptions+=([count]="$2"); shift 2 ;;
            *)
                value="$1"
                if (( argIndex == 0 )); then
                    assertBool "${value}"
                    booleanAsInteger "${value}" value
                fi
                _argsParsedArguments+=("${value}")
                (( argIndex++ ))
                shift
                ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

assertParse() {
    local specVarName="$1"
    local expectedOptionsVar="$2"
    local expectedArgsVar="$3"
    shift 3
    parseArgumentSpecAndArgs "${specVarName}" "$@"
    assertExpectedParse "${expectedOptionsVar}" "${expectedArgsVar}"
}

assertParseOptions() {
    local specVarName="$1"
    local expectedOptionsVar="$2"
    shift 2
    local -a _emptyArgs=()
    parseArgumentSpecAndArgs "${specVarName}" "$@"
    assertExpectedParse "${expectedOptionsVar}" _emptyArgs
}

assertParseFailed() {
    local specVarName="$1"
    local expectedError="$2"
    shift 2
    local checked=0 error
    parseArgumentSpecAndArgs "${specVarName}" "$@"
    (( checked )) || fail "type checker not called"
    assertEqual "${error}" "${expectedError}"
}

assertParseFailsWith() {
    local specVarName="$1"
    local expectedError="$2"
    shift 2
    local err
    err=${ ( parseArgumentSpecAndArgs "${specVarName}" "$@" ) 2>&1; }
    [[ -n "${err}" ]] || fail "parse should have failed but produced no error"
    assertContains "${expectedError}" "${err}"
}

assertExpectedParse() {
    local -n expectedOptionsRef="$1"
    local -n expectedArgsRef="$2"
    local option i

    (( ${#_argsParsedOptions[@]} == ${#expectedOptionsRef[@]} )) || \
        fail "expected ${#expectedOptionsRef[@]} options, got ${#_argsParsedOptions[@]}: ${ declare -p _argsParsedOptions; }"

    (( ${#_argsParsedArguments[@]} == ${#expectedArgsRef[@]} )) || \
        fail "expected ${#expectedArgsRef[@]} args, got ${#_argsParsedArguments[@]}: ${ declare -p _argsParsedArguments; }"

    for option in "${!expectedOptionsRef[@]}"; do
        local expectedValue=${expectedOptionsRef["${option}"]}
        local value=${_argsParsedOptions["${option}"]}
        assertEqual "${value}" "${expectedValue}" "option '${option}': expected '${expectedValue}', got '${value}'"
    done

    for (( i = 0; i < ${#expectedArgsRef[@]}; i++ )); do
        local expectedValue=${expectedArgsRef[i]}
        local value=${_argsParsedArguments[i]}
        assertEqual "${value}" "${expectedValue}" "argument '${i}': expected '${expectedValue}', got '${value}'"
    done
}

_minStringLength4() {
    checked=1 error=
    (( ${#1} > 3 )) || error="$1 must be 4 characters or longer"
}

source rayvn.up 'rayvn/test' 'rayvn/args'
main "$@"
