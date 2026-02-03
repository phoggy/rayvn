#!/usr/bin/env bash
# shellcheck disable=SC2155

# Tests for nix build output structure and nix profile install

main() {
    init "${@}"

    testNixBuild
    testNixProfileInstall

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

    # Graceful skip if nix is not available
    if ! command -v nix &> /dev/null; then
        log "nix not available, skipping"
        exit 0
    fi

    declare -grx testProfile="${ tempDirPath; }/nix-test-profile"
}

testNixBuild() {
    local storePath
    storePath=${ nix build "path:${rayvnHome}" --no-link --print-out-paths 2>/dev/null; }
    [[ -n "${storePath}" ]] || fail "nix build should produce a store path"

    # Assert expected layout
    assertFileExists "${storePath}/bin/rayvn"
    assertFileExists "${storePath}/bin/rayvn.up"
    assertDirectory "${storePath}/share/rayvn/lib"
    assertDirectory "${storePath}/share/rayvn/templates"
    assertDirectory "${storePath}/share/rayvn/etc"
    assertFileExists "${storePath}/share/rayvn/rayvn.pkg"
}

testNixProfileInstall() {
    nix profile install "path:${rayvnHome}" --profile "${testProfile}" 2>/dev/null \
        || fail "nix profile install should succeed"

    assertFileExists "${testProfile}/bin/rayvn"

    local version
    version=${ "${testProfile}/bin/rayvn" -v 2>&1; }
    [[ "${version}" == rayvn* ]] || fail "rayvn -v should start with 'rayvn', got: ${version}"
}

source rayvn.up 'rayvn/core' 'rayvn/test'
main "${@}"
