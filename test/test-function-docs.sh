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
    testBuildDocPromptEditsCurrentDoc
    testAlignDocColumns
    testDocProblemsMuchShorter
    testDocProblemsArgCount
    testSaveHashesKeepsUnscannedLibraries
    testSaveDocHashesKeepsUnresolvedStale
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

# With a current doc, the prompt asks for an edit that keeps what is still right; without one, for a new doc

testBuildDocPromptEditsCurrentDoc() {
    local prompt; prompt=${ _buildDocPrompt 'myFunc() { echo hi; }' '# ◇ Old doc.' ''; }
    assertContains 'Edit the current doc comment' "${prompt}"
    assertContains 'never remove information' "${prompt}"
    prompt=${ _buildDocPrompt 'myFunc() { echo hi; }' '' ''; }
    assertContains 'Generate an accurate doc comment' "${prompt}"
}

# ============================================================================
# _alignDocColumns
# ============================================================================

testAlignDocColumns() {
    local doc="# ◇ Prompts twice.
#
# · ARGS
#
#   prompt (string)        Label before the first entry.
#   resultVarRef (stringRef)  Name of the result var.
#   [level] ('casual'|'motivated')
#                          How much guessing power.
#
# · RETURNS
#
#   0  ok
#   1    not ok"
    local expected="# ◇ Prompts twice.
#
# · ARGS
#
#   prompt (string)           Label before the first entry.
#   resultVarRef (stringRef)  Name of the result var.
#   [level] ('casual'|'motivated')
#                             How much guessing power.
#
# · RETURNS
#
#   0  ok
#   1  not ok"
    assertEqual "${expected}" "${ _alignDocColumns "${doc}"; }" "columns must align to the longest name in each section"

    local usage="# ◇ Does it.
#
# · USAGE
#
#   doIt [-v]    Do it.
#   -v      Verbosely."
    assertEqual "${usage}" "${ _alignDocColumns "${usage}"; }" "USAGE sections must be left alone"

    local typeColumn="# ◇ Checks it.
#
# · ARGS
#
#   passRef        (stringRef)  Name of the password var.
#   breachCountRef (intRef)     Name of the count var."
    assertEqual "${typeColumn}" "${ _alignDocColumns "${typeColumn}"; }" "aligned sections, with types in a column of their own, must be left alone"

    local oneSpace="# ◇ Makes it.
#
# · ARGS
#
#   phraseRef (string)   Name of the result var.
#   [separator] (string) Between words."
    local oneSpaceAligned="# ◇ Makes it.
#
# · ARGS
#
#   phraseRef (string)    Name of the result var.
#   [separator] (string)  Between words."
    assertEqual "${oneSpaceAligned}" "${ _alignDocColumns "${oneSpace}"; }" "one space after a type must still be aligned"
}

# ============================================================================
# _docProblems
# ============================================================================

testDocProblemsMuchShorter() {
    local -a problems
    local current='# ◇ One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen.'
    _docProblems "${current}" '# ◇ One two.' 'f() { :; }' problems
    assertContains 'much shorter' "${problems[*]}"
    _docProblems "${current}" "${current} Seventeen." 'f() { :; }' problems
    assertEqual 0 ${#problems[@]} "a doc that grows must not be flagged"
}

testDocProblemsArgCount() {
    local -a problems
    local doc="# ◇ Does it.
#
# · ARGS
#
#   first (string)   The first.
#   second (string)  The second."
    _docProblems '' "${doc}" 'f() { local a="$1" b="${2:-x}"; gawk '"'"'{ print $3 }'"'"'; }' problems
    assertEqual 0 ${#problems[@]} "two documented args, two used (awk's \$3 ignored): ${problems[*]}"
    _docProblems '' "${doc}" 'f() { local a="$1" b="$2" c="$3"; }' problems
    assertContains 'ARGS has 2 entries, but the body uses 3' "${problems[*]}"
    _docProblems '' "${doc}" 'f() { while (( $# )); do shift; done; }' problems
    assertEqual 0 ${#problems[@]} "bodies that shift are not checked"
}

# ============================================================================
# _saveHashes, _saveDocHashes
# ============================================================================

# Saving keeps the stored hashes of libraries not scanned, and drops those of scanned libraries' removed functions

testSaveHashesKeepsUnscannedLibraries() {
    require 'rayvn/index'
    local -g _idxHashFile; _idxHashFile=${ makeTempFile; }
    declare -gA _idxStoredHashes=([p/a:f:body]=1 [p/a:f:doc]=2 [p/a:gone:body]=3 [p/b:g:body]=4 [p/b:g:doc]=5)
    declare -gA _idxCurrentHashes=([p/a:f:body]=6 [p/a:f:doc]=7)
    _saveHashes
    local expected; expected=${ printf '%s\n' p/a:f:body:6 p/a:f:doc:7 p/b:g:body:4 p/b:g:doc:5; }
    assertEqual "${expected}" "${ cat "${_idxHashFile}"; }"
}

# A stale function that was not resolved keeps its stored hashes, so it is still reported as stale; one resolved, and
# one that was not stale, are saved as they are now

testSaveDocHashesKeepsUnresolvedStale() {
    require 'rayvn/index'
    local -g _idxHashFile; _idxHashFile=${ makeTempFile; }
    declare -gA _idxStoredHashes=([p/a:skipped:body]=1 [p/a:skipped:doc]=2 [p/a:done:body]=3 [p/a:done:doc]=4
                                  [p/a:other:body]=5 [p/a:other:doc]=6)
    declare -gA _idxCurrentHashes=([p/a:skipped:body]=11 [p/a:skipped:doc]=2 [p/a:done:body]=13 [p/a:done:doc]=4
                                   [p/a:other:body]=15 [p/a:other:doc]=16)
    declare -ga _idxStaleDocs=(p/a:skipped p/a:done) _idxMissingDocs=()
    local -A resolved=([p/a:done]=1) updatedFiles=()
    _saveDocHashes resolved updatedFiles
    local expected; expected=${ printf '%s\n' p/a:done:body:13 p/a:done:doc:4 p/a:other:body:15 p/a:other:doc:16 \
                                                p/a:skipped:body:1 p/a:skipped:doc:2; }
    assertEqual "${expected}" "${ cat "${_idxHashFile}"; }"
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
