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
    testFlushDocSectionUsagePipes
    testFlushDocSectionArgsEnumType
    testTableCellText
    testFlushDocSectionContinuationLines
    testIsDocType
    testFindInvalidDocEntries
    testFlushDocSectionPathAndEnumTypes
    testFlushDocSectionExample
    testFlushDocSectionNotes
    testSyncSharedPagesFiles
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

    assertContains '*args*' "${result}" "Args section header rendered"
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

    assertContains '*notes*' "${result}" "Notes section header rendered"
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

# A '|' must not end a table cell: other forms of the call signature become code, and other text is escaped.

testFlushDocSectionUsagePipes() {
    local -a lines=('  encrypt [INPUT | -v NAME] (-r RECIPIENT)... [-o PATH]' '  encrypt [INPUT | -v NAME] --passphrase [-o PATH]'
                    '  -o, --output PATH  Write to PATH, or - for standard output.')
    local -a out=()
    _flushDocSection USAGE lines out

    local joined="${out[*]}"
    assertContains '| `encrypt` | `[INPUT | -v NAME] --passphrase [-o PATH]` |' "${joined}" "another usage form must be code"
    assertContains '| `-o, --output PATH` | Write to PATH, or - for standard output. |' "${joined}" "short and long option names must share a cell"
}

testFlushDocSectionArgsEnumType() {
    local -a lines=("  [useCase] ('account'|'file')  What it protects.")
    local -a out=()
    _flushDocSection ARGS lines out

    assertContains "| \`[useCase]\` *('account'\\|'file')* | What it protects. |" "${out[*]}" "an enum type's '|' must be escaped"
}

# Wrapped descriptions (lines starting with whitespace) continue the previous row, in both usage and args tables.

testFlushDocSectionContinuationLines() {
    local -a lines=('  myFunc [-o PATH]' '  -o, --output PATH  Write the result to PATH. Any existing file' '                     will be overwritten.')
    local -a out=()
    _flushDocSection USAGE lines out
    assertContains '| `-o, --output PATH` | Write the result to PATH. Any existing file will be overwritten. |' "${out[*]}"

    lines=('  name (string)  The name, which' '                 can be long.')
    out=()
    _flushDocSection ARGS lines out
    assertContains '| `name` *(string)* | The name, which can be long. |' "${out[*]}"
}

testIsDocType() {
    local type
    for type in string int bool file dir exe stringRef intRef arrayRef mapRef fnRef "'a'|'b'" "'account'|'file'|'other'"; do
        assertTrue "${type} must be a doc type" _isDocType "${type}"
    done
    for type in flag args 'string...' path "'a'" "a|b" ''; do
        assertFalse "'${type}' must not be a doc type" _isDocType "${type}"
    done
}

testFindInvalidDocEntries() {
    local file; file=${ makeTempFile; }
    cat > "${file}" << 'EOF'
# ◇ Do things.
#
# · ARGS
#
#   name (string)      The name.
#   path (path)        Not a type.
#
# · USAGE
#
#   things [--count N] name
#
#   --count N (count)  Not a type either.
#   [-v] (bool)        A bracketed option.
#   [name] (string)    An optional positional, which is fine.
#   mode ('a'|'b')     An enum.

things() {
    : # (string)  outside a doc comment is ignored
}
EOF
    local -a found=(); mapfile -t found < <(_findInvalidDocEntries "${file}")
    assertEqual 3 "${#found[@]}" "three problems: ${found[*]}"
    assertEqual "${file}:6:unknown type (path)" "${found[0]}"
    assertEqual "${file}:12:unknown type (count)" "${found[1]}"
    assertEqual "${file}:13:bracketed option ([-v])" "${found[2]}"
}

testFlushDocSectionPathAndEnumTypes() {
    local -a lines=('  script (exe)  The script.' '  dir (dir)  The directory.' "  mode ('a'|'b')  The mode.")
    local -a out=()
    _flushDocSection ARGS lines out
    local joined="${out[*]}"
    assertContains '| `script` *(exe)* | The script. |' "${joined}"
    assertContains '| `dir` *(dir)* | The directory. |' "${joined}"
    assertContains "| \`mode\` *('a'\\|'b')* | The mode. |" "${joined}"
}

testTableCellText() {
    assertEqual 'Use `--armor` or `-a` (default: `-o`).' "${ _tableCellText 'Use --armor or -a (default: -o).'; }"
    assertEqual 'a \| b and `c|d`' "${ _tableCellText 'a | b and `c|d`'; }"
    assertEqual 'x-ray and well-known' "${ _tableCellText 'x-ray and well-known'; }"
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

# ============================================================================
# _syncSharedPagesFiles
# ============================================================================

testSyncSharedPagesFiles() {
    local site; site=${ makeTempDir; }
    local sharedDir="${rayvnHome}/etc/pages"
    local output; output=${ _syncSharedPagesFiles "${site}"; }
    assertContains "Created _sass/custom/custom.scss" "${output}"
    assertEqual '' "${ diff -r "${sharedDir}" "${site}"; }" "every shared file must be copied"

    output=${ _syncSharedPagesFiles "${site}"; }
    assertEqual '' "${output}" "an up to date site must not be changed"

    echo 'edited by hand' >> "${site}/_includes/head_custom.html"
    echo 'site specific' > "${site}/_includes/site_only.html"
    output=${ _syncSharedPagesFiles "${site}"; }
    assertEqual "Updated _includes/head_custom.html" "${output}"
    assertEqual '' "${ diff "${sharedDir}/_includes/head_custom.html" "${site}/_includes/head_custom.html"; }" "a changed copy must be restored"
    assertEqual 'site specific' "${ cat "${site}/_includes/site_only.html"; }" "site-specific files must be left alone"
}

source rayvn.up 'rayvn/core' 'rayvn/index' 'rayvn/test'
main "$@"
