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
    testArgParserRequired
    testArgParserEnum
    testArgParserCustomTypeMap

    # Generated parser tests
    testGenParser
    testGenParserAliases
    testGenParserBoolConversion
    testGenParserWildcard
    testGenParserEmptySpec
    testGenParserTypeRejection
    testGenParserRequired
    testGenParserEnum
    testGenParserCustomTypeMap
    testGenCliParser
    testUpdateParser

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
    declare -A expectedOptions=(['name']="bar" ['force']="1" ['count']="29")
    declare -a expectedArgs=("1" "foo" "bar")
    assertParse spec expectedOptions expectedArgs -f --name bar --count 29 true foo bar
}

testArgParserAliases() {
    local spec=("--name|-n:str" "--force|-f" "--count|-c:+int")
    declare -A expectedOptions=(['name']="Bob" ['force']="1" ['count']="5")
    declare -a expectedArgs=()
    assertParse spec expectedOptions expectedArgs -n Bob -f -c 5
}

testArgParserBoolConversion() {
    local spec=("--verbose|-v:bool")
    declare -A expected

    expected=(['verbose']="1"); assertParseOptions spec expected --verbose true
    expected=(['verbose']="0"); assertParseOptions spec expected --verbose false
    expected=(['verbose']="1"); assertParseOptions spec expected --verbose 1
    expected=(['verbose']="0"); assertParseOptions spec expected -v 0
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

    spec=("--name:str" "--force|-f")
    assertParseFailsWith spec "missing value for --name" --name --force
}

testArgParserRequired() {
    local spec

    # Typed positionals are required by default
    spec=("str")
    assertParseFailsWith spec "missing required argument"
    spec=("str" "str")
    assertParseFailsWith spec "missing required arguments: expected at least 2" onlyOne

    # The '?' suffix makes a positional optional
    spec=("str?")
    declare -A expectedOptions=()
    declare -a expectedArgs=()
    assertParse spec expectedOptions expectedArgs

    spec=("str" "str?")
    expectedArgs=("foo")
    assertParse spec expectedOptions expectedArgs foo

    # Wildcard remains optional
    spec=("str" "*")
    assertParseFailsWith spec "missing required argument"
    expectedArgs=("foo" "bar")
    assertParse spec expectedOptions expectedArgs foo bar
}

testArgParserEnum() {
    local spec

    # Positional enum
    spec=("audit|update")
    declare -A expectedOptions=()
    declare -a expectedArgs=("audit")
    assertParse spec expectedOptions expectedArgs audit
    expectedArgs=("update")
    assertParse spec expectedOptions expectedArgs update
    assertParseFailsWith spec "must be one of: audit|update" bogus

    # Option enum
    spec=("--mode:fast|slow")
    declare -A expected=(['mode']="fast")
    assertParseOptions spec expected --mode fast
    assertParseFailsWith spec "must be one of: fast|slow" --mode medium
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
    declare -A expectedOptions=(['count']="29" ['force']="1" ['name']="barf")
    declare -a expectedArgs=("1" "foo" "bar")
    assertParse spec expectedOptions expectedArgs "${passArgs[@]}"
}

# ──────────────────────────────────────────────────────────────────────────────
# Generated parser tests
# ──────────────────────────────────────────────────────────────────────────────

testGenParser() {
    local spec=("--name|-n:str" "--force|-f" "--count:+int" "bool" "*")
    evalGeneratedParser spec

    declare -A expectedOptions=(['count']="29" ['force']="1" ['name']="Bob")
    declare -a expectedArgs=("1" "foo" "bar")

    parseArgs -f --name Bob --count 29 true foo bar
    assertExpectedParse expectedOptions expectedArgs
}

testGenParserAliases() {
    local spec=("--name|-n:str" "--force|-f" "--count|-c:+int")
    evalGeneratedParser spec

    declare -A expectedOptions=(['name']="Bob" ['force']="1" ['count']="5")
    declare -a expectedArgs=()
    parseArgs -n Bob -f -c 5
    assertExpectedParse expectedOptions expectedArgs
}

testGenParserBoolConversion() {
    local spec=("--verbose|-v:bool")
    evalGeneratedParser spec

    declare -A expected
    declare -a noArgs=()

    expected=(['verbose']="1"); parseArgs --verbose true; assertExpectedParse expected noArgs
    expected=(['verbose']="0"); parseArgs --verbose false; assertExpectedParse expected noArgs
    expected=(['verbose']="1"); parseArgs --verbose 1; assertExpectedParse expected noArgs
    expected=(['verbose']="0"); parseArgs -v 0; assertExpectedParse expected noArgs
}

testGenParserWildcard() {
    local spec=("*")
    evalGeneratedParser spec

    declare -A expectedOptions=()
    declare -a expectedArgs=("foo" "bar" "baz")
    parseArgs foo bar baz
    assertExpectedParse expectedOptions expectedArgs
}

