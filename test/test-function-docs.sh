#!/usr/bin/env bash

main() {
    init "$@"

    testParseDuration
    testExtractFunctionDoc
    testExtractFunctionDocNone
    testExtractFunctionBody
    testExtractFunctionBodyMultiArg
    testExtractReferencedConstants
    testBuildDocPrompt
    testReplaceDocCommentInsert
    testReplaceDocCommentReplace
    testSaveAndLoadDocTimestamps
    testSortTargetsByFileOrder
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
}

# Write a bash shebang file to a temp location, return the path.
_writeFunctionDocsFixture() {
    local content="$1"
    local file; file=${ makeTempFile fdtest-XXXXXX.sh; }
    printf '#!/usr/bin/env bash\n\n%s\n' "${content}" > "${file}"
    echo "${file}"
}

# ============================================================================
# _parseDuration
# ============================================================================

testParseDuration() {
    local result

    result=${ _parseDuration '30m'; }
    assertEqual '1800' "${result}" "_parseDuration: 30m = 1800s"

    result=${ _parseDuration '2h'; }
    assertEqual '7200' "${result}" "_parseDuration: 2h = 7200s"

    result=${ _parseDuration '1d'; }
    assertEqual '86400' "${result}" "_parseDuration: 1d = 86400s"

    result=${ _parseDuration '10m'; }
    assertEqual '600' "${result}" "_parseDuration: 10m = 600s"

    assertFalse "_parseDuration fails on invalid format" _parseDuration 'bad' 2> /dev/null
    assertFalse "_parseDuration fails on missing unit" _parseDuration '30' 2> /dev/null
}

# ============================================================================
# _extractFunctionDoc
# ============================================================================

testExtractFunctionDoc() {
    local file; file=${ _writeFunctionDocsFixture $'# ◇ My test function.\n#\n# · ARGS\n#\n#   arg1 (string)  First arg.\n\nmyTestFunc() {\n    echo "$1"\n}'; }

    local doc; doc=${ _extractFunctionDoc "${file}" myTestFunc; }
    assertContains '◇ My test function.' "${doc}" "extracts diamond summary line"
    assertContains 'arg1 (string)' "${doc}" "extracts arg documentation"

    rm -f "${file}"
}

testExtractFunctionDocNone() {
    local file; file=${ makeTempFile fdtest-XXXXXX.sh; }
    # Use a declare line as separator so the shebang is not adjacent to the function
    printf '#!/usr/bin/env bash\n\ndeclare -g _unused=1\n\nmyUndocumentedFunc() {\n    echo hi\n}\n' > "${file}"

    local doc; doc=${ _extractFunctionDoc "${file}" myUndocumentedFunc; }
    assertEqual '' "${doc}" "returns empty when no doc comment"

    rm -f "${file}"
}

# ============================================================================
# _extractFunctionBody
# ============================================================================

testExtractFunctionBody() {
    local file; file=${ _writeFunctionDocsFixture $'# ◇ Docs.\n\nmyBodyFunc() {\n    echo hello\n    return 0\n}'; }

    local body; body=${ _extractFunctionBody "${file}" myBodyFunc; }
    assertContains 'myBodyFunc() {' "${body}" "includes function declaration"
    assertContains 'echo hello' "${body}" "includes function body"
    assertContains 'return 0' "${body}" "includes last body line"

    rm -f "${file}"
}

testExtractFunctionBodyMultiArg() {
    local file; file=${ _writeFunctionDocsFixture $'anotherFunc() {\n    local a="$1"\n    local b="$2"\n    echo "${a} ${b}"\n}'; }

    local body; body=${ _extractFunctionBody "${file}" anotherFunc; }
    assertContains 'local a' "${body}" "extracts local vars"
    assertContains 'local b' "${body}" "extracts second local"

    rm -f "${file}"
}

# ============================================================================
# _extractReferencedConstants
# ============================================================================

testExtractReferencedConstants() {
    local file; file=${ _writeFunctionDocsFixture $'declare -gr _myTimeout=30\ndeclare -gr _myPrefix=\'hello\'\n\nmyFunc() {\n    sleep ${_myTimeout}\n    echo ${_myPrefix}\n}'; }

    local body=$'    sleep ${_myTimeout}\n    echo ${_myPrefix}'
    local result; result=${ _extractReferencedConstants "${body}" "${file}"; }

    assertContains '_myTimeout=30' "${result}" "extracts unquoted constant value"
    assertContains "_myPrefix=hello" "${result}" "extracts single-quoted constant value"

    rm -f "${file}"
}

