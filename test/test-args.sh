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
    testGenParserDefaults
    testGenParserMultipleAliases
    testGenParserExclusionGroups
    testGenParserVariadicOption
    testGenParserDashedNames
    testGenParserVersionType
    testGenCliParser
    testGenCliUsage
    testGenCliNamedMissingArgMessages
    testGenParserFailRoutesToUsage
    testGenParserFailFallback
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

testGenParserDefaults() {
    local spec=("--count|-c:+int=5" "--mode:fast|slow=slow" "--verbose:bool=false" "--name:str")
    evalGeneratedParser spec

    # Unsupplied options arrive pre-populated (bool default converted to 0/1)
    declare -A expectedOptions=(['count']="5" ['mode']="slow" ['verbose']="0")
    declare -a expectedArgs=()
    parseArgs
    assertExpectedParse expectedOptions expectedArgs

    # Supplied values override defaults, in either form
    expectedOptions=(['count']="9" ['mode']="fast" ['verbose']="1")
    parseArgs -c 9 --mode=fast --verbose true
    assertExpectedParse expectedOptions expectedArgs

    # Invalid defaults are rejected at generation time
    local badSpec=("--mode:fast|slow=medium")
    local err; err=${ ( generateParser rayvn badSpec ) 2>&1; }
    assertContains "must be one of: fast|slow" "${err}"

    badSpec=("--force|-f=1")
    err=${ ( generateParser rayvn badSpec ) 2>&1; }
    assertContains "cannot have a default" "${err}"
}

testGenParserMultipleAliases() {
    local spec=("--name|--nm|-n|-N:str" "--force|--frc|-f")
    evalGeneratedParser spec

    declare -A expectedOptions=(['name']="Bob" ['force']="1")
    declare -a expectedArgs=()
    parseArgs -N Bob --frc
    assertExpectedParse expectedOptions expectedArgs

    # The = form works through any long alias; the first name provides the _opts key
    parseArgs --nm=Bob --force
    assertExpectedParse expectedOptions expectedArgs
    assertGenParseFailsWith "does not accept a value" --frc=1
}

testGenParserExclusionGroups() {
    local spec err

    # A group of undeclared simple flags declares them and makes them exclusive
    spec=("[--fix|--ask]" "*")
    evalGeneratedParser spec
    declare -A expectedOptions=(['fix']="1")
    declare -a expectedArgs=("foo")
    parseArgs --fix foo
    assertExpectedParse expectedOptions expectedArgs
    assertGenParseFailsWith "at most one of --fix | --ask" --fix --ask

    # Members may reference declared options by any alias; typed options participate
    spec=("--fix|-f" "--mode:fast|slow" "[-f|--mode]")
    evalGeneratedParser spec
    assertGenParseFailsWith "at most one of --fix | --mode" -f --mode fast
    expectedOptions=(['mode']="fast")
    expectedArgs=()
    parseArgs --mode fast
    assertExpectedParse expectedOptions expectedArgs

    # Three-way group
    spec=("[--setup|--record|--publish]")
    evalGeneratedParser spec
    assertGenParseFailsWith "at most one of --setup | --record | --publish" --setup --publish
    expectedOptions=(['publish']="1")
    parseArgs --publish
    assertExpectedParse expectedOptions expectedArgs

    # The check is waived when --help is parsed
    spec=("[--fix|--ask]" "--help|-h")
    evalGeneratedParser spec
    parseArgs --fix --ask --help
    (( _opts['help'] )) || fail "help should be set"

    # A member with a default is rejected at generation time
    spec=("--mode:fast|slow=slow" "[--mode|--other]")
    err=${ ( generateParser rayvn spec ) 2>&1; }
    assertContains "cannot be in an exclusion group" "${err}"

    # Single-member groups are rejected
    spec=("[--fix]")
    err=${ ( generateParser rayvn spec ) 2>&1; }
    assertContains "must name at least two options" "${err}"
}

