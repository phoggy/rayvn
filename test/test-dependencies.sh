#!/usr/bin/env bash

main() {
    init "$@"

    testExtractFlakeDepsBasic
    testExtractFlakeDepsLocalPkg
    testExtractFlakeDepsEmpty
    testGetBrewDependenciesBasic
    testGetBrewDependenciesWithMappings
    testGetBrewDependenciesWithExclusions
    testDepsProjectRootFound
    testDepsProjectRootMissing
    testFindDependenciesReportsOnly
    testFindDependenciesFix
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
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

# ============================================================================
# _depsProjectRoot
# ============================================================================

testDepsProjectRootFound() {
    local dir; dir=${ makeTempDir deps-root-XXXXXX; }
    touch "${dir}/flake.nix"

    # Set the xyzHome variable that _depsProjectRoot looks for
    declare -g xyzHome="${dir}"

    local result
    assertTrue "_depsProjectRoot returns 0 when flake.nix exists" \
        _depsProjectRoot xyz result

    assertEqual "${dir}" "${result}" "sets project root to dir with flake.nix"

    unset xyzHome
    rm -rf "${dir}"
}

testDepsProjectRootMissing() {
    local dir; dir=${ makeTempDir deps-noflake-XXXXXX; }
    # No flake.nix in this dir

    declare -g noflakeHome="${dir}"

    local result
    assertFalse "_depsProjectRoot returns 1 when no flake.nix" \
        _depsProjectRoot noflake result

    unset noflakeHome
    rm -rf "${dir}"
}

# ============================================================================
# findDependencies
# ============================================================================

# Create a fixture project, registered as 'depsfixture', whose script uses jq and sha1sum (from coreutils), with a
# trailing comment containing an apostrophe and message text quoting 'awk'. Its flake lists only bash. Sets the named
# var to the project root.

_newDepsFixtureProject() {
    local -n rootRef=$1
    local projectDir; projectDir=${ makeTempDir deps-project-XXXXXX; }
    mkdir -p "${projectDir}/bin" || fail
    cat > "${projectDir}/bin/tool" <<'SCRIPT'
#!/usr/bin/env bash
main() {
    jq . "$1" # it's a comment with an apostrophe
    sha1sum "$1"
    show "Fixing 'awk' → 'gawk'"
}
SCRIPT
    printf 'runtimeDeps = [\n          pkgs.bash\n];\n' > "${projectDir}/flake.nix"
    _rayvnProjects[depsfixture::project]="${projectDir}"
    rootRef="${projectDir}"
}

testFindDependenciesReportsOnly() {
    local dir; _newDepsFixtureProject dir
    local before; readFile "${dir}/flake.nix" before
    local output; output="${ findDependencies depsfixture 2>&1; }"
    assertNotEqual 0 $? "missing deps must fail without --fix"
    assertContains 'pkgs.jq (for jq)' "${output}"
    assertContains 'pkgs.coreutils (for sha1sum)' "${output}"
    [[ ${output} != *"'awk' found"* ]] || fail "message text must not be reported as awk: ${output}"
    local after; readFile "${dir}/flake.nix" after
    assertEqual "${before}" "${after}" "flake.nix must not change without --fix"
}

testFindDependenciesFix() {
    local dir; _newDepsFixtureProject dir
    local output; output="${ findDependencies depsfixture fix 2>&1; }"
    assertEqual 0 $? "--fix must succeed: ${output}"
    assertInFile 'pkgs.jq' "${dir}/flake.nix"
    assertInFile 'pkgs.coreutils' "${dir}/flake.nix"
    output="${ findDependencies depsfixture 2>&1; }"
    assertEqual 0 $? "deps must pass once fixed: ${output}"
}

source rayvn.up 'rayvn/core' 'rayvn/dependencies' 'rayvn/index' 'rayvn/test'
main "$@"