testGenParserEmptySpec() {
    local spec=()
    evalGeneratedParser spec
    assertGenParseFailsWith "unknown argument: foo" foo
}

testGenParserTypeRejection() {
    local spec

    spec=("--count:+int")
    evalGeneratedParser spec
    assertGenParseFailsWith "must be a positive integer" --count -5
    assertGenParseFailsWith "must be a positive integer" --count abc

    spec=("--n:int")
    evalGeneratedParser spec
    assertGenParseFailsWith "must be a positive or negative integer" --n 3.14

    spec=("--name:str")
    evalGeneratedParser spec
    assertGenParseFailsWith "missing value for --name" --name
    assertGenParseFailsWith "unknown argument: --bad" --name foo --bad

    spec=("str")
    evalGeneratedParser spec
    assertGenParseFailsWith "unknown argument: bar" foo bar

    spec=("--flag:bool")
    evalGeneratedParser spec
    assertGenParseFailsWith "must be boolean" --flag maybe

    spec=("--name:str" "--force|-f")
    evalGeneratedParser spec
    assertGenParseFailsWith "missing value for --name" --name --force
}

testGenParserRequired() {
    local spec

    spec=("str")
    evalGeneratedParser spec
    assertGenParseFailsWith "missing required argument"
    parseArgs foo
    declare -A expectedOptions=()
    declare -a expectedArgs=("foo")
    assertExpectedParse expectedOptions expectedArgs

    spec=("str" "str")
    evalGeneratedParser spec
    assertGenParseFailsWith "missing required arguments: expected at least 2" onlyOne

    spec=("str?")
    evalGeneratedParser spec
    parseArgs
    expectedArgs=()
    assertExpectedParse expectedOptions expectedArgs

    spec=("str" "*")
    evalGeneratedParser spec
    assertGenParseFailsWith "missing required argument"
    parseArgs foo bar
    expectedArgs=("foo" "bar")
    assertExpectedParse expectedOptions expectedArgs
}

testGenParserEnum() {
    local spec

    # Positional enum
    spec=("audit|update")
    evalGeneratedParser spec
    declare -A expectedOptions=()
    declare -a expectedArgs=("audit")
    parseArgs audit
    assertExpectedParse expectedOptions expectedArgs
    assertGenParseFailsWith "must be one of: audit|update" bogus

    # Option enum
    spec=("--mode:fast|slow")
    evalGeneratedParser spec
    expectedOptions=(['mode']="slow")
    expectedArgs=()
    parseArgs --mode slow
    assertExpectedParse expectedOptions expectedArgs
    assertGenParseFailsWith "must be one of: fast|slow" --mode medium
}

testGenParserCustomTypeMap() {
    declare -Ar _genCustomTypeMap=(['str4']=_assertMinStringLength4 ['str']='*' ['int']=assertInt
                                   ['+int']=assertPositiveInt ['bool']=assertBool
                                   ['file']=assertFile ['dir']=assertDirectory)
    local argsTypeMap=_genCustomTypeMap
    local spec=("--name|-n:str4" "--force|-f" "str4")
    evalGeneratedParser spec

    # Custom checker must be embedded in the generated code for both option and positional
    assertGenParseFailsWith "must be 4 characters or longer" --name bar good
    assertGenParseFailsWith "must be 4 characters or longer" --name good bar

    declare -A expectedOptions=(['name']="barf" ['force']="1")
    declare -a expectedArgs=("good")
    parseArgs -f --name barf good
    assertExpectedParse expectedOptions expectedArgs
}

testGenCliParser() {
    declare -A cliSpec=(['list']='list(--verbose|-v *)' ['add']='add(--name|-n:str str)')
    local parser; parser="${ generateParser rayvn cliSpec; }"
    eval "${parser}"

    declare -F parseCommand > /dev/null || fail "parseCommand was not generated"
    declare -F parseListArgs > /dev/null || fail "parseListArgs was not generated"
    declare -F parseAddArgs > /dev/null || fail "parseAddArgs was not generated"

    # Define command handlers and dispatch

    local listCalled=0 addCalled=0
    listCmd() { listCalled=1; }
    listCmdUsage() { fail "listCmdUsage should not be called"; }
    addCmd() { addCalled=1; }
    addCmdUsage() { fail "addCmdUsage should not be called"; }

    parseCommand list --verbose foo bar
    (( listCalled )) || fail "listCmd was not called"
    declare -A expectedOptions=(['verbose']="1")
    declare -a expectedArgs=("foo" "bar")
    assertExpectedParse expectedOptions expectedArgs

    parseCommand add -n widget thing
    (( addCalled )) || fail "addCmd was not called"
    expectedOptions=(['name']="widget")
    expectedArgs=("thing")
    assertExpectedParse expectedOptions expectedArgs
}