testGenParserVariadicOption() {
    local spec err

    # Basic consumption: greedily collects values, stopping at the next option-like token;
    # _opts still marks presence, the values land in a dedicated _optListName array
    spec=("--record:str*" "--force|-f")
    evalGeneratedParser spec
    declare -A expectedOptions=(['record']="1" ['force']="1")
    declare -a expectedArgs=()
    parseArgs --record id1 id2 --force
    assertExpectedParse expectedOptions expectedArgs
    assertEqual "${_optListRecord[*]}" "id1 id2" "variadic values"

    # Bare invocation: present, but with an empty list
    parseArgs --record
    assertEqual "${_opts['record']}" "1" "bare --record sets presence"
    assertEqual "${#_optListRecord[@]}" "0" "bare --record collects nothing"

    # The '=' form sets a single-element list
    parseArgs --record=onlyone
    assertEqual "${_optListRecord[*]}" "onlyone" "= form single value"

    # Resets on every parse, even when the option isn't supplied at all (no stale values
    # left over from a previous call)
    parseArgs --force
    assertEqual "${#_optListRecord[@]}" "0" "_optListRecord reset when --record absent"

    # Each value is type-checked, same as a scalar option
    spec=("--nums:int*")
    evalGeneratedParser spec
    parseArgs --nums 1 2 3
    assertEqual "${_optListNums[*]}" "1 2 3" "typed variadic values"
    assertGenParseFailsWith "must be a positive or negative integer" --nums 1 abc

    # Enum types work too
    spec=("--mode:fast|slow*")
    evalGeneratedParser spec
    parseArgs --mode fast slow
    assertEqual "${_optListMode[*]}" "fast slow" "enum variadic values"
    assertGenParseFailsWith "must be one of: fast|slow" --mode fast bogus

    # Dashes in the option name become underscores in the array's variable name
    spec=("--exclude-pattern:str*")
    evalGeneratedParser spec
    parseArgs --exclude-pattern a b
    assertEqual "${_optListExcludePattern[*]}" "a b" "dashed variadic option array name"

    # A variadic option cannot have a default
    spec=("--record:str*=x")
    err=${ ( generateParser rayvn spec ) 2>&1; }
    assertContains "cannot have a default value" "${err}"
}

testGenParserVersionType() {
    local spec=("version")
    evalGeneratedParser spec

    declare -A expectedOptions=()
    declare -a expectedArgs=("1.2.3")
    parseArgs 1.2.3
    assertExpectedParse expectedOptions expectedArgs

    expectedArgs=("1.2.3-alpha.1+build.5")
    parseArgs 1.2.3-alpha.1+build.5
    assertExpectedParse expectedOptions expectedArgs

    assertGenParseFailsWith "must be a semantic version" 1.2
    assertGenParseFailsWith "must be a semantic version" v1.2.3
    assertGenParseFailsWith "must be a semantic version" abc
}

