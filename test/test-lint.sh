#!/usr/bin/env bash

# Project name and root used across all tests (unique per process)
lintTestProject="lint-test-${$}"
lintTestRoot=''

main() {
    init "$@"

    testLintCleanFile
    testLintDetectsBracedPositional
    testLintDetectsBracedSpecial
    testLintDetectsStrictMode
    testLintDetectsOldStyleCommandSub
    testLintDetectsMissingSpaces
    testLintDetectsNonCamelCase
    testLintDetectsNonCamelCaseVar
    testLintDetectsNonRefNameref
    testLintDetectsBareNamedVar
    testLintFixesBracedPositional
    testLintFixesSpacing
    testLintFixesStrictMode
    testLintUnregisteredProject
}

init() {
    lintTestRoot=${ makeTempDir lint-test-XXXXXX; }
    ensureDir "${lintTestRoot}/lib"
    addRayvnProject "${lintTestProject}" "${lintTestRoot}"

    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
}

# Write a bash shebang file to the test project lib dir
_writeLintFixture() {
    local name="$1"
    local content="$2"
    local file="${lintTestRoot}/lib/${name}"
    printf '#!/usr/bin/env bash\n%s\n' "${content}" > "${file}"
    echo "${file}"
}

# ============================================================================
# Basic detection tests
# ============================================================================

testLintCleanFile() {
    _writeLintFixture "clean.sh" 'myFunc() {
    local val="$1"
    [[ -n "${val}" ]] && echo "${val}"
}' > /dev/null
    assertTrue "runLint passes on clean file" runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsBracedPositional() {
    _writeLintFixture "braced-pos.sh" 'myFunc() { echo ${1}; }' > /dev/null
    assertFalse "runLint detects \${1} braced positional param" runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsBracedSpecial() {
    _writeLintFixture "braced-special.sh" 'myFunc() { echo ${@}; }' > /dev/null
    assertFalse "runLint detects \${@} braced special param" runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsStrictMode() {
    _writeLintFixture "strict.sh" 'set -e' > /dev/null
    assertFalse "runLint detects set -e strict mode" runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsOldStyleCommandSub() {
    _writeLintFixture "oldsub.sh" 'myFunc() { local x=$(echo hi); }' > /dev/null
    assertFalse "runLint detects old-style \$(cmd) command substitution" runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsMissingSpaces() {
    _writeLintFixture "spaces.sh" 'myFunc() { if [[ ! -z "$1" ]]; then echo hi; fi; }' > /dev/null
    assertFalse "runLint detects missing space after [[ " runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsNonCamelCase() {
    _writeLintFixture "snake.sh" 'my_func() { echo hi; }' > /dev/null
    assertFalse "runLint detects snake_case function name" runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsNonCamelCaseVar() {
    _writeLintFixture "snake-var.sh" $'myFunc() {\n    local my_var="x"\n}' > /dev/null
    assertFalse "runLint detects snake_case variable name" runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsNonRefNameref() {
    _writeLintFixture "nameref.sh" $'myFunc() {\n    local -n target=$1\n}' > /dev/null
    assertFalse "runLint detects nameref not ending in Ref" runLint "${lintTestProject}" 2>/dev/null
}

testLintDetectsBareNamedVar() {
    _writeLintFixture "bare-var.sh" 'myFunc() { local foo=1; echo $foo; }' > /dev/null
    assertFalse "runLint detects bare named var without \${}" runLint "${lintTestProject}" 2>/dev/null
}

# ============================================================================
# Auto-fix tests (write only a fixable file, verify --fix passes)
# ============================================================================

testLintFixesBracedPositional() {
    rm -f "${lintTestRoot}"/lib/*.sh
    local file; file=${ _writeLintFixture "fix-pos.sh" 'myFunc() { echo ${1}; }'; }
    assertTrue "runLint --fix corrects \${1}" runLint --fix "${lintTestProject}" 2>/dev/null
    assertInFile '$1' "${file}"
    assertNotInFile '${1}' "${file}"
}

testLintFixesSpacing() {
    rm -f "${lintTestRoot}"/lib/*.sh
    local file; file=${ _writeLintFixture "fix-space.sh" 'myFunc() { (( x=1 )); }'; }
    # lint-ok
    assertTrue "runLint --fix corrects (( spacing" runLint --fix "${lintTestProject}" 2>/dev/null
}

testLintFixesStrictMode() {
    rm -f "${lintTestRoot}"/lib/*.sh
    local file; file=${ _writeLintFixture "fix-strict.sh" $'set -e\nmyFunc() { echo hi; }'; }
    assertTrue "runLint --fix removes strict mode line" runLint --fix "${lintTestProject}" 2>/dev/null
    assertNotInFile 'set -e' "${file}"
}

# ============================================================================
# Error cases
# ============================================================================

testLintUnregisteredProject() {
    assertFalse "runLint fails for unregistered project" \
        eval "( runLint 'no-such-project-xyz' ) 2>/dev/null"
}

source rayvn.up 'rayvn/core' 'rayvn/lint' 'rayvn/test'
main "$@"