testUpdateParser() {
    local dir; dir=${ makeTempDir; }
    local script="${dir}/example.sh"
    cat > "${script}" << 'EOF'
#!/usr/bin/env bash

# rayvn:args exampleSpec example
declare -a exampleSpec=("--name|-n:str" "--force|-f" "+int")

main() { parseExampleArgs "$@"; }
EOF

    # Initial generation inserts a marked block after the spec

    updateParser "${script}" > /dev/null
    grep -q '^ARGS_PARSER_BEGIN=' "${script}" || fail "ARGS_PARSER_BEGIN marker not found"
    grep -q '^ARGS_PARSER_END=' "${script}" || fail "ARGS_PARSER_END marker not found"
    grep -q 'parseExampleArgs()' "${script}" || fail "generated parseExampleArgs() not found"

    # Regeneration must replace the block, not duplicate it

    updateParser "${script}" > /dev/null
    local count; count=${ grep -c '^ARGS_PARSER_BEGIN=' "${script}"; }
    (( count == 1 )) || fail "expected 1 ARGS_PARSER_BEGIN marker after regen, got ${count}"
    count=${ grep -c 'parseExampleArgs()' "${script}"; }
    (( count == 1 )) || fail "expected 1 parseExampleArgs() after regen, got ${count}"

    # Generated parser must work

    local block; block=${ gawk '/^ARGS_PARSER_BEGIN=/{f=1} f{print} /^ARGS_PARSER_END=/{f=0}' "${script}"; }
    eval "${block}"
    declare -A expectedOptions=(['name']="Bob" ['force']="1")
    declare -a expectedArgs=("42")
    parseExampleArgs -f --name Bob 42
    assertExpectedParse expectedOptions expectedArgs
}


# ──────────────────────────────────────────────────────────────────────────────
# Performance benchmark
# ──────────────────────────────────────────────────────────────────────────────

benchmarkParsers() {
    local spec=("--name|-n:str" "--force|-f" "--count|-c:+int" "bool" "*")
    evalGeneratedParser spec

    local iterations=500
    local args=(--force --name Bob --count 29 true foo bar)

    echo
    echo "=== Parser Performance Benchmark ==="
    echo
    benchmark _benchRuntime   ${iterations} "runtime-declarative" "${args[@]}"
    benchmark parseArgs   ${iterations} "generated"      "${args[@]}"
    benchmark _benchHandCoded ${iterations} "hand-coded"          "${args[@]}"
    echo
}

_benchRuntime() {
    local spec=("--name|-n:str" "--force|-f" "--count|-c:+int" "bool" "*")
    parseArgumentSpecAndArgs spec "$@"
}

_benchHandCoded() {
    _opts=()
    _args=()
    local argIndex=0 value
    while (( $# )); do
        case "$1" in
            --name | -n) [[ -z "$2" ]] && fail "missing value for --name"; _opts+=(['name']="$2"); shift 2 ;;
            --force | -f) _opts+=(['force']="1"); shift ;;
            --count | -c) [[ -z "$2" ]] && fail "missing value for --count"; assertPositiveInt "$2"; _opts+=(['count']="$2"); shift 2 ;;
            *)
                value="$1"
                if (( argIndex == 0 )); then
                    assertBool "${value}"
                    booleanAsInteger "${value}" value
                fi
                _args+=("${value}")
                (( argIndex++ ))
                shift
                ;;
        esac
    done
}

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

evalGeneratedParser() {
    local parser; parser="${ generateParser rayvn $1; }"
    eval "${parser}"
}

assertGenParseFailsWith() {
    local expectedError="$1"
    shift
    local err
    err=${ ( parseArgs "$@" ) 2>&1; }
    [[ -n "${err}" ]] || fail "parse should have failed but produced no error"
    assertContains "${expectedError}" "${err}"
}

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

    (( ${#_opts[@]} == ${#expectedOptionsRef[@]} )) || \
        fail "expected ${#expectedOptionsRef[@]} options, got ${#_opts[@]}: ${ declare -p _opts; }"

    (( ${#_args[@]} == ${#expectedArgsRef[@]} )) || \
        fail "expected ${#expectedArgsRef[@]} args, got ${#_args[@]}: ${ declare -p _args; }"

    for option in "${!expectedOptionsRef[@]}"; do
        local expectedValue=${expectedOptionsRef["${option}"]}
        local value=${_opts["${option}"]}
        assertEqual "${value}" "${expectedValue}" "option '${option}': expected '${expectedValue}', got '${value}'"
    done

    for (( i = 0; i < ${#expectedArgsRef[@]}; i++ )); do
        local expectedValue=${expectedArgsRef[i]}
        local value=${_args[i]}
        assertEqual "${value}" "${expectedValue}" "argument '${i}': expected '${expectedValue}', got '${value}'"
    done
}

_minStringLength4() {
    checked=1 error=
    (( ${#1} > 3 )) || error="$1 must be 4 characters or longer"
}

_assertMinStringLength4() {
    (( ${#1} > 3 )) || fail "$1 must be 4 characters or longer"
}

source rayvn.up 'rayvn/test' 'rayvn/args'
main "$@"