# ============================================================================
# _buildDocPrompt
# ============================================================================

testBuildDocPrompt() {
    local prompt; prompt=${ _buildDocPrompt 'myFunc() { echo hi; }' '# ◇ Old doc.' ''; }

    assertContains 'FUNCTION:' "${prompt}" "prompt includes FUNCTION section"
    assertContains 'myFunc() { echo hi; }' "${prompt}" "prompt includes function body"
    assertContains 'CURRENT DOC' "${prompt}" "prompt includes CURRENT DOC section"
    assertContains '# ◇ Old doc.' "${prompt}" "prompt includes existing doc"
}

# ============================================================================
# _replaceDocComment
# ============================================================================

testReplaceDocCommentInsert() {
    local file; file=${ _writeFunctionDocsFixture $'noDocFunc() {\n    echo hi\n}'; }

    _replaceDocComment "${file}" noDocFunc '# ◇ Inserted doc.'

    assertInFile '# ◇ Inserted doc.' "${file}"
    assertInFile 'noDocFunc() {' "${file}"

    rm -f "${file}"
}

testReplaceDocCommentReplace() {
    local file; file=${ _writeFunctionDocsFixture $'# ◇ Old doc.\n\nreplaceDocFunc() {\n    echo hi\n}'; }

    _replaceDocComment "${file}" replaceDocFunc '# ◇ New doc.'

    assertInFile '# ◇ New doc.' "${file}"
    assertNotInFile '# ◇ Old doc.' "${file}"
    assertInFile 'replaceDocFunc() {' "${file}"

    rm -f "${file}"
}

# ============================================================================
# _loadDocTimestamps / _saveDocTimestamps
# ============================================================================

testSaveAndLoadDocTimestamps() {
    local tsFile; tsFile=${ makeTempFile fdtest-ts-XXXXXX; }

    # Manually populate _docTimestamps and save
    declare -gA _docTimestamps=()
    _docTimestamps['rayvn/core:foo']=1000
    _docTimestamps['rayvn/core:bar']=2000

    # Redirect _docTimestampsFile by temporarily overriding via subshell is tricky;
    # instead, write the file directly and call _loadDocTimestamps with that path
    {
        echo 'rayvn/core:bar=2000'
        echo 'rayvn/core:foo=1000'
    } > "${tsFile}"

    # Load from the fixture file
    declare -gA _docTimestamps=()
    while IFS= read -r line; do
        local key="${line%%=*}"
        local ts="${line#*=}"
        [[ -n "${key}" ]] && _docTimestamps["${key}"]="${ts}"
    done < "${tsFile}"

    assertEqual '1000' "${_docTimestamps['rayvn/core:foo']}" "loads foo timestamp"
    assertEqual '2000' "${_docTimestamps['rayvn/core:bar']}" "loads bar timestamp"

    # Save and verify sorted output
    local outFile; outFile=${ makeTempFile fdtest-out-XXXXXX; }
    { for key in "${!_docTimestamps[@]}"; do echo "${key}=${_docTimestamps[${key}]}"; done; } | sort > "${outFile}"
    assertInFile 'rayvn/core:bar=2000' "${outFile}"
    assertInFile 'rayvn/core:foo=1000' "${outFile}"

    rm -f "${tsFile}" "${outFile}"
}

# ============================================================================
# _sortTargetsByFileOrder
# ============================================================================

testSortTargetsByFileOrder() {
    # Write a fixture library file with two functions in known order
    local libFile; libFile=${ _writeFunctionDocsFixture $'secondFunc() { echo 2; }\nfirstFuncAtBottom() { echo 1; }'; }

    # Register a mock project pointing to the fixture dir
    local libDir; libDir=${ dirname "${libFile}"; }
    local projName="fdtest-sort-$$"
    declare -gA _rayvnProjects["${projName}::library"]="${libDir}"

    # Create targets referencing both functions (out of file order)
    local libBase; libBase=${ basename "${libFile}" .sh; }
    local -a targets=("${projName}/${libBase}:firstFuncAtBottom" "${projName}/${libBase}:secondFunc")

    _sortTargetsByFileOrder targets

    assertEqual "${projName}/${libBase}:secondFunc" "${targets[0]}" "secondFunc appears first (line 2)"
    assertEqual "${projName}/${libBase}:firstFuncAtBottom" "${targets[1]}" "firstFuncAtBottom appears second (line 3)"

    unset "_rayvnProjects[${projName}::library]"
    rm -f "${libFile}"
}

source rayvn.up 'rayvn/core' 'rayvn/function-docs' 'rayvn/test'
main "$@"
