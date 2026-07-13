#!/usr/bin/env bash

main() {
    init "$@"


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
    testGenParserEndOfOptions
    testGenParserEqualsValue
    testGenParserShortOnlyOption
    testGenCliParser
    testUpdateParser
    testUpdateParserCheck
    testParseArgsWithSpec

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

testGenParserEndOfOptions() {
    local spec

    # Wildcard: everything after -- is positional, even option-like values
    spec=("--force|-f" "*")
    evalGeneratedParser spec
    declare -A expectedOptions=(['force']="1")
    declare -a expectedArgs=("--force" "-x" "foo")
    parseArgs -f -- --force -x foo
    assertExpectedParse expectedOptions expectedArgs

    # Typed positionals: checks still apply after --
    spec=("--force|-f" "+int")
    evalGeneratedParser spec
    expectedOptions=()
    expectedArgs=("42")
    parseArgs -- 42
    assertExpectedParse expectedOptions expectedArgs
    assertGenParseFailsWith "must be a positive integer" -- abc
    assertGenParseFailsWith "unknown argument" -- 42 extra

    # No positionals allowed: anything after -- is unknown
    spec=("--force|-f")
    evalGeneratedParser spec
    assertGenParseFailsWith "unknown argument: foo" -- foo
    expectedOptions=(['force']="1")
    expectedArgs=()
    parseArgs -f --
    assertExpectedParse expectedOptions expectedArgs
}

testGenParserEqualsValue() {
    local spec=("--name|-n:str" "--count:+int" "--mode:fast|slow" "--verbose:bool" "--force|-f")
    evalGeneratedParser spec

    declare -A expectedOptions=(['name']="Bob" ['count']="29" ['mode']="fast" ['verbose']="0")
    declare -a expectedArgs=()
    parseArgs --name=Bob --count=29 --mode=fast --verbose=false
    assertExpectedParse expectedOptions expectedArgs

    # Option-like values are unambiguous in = form
    expectedOptions=(['name']="--weird")
    parseArgs --name=--weird
    assertExpectedParse expectedOptions expectedArgs

    # Type checks, empty values, and flags with values are rejected
    assertGenParseFailsWith "must be a positive integer" --count=abc
    assertGenParseFailsWith "must be one of: fast|slow" --mode=medium
    assertGenParseFailsWith "missing value for --name" --name=
    assertGenParseFailsWith "does not accept a value" --force=1
}

testGenParserShortOnlyOption() {
    local spec=("-f" "-c:+int")
    evalGeneratedParser spec

    declare -A expectedOptions=(['f']="1" ['c']="5")
    declare -a expectedArgs=()
    parseArgs -f -c 5
    assertExpectedParse expectedOptions expectedArgs
    assertGenParseFailsWith "must be a positive integer" -c abc
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

testUpdateParserCheck() {
    local dir; dir=${ makeTempDir; }
    local script="${dir}/checked.sh"
    cat > "${script}" << 'EOF'
#!/usr/bin/env bash

# rayvn:args checkedSpec checked
declare -a checkedSpec=("--name|-n:str" "str?")

main() { parseCheckedArgs "$@"; }
EOF

    # Missing block reports drift
    ( updateParser --check "${script}" ) > /dev/null 2>&1 && fail "check should fail with no parser block"

    # Freshly generated block is in sync
    updateParser "${script}" > /dev/null
    ( updateParser --check "${script}" ) > /dev/null 2>&1 || fail "check should pass on fresh block"

    # Editing the spec makes the block stale
    gsed -i 's/--name|-n:str/--name|-n:str --force|-f/' "${script}"
    ( updateParser --check "${script}" ) > /dev/null 2>&1 && fail "check should fail on stale block"

    # Regeneration restores sync
    updateParser "${script}" > /dev/null
    ( updateParser --check "${script}" ) > /dev/null 2>&1 || fail "check should pass after regen"
}

testParseArgsWithSpec() {
    local spec=("--name|-n:str" "--force|-f" "audit|update" "str?")

    declare -A expectedOptions=(['name']="Bob" ['force']="1")
    declare -a expectedArgs=("audit" "x")
    parseArgsWithSpec spec -f --name Bob audit x
    assertExpectedParse expectedOptions expectedArgs

    # Enum, required, and unknown arg checks all apply
    assertGenParseFailsWith "must be one of: audit|update" bogus
    local err
    err=${ ( parseArgsWithSpec spec ) 2>&1; }
    assertContains "missing required argument" "${err}"
    err=${ ( parseArgsWithSpec spec audit x y ) 2>&1; }
    assertContains "unknown argument: y" "${err}"
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
    benchmark _benchWithSpec  ${iterations} "generate+parse" "${args[@]}"
    benchmark parseArgs       ${iterations} "generated"      "${args[@]}"
    benchmark _benchHandCoded ${iterations} "hand-coded"     "${args[@]}"
    echo
}

_benchWithSpec() {
    local spec=("--name|-n:str" "--force|-f" "--count|-c:+int" "bool" "*")
    parseArgsWithSpec spec "$@"
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

_assertMinStringLength4() {
    (( ${#1} > 3 )) || fail "$1 must be 4 characters or longer"
}

source rayvn.up 'rayvn/test' 'rayvn/args'
main "$@"
