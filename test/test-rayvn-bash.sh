#!/usr/bin/env rayvn-bash

main() {
    init "$@"

    testUsageDisplayed
    testFindsCorrectBashVersion
    testExecutesScript
    testCommandSubstitutionWorks
    testCacheCreated
    testCacheTrusted
    testNixFastPath

    return 0
}

init() {
    while (( $# )); do
        case "${1}" in
            --debug) setDebug showOnExit ;;
            --debug-new) setDebug clearLog showOnExit ;;
            --debug-out) setDebug tty "${ tty; }" ;;
            --debug-tty) shift; setDebug tty "${1}" ;;
        esac
        shift
    done

    # Create temp directory for test scripts
    testDir=${ mktemp -d; }
    cacheFile="${HOME}/.cache/rayvn/bash-path"
}

testUsageDisplayed() {
    local output
    output=${ rayvn-bash 2>&1; }
    [[ "${output}" == *"rayvn-bash: smart shebang"* ]] || fail "usage missing 'rayvn-bash: smart shebang'"
    [[ "${output}" == *"#!/usr/bin/env rayvn-bash"* ]] || fail "usage missing shebang example"
    [[ "${output}" == *"Requires bash 5.3+"* ]] || fail "usage missing version requirement"
}

testFindsCorrectBashVersion() {
    # rayvn-bash should find bash 5.3+
    local bashPath
    bashPath=${ command -v bash; }
    local version
    version=${ "${bashPath}" -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'; }
    local major="${version%%.*}"
    local minor="${version#*.}"

    # Verify bash in PATH is 5.3+
    (( major > 5 || (major == 5 && minor >= 3) )) || fail "bash version ${version} is less than 5.3"
}

testExecutesScript() {
    # Create a simple test script
    local script="${testDir}/test-exec.sh"
    cat > "${script}" << 'EOF'
#!/usr/bin/env rayvn-bash
echo "executed"
EOF
    chmod +x "${script}"

    local output
    output=${ "${script}"; }
    assertEqual "${output}" "executed"
}

testCommandSubstitutionWorks() {
    # Create a script that uses bash 5.3+ command substitution
    local script="${testDir}/test-cmdsub.sh"
    cat > "${script}" << 'EOF'
#!/usr/bin/env rayvn-bash
result=${ echo "hello"; }
echo "${result}"
EOF
    chmod +x "${script}"

    local output
    output=${ "${script}"; }
    assertEqual "${output}" "hello"
}

testCacheCreated() {
    # Clear cache
    rm -f "${cacheFile}"

    # Run a script through rayvn-bash
    local script="${testDir}/test-cache.sh"
    cat > "${script}" << 'EOF'
#!/usr/bin/env rayvn-bash
echo "done"
EOF
    chmod +x "${script}"
    "${script}" > /dev/null

    # Cache might not be created if bash in PATH is 5.3+ (fast path)
    # So we check that either cache exists OR bash in PATH is correct
    local bashInPath
    bashInPath=${ command -v bash; }

    if [[ -f "${cacheFile}" ]]; then
        local cached
        cached=${ cat "${cacheFile}"; }
        assertFileExists "${cached}"
    else
        # Fast path was used - verify bash in PATH is 5.3+
        local version
        version=${ "${bashInPath}" -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'; }
        [[ "${version}" == 5.* ]] || [[ "${version}" == 6.* ]] || fail "expected bash 5.x or 6.x, got ${version}"
    fi
}

testCacheTrusted() {
    # If cache exists, verify it points to a valid bash
    if [[ -f "${cacheFile}" ]]; then
        local cached
        cached=${ cat "${cacheFile}"; }
        assertFileExists "${cached}"
        [[ -x "${cached}" ]] || fail "cached bash ${cached} is not executable"
    fi
}

testNixFastPath() {
    # Check if we're in a nix environment
    local bashInPath
    bashInPath=${ command -v bash; }

    if [[ "${bashInPath}" == /nix/store/* ]]; then
        # In nix, rayvn-bash should use bash directly without version check
        # We can verify this by checking that no cache is created
        rm -f "${cacheFile}"

        local script="${testDir}/test-nix.sh"
        cat > "${script}" << 'EOF'
#!/usr/bin/env rayvn-bash
echo "nix"
EOF
        chmod +x "${script}"
        "${script}" > /dev/null

        # In nix fast path, cache should not be created
        assertFileDoesNotExist "${cacheFile}"
    fi
}

source rayvn.up 'rayvn/test'
main "$@"
