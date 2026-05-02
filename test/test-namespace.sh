#!/usr/bin/env bash

nsProjectA="ns-test-a-${$}"
nsProjectB="ns-test-b-${$}"
nsRootA=''
nsRootB=''

main() {
    init "$@"

    testNoCollisions
    testFunctionCollision
    testVariableCollision
    testSkipBlock
    testNamespaceOkLine
    testSameFileDuplicateNotCollision
    testSingleProjectNoCollision
}

init() {
    nsRootA=${ makeTempDir ns-test-a-XXXXXX; }
    nsRootB=${ makeTempDir ns-test-b-XXXXXX; }
    ensureDir "${nsRootA}/lib"
    ensureDir "${nsRootB}/lib"
    addRayvnProject "${nsProjectA}" "${nsRootA}"
    addRayvnProject "${nsProjectB}" "${nsRootB}"

    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
}

_writeNsLib() {
    local project="$1" name="$2" content="$3"
    local root
    [[ "${project}" == "${nsProjectA}" ]] && root="${nsRootA}" || root="${nsRootB}"
    printf '#!/usr/bin/env bash\n%s\n' "${content}" > "${root}/lib/${name}.sh"
}

_clearLibs() {
    rm -f "${nsRootA}/lib/"*.sh "${nsRootB}/lib/"*.sh
}

# ============================================================================
# No collision
# ============================================================================

testNoCollisions() {
    _clearLibs
    _writeNsLib "${nsProjectA}" "libA" 'funcA() { :; }'
    _writeNsLib "${nsProjectB}" "libB" 'funcB() { :; }'
    assertTrue "checkNamespaces passes when no names overlap" \
        checkNamespaces "${nsProjectA}" "${nsProjectB}" 2> /dev/null
}

# ============================================================================
# Function collisions
# ============================================================================

testFunctionCollision() {
    _clearLibs
    _writeNsLib "${nsProjectA}" "libA" 'sharedFunc() { :; }'
    _writeNsLib "${nsProjectB}" "libB" 'sharedFunc() { :; }'
    assertFalse "checkNamespaces detects function collision across projects" \
        checkNamespaces "${nsProjectA}" "${nsProjectB}" 2> /dev/null
}

# ============================================================================
# Variable collisions
# ============================================================================

testVariableCollision() {
    _clearLibs
    _writeNsLib "${nsProjectA}" "libA" '_init_ns_test_a_libA() { declare -g sharedVar; }'
    _writeNsLib "${nsProjectB}" "libB" '_init_ns_test_b_libB() { declare -g sharedVar; }'
    assertFalse "checkNamespaces detects global variable collision across projects" \
        checkNamespaces "${nsProjectA}" "${nsProjectB}" 2> /dev/null
}

# ============================================================================
# namespace-skip-start / namespace-skip-end block
# ============================================================================

testSkipBlock() {
    _clearLibs
    _writeNsLib "${nsProjectA}" "libA" '# namespace-skip-start: intentional placeholder
sharedFunc() { :; }
# namespace-skip-end'
    _writeNsLib "${nsProjectB}" "libB" 'sharedFunc() { :; }'
    assertTrue "checkNamespaces respects namespace-skip-start/end block" \
        checkNamespaces "${nsProjectA}" "${nsProjectB}" 2> /dev/null
}

# ============================================================================
# # namespace-ok per-line suppression
# ============================================================================

testNamespaceOkLine() {
    _clearLibs
    _writeNsLib "${nsProjectA}" "libA" 'sharedFunc() { :; } # namespace-ok'
    _writeNsLib "${nsProjectB}" "libB" 'sharedFunc() { :; }'
    assertTrue "checkNamespaces respects # namespace-ok on function line" \
        checkNamespaces "${nsProjectA}" "${nsProjectB}" 2> /dev/null
}

# ============================================================================
# Same-file duplicate declaration is not a collision
# ============================================================================

testSameFileDuplicateNotCollision() {
    _clearLibs
    _writeNsLib "${nsProjectA}" "libA" '_init_ns_test_a_libA() {
    declare -g dupVar
    declare -g dupVar
}'
    assertTrue "same variable declared twice in one file is not a collision" \
        checkNamespaces "${nsProjectA}" 2> /dev/null
}

# ============================================================================
# Checking a single project finds no cross-project collisions
# ============================================================================

testSingleProjectNoCollision() {
    _clearLibs
    _writeNsLib "${nsProjectA}" "libA" 'sharedFunc() { :; }'
    _writeNsLib "${nsProjectB}" "libB" 'sharedFunc() { :; }'
    assertTrue "checkNamespaces with one project sees no cross-project collision" \
        checkNamespaces "${nsProjectA}" 2> /dev/null
}

source rayvn.up 'rayvn/core' 'rayvn/namespace' 'rayvn/test'
main "$@"