testGenParserDashedNames() {
    # Dashed long names must produce distinct _opts keys ('no-compact', not 'compact')
    local spec=("--compact:str" "--no-compact" "--hash-file:str")
    evalGeneratedParser spec

    declare -A expectedOptions=(['compact']="a" ['no-compact']="1" ['hash-file']="b")
    declare -a expectedArgs=()
    parseArgs --compact a --no-compact --hash-file b
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

testGenCliUsage() {
    local dir; dir=${ makeTempDir; }
    local script="${dir}/usage.sh"
    cat > "${script}" << 'EOF'
#!/usr/bin/env bash

# rayvn:cli usageSpec
declare -gA usageSpec=(
    # Scan things for problems.
    #   PROJECT...   Project names (default: current).
    #   --fix        Auto-fix problems.
    #   --ask        Prompt per file.
    ['lint']='lint([--fix|--ask] --help|-h *)'

    # Create a new thing.
    #   TYPE         One of a, b or c.
    #   NAME         The name to create.
    #   --repo|-r    Target repo.
    ['new']='new(a|b|c str --repo|-r:str=my/repo --help|-h)'

    # rayvn:usage hand-written
    ['manual']='manual(--help|-h *)'
)
EOF
    updateParser "${script}" > /dev/null
    eval "${ gawk '/^ARGS_PARSER_BEGIN=/{f=1} f{print} /^ARGS_PARSER_END=/{f=0}' "${script}"; }"

    # Rendered output: synopsis, summary, aligned entries, default text, auto --help
    local out
    out=${ ( newCmdUsage ) 2>&1; }
    assertContains "new TYPE NAME [--repo REPO]" "${out}"
    assertContains "Create a new thing." "${out}"
    assertContains "--repo, -r REPO" "${out}"
    assertContains "(default: my/repo)" "${out}"
    assertContains "--help, -h" "${out}"

    out=${ ( lintCmdUsage ) 2>&1; }
    assertContains "lint [PROJECT...] [--fix | --ask]" "${out}"
    assertContains "Auto-fix problems." "${out}"

    # The 'rayvn:usage hand-written' marker suppresses generation
    grep -q 'manualCmdUsage()' "${script}" && fail "usage function should not be generated for hand-written marker"

    # The Extra hook is called when defined
    lintCmdUsageExtra() { echo "EXTRA CONTENT"; }
    out=${ ( lintCmdUsage ) 2>&1; }
    assertContains "EXTRA CONTENT" "${out}"
    unset -f lintCmdUsageExtra

    # Doc validation errors at generation time
    declare -A _argsCliDocs
    declare -A errSpec=(['list']='list(--verbose --help|-h)')
    local err

    _argsCliDocs=(['list']=$'Summary.\n  --bogus  Nope.')
    err=${ ( generateParser rayvn errSpec ) 2>&1; }
    assertContains "unknown option '--bogus'" "${err}"

    _argsCliDocs=(['list']=$'Summary.')
    err=${ ( generateParser rayvn errSpec ) 2>&1; }
    assertContains "is not documented" "${err}"

    declare -A posSpec=(['add']='add(str --help|-h)')
    _argsCliDocs=(['add']=$'Summary.')
    err=${ ( generateParser rayvn posSpec ) 2>&1; }
    assertContains "must name all 1 positional" "${err}"
}

testGenCliNamedMissingArgMessages() {
    local dir; dir=${ makeTempDir; }
    local script="${dir}/named.sh"
    cat > "${script}" << 'EOF'
#!/usr/bin/env bash

# rayvn:cli namedSpec
declare -gA namedSpec=(
    # Single required positional.
    #   SCRIPT  Single required positional.
    ['one']='one(file --help|-h)'

    # Two required positionals.
    #   TYPE  First of two required positionals.
    #   NAME  Second of two required positionals.
    ['two']='two(str str --help|-h)'
)
EOF
    updateParser "${script}" > /dev/null
    eval "${ gawk '/^ARGS_PARSER_BEGIN=/{f=1} f{print} /^ARGS_PARSER_END=/{f=0}' "${script}"; }"

    oneCmd() { :; }
    twoCmd() { :; }

    local out
    out=${ ( parseCommand one ) 2>&1; }
    assertContains "missing required argument: SCRIPT" "${out}"

    out=${ ( parseCommand two ) 2>&1; }
    assertContains "missing required arguments: TYPE NAME" "${out}"

    out=${ ( parseCommand two first ) 2>&1; }
    assertContains "missing required argument: NAME" "${out}"

    # Standalone argument-spec parsers have no doc-derived names, so the message stays generic
    local spec=("str" "str")
    evalGeneratedParser spec
    local err; err=${ ( parseArgs ) 2>&1; }
    assertContains "missing required arguments: expected at least 2" "${err}"
}

testGenParserFailRoutesToUsage() {
    declare -A cliSpec=(['rel']='rel(version --help|-h)')
    local parser; parser="${ generateParser rayvn cliSpec; }"
    eval "${parser}"

    local relCalled=0
    relCmd() { relCalled=1; }
    relCmdUsage() { echo "USAGE_MARKER"; echo "rayvn rel VERSION"; bye "$@"; }

    # Missing required positional routes to the command's usage, not a bare fail
    local out
    out=${ ( parseCommand rel ) 2>&1; }
    assertContains "USAGE_MARKER" "${out}"
    assertContains "missing required argument" "${out}"

    # A type-check failure (the 'version' type calls assertVersion, a shared core.sh
    # function that calls fail() itself) also routes — the hook lives in fail(), so it
    # catches this without any special-casing in the generator
    out=${ ( parseCommand rel abc ) 2>&1; }
    assertContains "USAGE_MARKER" "${out}"
    assertContains "must be a semantic version" "${out}"

    (( relCalled == 0 )) || fail "relCmd should not have been called on a parse failure"

    # A successful parse must restore _failHandler, not leave it set for unrelated
    # later fail() calls in the command's own body
    parseCommand rel 1.2.3
    (( relCalled )) || fail "relCmd was not called on successful parse"
    [[ -z "${_failHandler}" ]] || fail "_failHandler leaked after a successful parse: '${_failHandler}'"

    # Standalone argument-spec parsers route to the script's own usage() if one is defined
    local spec=("str")
    evalGeneratedParser spec
    usage() { echo "TOP_USAGE_MARKER"; bye "$@"; }
    out=${ ( parseArgs ) 2>&1; }
    assertContains "TOP_USAGE_MARKER" "${out}"
    assertContains "missing required argument" "${out}"
    unset -f usage
}

testGenParserFailFallback() {
    # Without a usage() function defined, standalone parsers fall back to the default
    # fail() behavior (a bare error) rather than crashing on an undefined function call
    local spec=("str")
    evalGeneratedParser spec
    unset -f usage 2> /dev/null
    local err
    err=${ ( parseArgs ) 2>&1; }
    assertContains "missing required argument" "${err}"
    [[ "${err}" != *"command not found"* ]] || fail "calling undefined usage() crashed: ${err}"
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
