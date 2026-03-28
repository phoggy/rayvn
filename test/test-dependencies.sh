#!/usr/bin/env bash

main() {
    init "$@"

    testExtractFlakeDepsBasic
    testExtractFlakeDepsLocalPkg
    testExtractFlakeDepsEmpty
    testGetBrewDependenciesBasic
    testGetBrewDependenciesWithMappings
    testGetBrewDependenciesWithExclusions
}

init() {
    while (( $# )); do
        case "$1" in
            --debug) setDebug --showLogOnExit ;;
            --debug-new) setDebug --clearLog --showLogOnExit ;;
            --debug-out) setDebug --tty "${terminal}" ;;
            --debug-tty) shift; setDebug --tty "$1" ;;
        esac
        shift
    done
}

# Write a fixture flake.nix with the given runtimeDeps content.
# Returns the project root directory path.
_writeDepsFixture() {
    local runtimeDepsContent="$1"
    local dir; dir=${ makeTempDir deps-test-XXXXXX; }
    printf 'runtimeDeps = [\n%s\n];\n' "${runtimeDepsContent}" > "${dir}/flake.nix"
    echo "${dir}"
}

# ============================================================================
# _extractFlakeDeps
# ============================================================================

testExtractFlakeDepsBasic() {
    local dir; dir=${ _writeDepsFixture '    pkgs.age
    pkgs.minisign
    pkgs.curl'; }

    local result; result=${ _extractFlakeDeps "${dir}"; }
    assertContains 'pkg:age' "${result}" "extracts age pkg"
    assertContains 'pkg:minisign' "${result}" "extracts minisign pkg"
    assertContains 'pkg:curl' "${result}" "extracts curl pkg"

    rm -rf "${dir}"
}

testExtractFlakeDepsLocalPkg() {
    local dir; dir=${ _writeDepsFixture '    rayvnPkg
    mrldPkg'; }

    local result; result=${ _extractFlakeDeps "${dir}"; }
    assertContains 'local:rayvnPkg' "${result}" "extracts local rayvnPkg"
    assertContains 'local:mrldPkg' "${result}" "extracts local mrldPkg"

    rm -rf "${dir}"
}

testExtractFlakeDepsEmpty() {
    local dir; dir=${ _writeDepsFixture ''; }

    local result; result=${ _extractFlakeDeps "${dir}"; }
    assertEqual '' "${result}" "empty runtimeDeps produces no output"

    rm -rf "${dir}"
}

# ============================================================================
# getBrewDependencies
# ============================================================================

testGetBrewDependenciesBasic() {
    local dir; dir=${ _writeDepsFixture '    pkgs.age
    pkgs.minisign'; }

    local result; result=${ getBrewDependencies myproject "${dir}"; }
    assertContains 'depends_on "age"' "${result}" "outputs age brew dependency"
    assertContains 'depends_on "minisign"' "${result}" "outputs minisign brew dependency"

    rm -rf "${dir}"
}

testGetBrewDependenciesWithMappings() {
    local dir; dir=${ _writeDepsFixture '    pkgs.minisign
    pkgs.rage-encryption'; }
    printf 'declare -gA nixBrewMap=([rage-encryption]="rage")\n' > "${dir}/rayvn.pkg"

    local result; result=${ getBrewDependencies myproject "${dir}"; }
    assertContains 'depends_on "minisign"' "${result}" "outputs minisign without mapping"
    assertContains 'depends_on "rage"' "${result}" "applies nixBrewMap override for rage-encryption"

    rm -rf "${dir}"
}

testGetBrewDependenciesWithExclusions() {
    local dir; dir=${ _writeDepsFixture '    pkgs.age
    pkgs.nix'; }
    printf 'declare -ga nixBrewExclude=(nix)\n' > "${dir}/rayvn.pkg"

    local result; result=${ getBrewDependencies myproject "${dir}"; }
    assertContains 'depends_on "age"' "${result}" "includes non-excluded dependency"
    [[ "${result}" != *'depends_on "nix"'* ]] || fail "nix should not appear in brew dependencies"

    rm -rf "${dir}"
}

source rayvn.up 'rayvn/core' 'rayvn/dependencies' 'rayvn/test'
main "$@"
