#!/usr/bin/env bash

# Writing the release version, and finding the flake inputs to lock to releases, for a release.

main() {
    init "$@"

    testWriteReleaseVersion
    testOwnFlakeInputs

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

# Only root inputs that are the owner's GitHub projects are listed, not other owners' or followed inputs

testOwnFlakeInputs() {
    local lockFile; lockFile="${ makeTempDir; }/flake.lock"
    cat > "${lockFile}" <<'LOCK'
{
  "nodes": {
    "nixpkgs": { "original": { "owner": "NixOS", "repo": "nixpkgs", "type": "github" } },
    "rayvn": { "original": { "owner": "phoggy", "repo": "rayvn", "type": "github" } },
    "valt": { "inputs": { "rayvn": ["rayvn"] }, "original": { "owner": "Phoggy", "repo": "valt", "type": "github" } },
    "local": { "original": { "path": "/tmp/x", "type": "path" } },
    "root": { "inputs": { "nixpkgs": "nixpkgs", "rayvn": "rayvn", "valt": "valt", "local": "local", "other": ["valt", "rayvn"] } }
  },
  "root": "root",
  "version": 7
}
LOCK
    assertEqual $'rayvn rayvn\nvalt valt' "${ _ownFlakeInputs phoggy "${lockFile}"; }"
}

source rayvn.up 'rayvn/test' 'rayvn/release'
main "$@"
