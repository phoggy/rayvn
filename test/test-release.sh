#!/usr/bin/env bash

# The release version written to rayvn.pkg and flake.nix before a release is tagged.

main() {
    init "$@"

    testWriteReleaseVersion

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done
}

# The post-release version and empty date in rayvn.pkg, and the version in flake.nix, become the release's

testWriteReleaseVersion() {
    local dir; dir="${ makeTempDir; }"
    printf "projectName='demo'\nprojectVersion='0.4.0+'\nprojectReleaseDate=''\n" > "${dir}/rayvn.pkg"
    printf '{\n  outputs = {\n    version = "0.4.0";\n  };\n}\n' > "${dir}/flake.nix"

    _writeReleaseVersion "${dir}/rayvn.pkg" "${dir}/flake.nix" '0.5.0' '2026-11-08 12:00:00 PST'

    assertInFile "projectVersion='0.5.0'" "${dir}/rayvn.pkg"
    assertInFile "projectReleaseDate='2026-11-08 12:00:00 PST'" "${dir}/rayvn.pkg"
    assertInFile "projectName='demo'" "${dir}/rayvn.pkg"
    assertInFile 'version = "0.5.0";' "${dir}/flake.nix"
}

source rayvn.up 'rayvn/test' 'rayvn/release'
main "$@"
