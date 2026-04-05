#!/usr/bin/env bash

main() {
    init "$@"

    testHashString
    testGenerateDescriptionFromName
    testWrapCodeInBackticks
    testRenderDocMarkdownSummary
    testRenderDocMarkdownArgs
    testRenderDocMarkdownArgsWithMetavar
    testRenderDocMarkdownExample
    testRenderDocMarkdownNotes
    testRenderDocMarkdownUsage
    testFlushDocSectionArgsKnownType
    testFlushDocSectionArgsUnknownType
    testFlushDocSectionExample
    testFlushDocSectionNotes
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
}

# ============================================================================
# _hashString
# ============================================================================

testHashString() {
    local h1; h1=${ _hashString 'hello'; }
    local h2; h2=${ _hashString 'hello'; }
    local h3; h3=${ _hashString 'world'; }

    assertEqual "${h1}" "${h2}" "same input produces same hash"
    assertNotEqual "${h1}" "${h3}" "different input produces different hash"
    assertEqual 16 "${#h1}" "hash is 16 hex chars"
}

# ============================================================================
# _generateDescriptionFromName
# ============================================================================

testGenerateDescriptionFromName() {
    local result

    result=${ _generateDescriptionFromName 'assertSomething'; }
    assertContains 'assertion' "${result}" "assert* → assertion description"

    result=${ _generateDescriptionFromName 'ensureDir'; }
    assertContains 'ensure' "${result}" "ensure* → ensure description"

    result=${ _generateDescriptionFromName 'getConfig'; }
    assertContains 'retrieve' "${result}" "get* → retrieve description"

    result=${ _generateDescriptionFromName 'isEnabled'; }
    assertContains 'boolean' "${result}" "is* → boolean description"

    result=${ _generateDescriptionFromName 'makeTempFile'; }
    assertContains 'create' "${result}" "make* → create description"

    result=${ _generateDescriptionFromName 'unknownFunc'; }
    assertContains 'utility' "${result}" "unknown prefix → utility function"
}

# ============================================================================
# _wrapCodeInBackticks
# ============================================================================

testWrapCodeInBackticks() {
    local result

    result=${ _wrapCodeInBackticks 'plain text no code'; }
    assertEqual 'plain text no code' "${result}" "plain text unchanged"

    result=${ _wrapCodeInBackticks 'Use ${myVar} here'; }
    assertContains '`${myVar}`' "${result}" "wraps \${var} in backticks"

    result=${ _wrapCodeInBackticks 'call myFunc() to do it'; }
    assertContains '`myFunc()`' "${result}" "wraps func() in backticks"
}

# ============================================================================
# _renderDocMarkdown — full doc string integration tests
# ============================================================================

testRenderDocMarkdownSummary() {
    local doc=$'◇ Do something useful.\n  Optional extra line.'
    local result; result=${ _renderDocMarkdown "${doc}"; }

    assertContains 'Do something useful.' "${result}" "summary line rendered"
}

testRenderDocMarkdownArgs() {
    local doc=$'◇ My func.\n· ARGS\n\n  name (string)  The name.\n  count (int)    How many.'
    local result; result=${ _renderDocMarkdown "${doc}"; }

    assertContains '*Args*' "${result}" "Args section header rendered"
    assertContains '`name` *(string)*' "${result}" "name arg with type rendered"
    assertContains '`count` *(int)*' "${result}" "count arg with type rendered"
    assertContains 'The name.' "${result}" "arg description included"
}

testRenderDocMarkdownArgsWithMetavar() {
    local doc=$'◇ My func.\n· ARGS\n\n  --error MSG (string)  The error message.'
    local result; result=${ _renderDocMarkdown "${doc}"; }

    assertContains '`--error MSG` *(string)*' "${result}" "flag with metavar rendered in args column"
    assertContains 'The error message.' "${result}" "description in description column"
}

testRenderDocMarkdownExample() {
    local doc=$'◇ My func.\n· EXAMPLE\n\n  myFunc arg1 arg2\n  myFunc --flag'
    local result; result=${ _renderDocMarkdown "${doc}"; }

    assertContains '```bash' "${result}" "example opens code fence"
    assertContains 'myFunc arg1 arg2' "${result}" "example content included"
    assertContains '```' "${result}" "example closes code fence"
}

testRenderDocMarkdownNotes() {
    local doc=$'◇ My func.\n· NOTES\n\n  - First note.\n  - Second note.'
    local result; result=${ _renderDocMarkdown "${doc}"; }

    assertContains '*Notes*' "${result}" "Notes section header rendered"
    assertContains '- First note.' "${result}" "note items rendered as plain markdown"
    # Notes should NOT be in a code fence
    [[ "${result}" != *'```'* ]] || fail "Notes should not be wrapped in code fence"
}

testRenderDocMarkdownUsage() {
    local doc=$'◇ My func.\n· USAGE\n\n  myFunc [OPTIONS] NAME\n\n  --flag  Enable the flag.\n  NAME (string)  The name.'
    local result; result=${ _renderDocMarkdown "${doc}"; }

    assertContains '`myFunc [OPTIONS] NAME`' "${result}" "usage signature rendered"
    assertContains 'usage-signature' "${result}" "usage-signature CSS class applied"
    assertContains 'usage-table' "${result}" "usage-table CSS class applied"
    assertContains '`NAME` *(string)*' "${result}" "typed param rendered in usage table"
}

# ============================================================================
# _flushDocSection — direct section tests
# ============================================================================

testFlushDocSectionArgsKnownType() {
    local -a lines=('  myArg (string)  The argument.')
    local -a out=()
    _flushDocSection ARGS lines out

    local joined="${out[*]}"
    assertContains '`myArg` *(string)*' "${joined}" "arg with known type rendered with type annotation"
    assertContains 'The argument.' "${joined}" "arg description included"
    assertContains 'args-table' "${joined}" "args-table CSS class applied"
}

testFlushDocSectionArgsUnknownType() {
    local -a lines=('  myArg someWord  The argument.')
    local -a out=()
    _flushDocSection ARGS lines out

    local joined="${out[*]}"
    assertContains '`myArg`' "${joined}" "arg name rendered"
    assertContains 'someWord  The argument.' "${joined}" "unknown type treated as description"
}

testFlushDocSectionExample() {
    local -a lines=('' '  myFunc arg1' '' '  myFunc arg2' '')
    local -a out=()
    _flushDocSection EXAMPLE lines out

    local joined="${out[*]}"
    assertContains '```bash' "${joined}" "code fence opened"
    assertContains 'myFunc arg1' "${joined}" "first example line included"
    assertContains 'myFunc arg2' "${joined}" "second example line included"
    assertContains '```' "${joined}" "code fence closed"
}

testFlushDocSectionNotes() {
    local -a lines=('  - First note.' '  - Second note.')
    local -a out=()
    _flushDocSection NOTES lines out

    local joined="${out[*]}"
    assertContains '- First note.' "${joined}" "first note rendered"
    assertContains '- Second note.' "${joined}" "second note rendered"
    [[ "${joined}" != *'```'* ]] || fail "Notes should not produce code fence"
}

source rayvn.up 'rayvn/core' 'rayvn/index' 'rayvn/test'
main "$@"
