#!/usr/bin/env bash

# Project dependency checking and brew formula generation.
# Use via: require 'rayvn/deps'

# Check that all required project dependencies are available in PATH.
# Reads flake.nix from the project root and applies overrides from rayvn.pkg.
# Silently skips if flake.nix is not found (Nix/Homebrew installs manage their own deps).
# Args: projectName
#
#   projectName  - the rayvn project name (e.g. 'valt', 'wardn')
#
checkProjectDeps() {
    local projectName="${1}"

    # Find the project root (silently skip if flake.nix not accessible)
    local projectRoot=''
    _depsProjectRoot "${projectName}" projectRoot || return 0

    # Load overrides from rayvn.pkg (nixBinaryMap for correct binary names, nixBrewMap for install hints)
    local pkgFile="${projectRoot}/rayvn.pkg"
    local -A nixBinaryMap=()
    local -A nixBrewMap=()
    [[ -f "${pkgFile}" ]] && sourceConfigFile "${pkgFile}"

    # Check each dep
    local missing=() nixN binN
    local entry type name
    while IFS=: read -r type name; do
        case "${type}" in
            pkg)
                nixN="${name}"
                binN="${nixBinaryMap[${nixN}]:-${nixN}}"
                command -v "${binN}" &> /dev/null || missing+=("${nixN}:${binN}")
                ;;
            local)
                local varName="${name}"        # e.g. "mrldPkg"
                local projName="${varName%Pkg}" # e.g. "mrld"
                command -v "${projName}" &> /dev/null || missing+=("${projName}:${projName}")
                ;;
        esac
    done < <( _extractFlakeDeps "${projectRoot}" )

    if (( ${#missing[@]} )); then
        local formula
        for entry in "${missing[@]}"; do
            nixN="${entry%%:*}"
            binN="${entry##*:}"
            formula="${nixBrewMap[${nixN}]:-${nixN}}"
            echo "${projectName}: missing required dependency '${binN}' (${nixN})" >&2
            echo "  Install: brew install ${formula}" >&2
            echo "           Or: nix run github:phoggy/${projectName}" >&2
        done
        fail "required dependencies not found"
    fi
}

# Print brew formula depends_on lines for a project.
# Reads flake.nix and applies overrides from rayvn.pkg.
# Args: projectName [projectRoot]
#
#   projectName  - the rayvn project name (e.g. 'valt', 'wardn')
#   projectRoot  - optional path override (defaults to ${projectName}Home then PWD)
#
getBrewDeps() {
    local projectName="${1}"
    local projectRoot="${2:-}"

    if [[ -z ${projectRoot} ]]; then
        local homeVar="${projectName//-/_}Home"
        projectRoot="${!homeVar}"
        [[ ${projectRoot} ]] || projectRoot="${PWD}"
    fi

    local pkgFile="${projectRoot}/rayvn.pkg"
    local -A nixBrewMap=()
    local -a nixBrewExclude=()
    local -A nixPkgTapOverrides=()
    [[ -f "${pkgFile}" ]] && sourceConfigFile "${pkgFile}"

    local type name
    while IFS=: read -r type name; do
        case "${type}" in
            pkg)
                local nixName="${name}"
                isMemberOf nixBrewExclude "${nixName}" && continue
                local formula="${nixBrewMap[${nixName}]:-${nixName}}"
                echo "  depends_on \"${formula}\""
                ;;
            local)
                local varName="${name}"        # e.g. "mrldPkg"
                local projName="${varName%Pkg}" # e.g. "mrld"
                local formula
                if [[ ${nixPkgTapOverrides[${varName}]+defined} ]]; then
                    formula="${nixPkgTapOverrides[${varName}]}"
                else
                    formula="phoggy/rayvn/${projName}"
                fi
                echo "  depends_on \"${formula}\""
                ;;
        esac
    done < <( _extractFlakeDeps "${projectRoot}" )
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/deps' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_deps() {
    require 'rayvn/config'
}

# Find the project root containing flake.nix, setting the result via nameref.
# Returns 1 (silently skip) if flake.nix is not accessible.
# Args: projectName projectRootRef
_depsProjectRoot() {
    local projectName="${1}"
    local -n _rootRef="${2}"

    local homeVar="${projectName//-/_}Home"
    local candidateRoot="${!homeVar}"
    [[ ${candidateRoot} ]] || candidateRoot="${PWD}"

    if [[ -f "${candidateRoot}/flake.nix" ]]; then
        _rootRef="${candidateRoot}"
        return 0
    fi

    return 1  # flake.nix not found — Nix/Homebrew install, skip dep check
}

# Parse the runtimeDeps block from flake.nix and print dep entries.
# Each line of output is either "pkg:name" (for pkgs.X) or "local:XxxPkg" (for local XxxPkg vars).
# Args: projectRoot
_extractFlakeDeps() {
    local projectRoot="${1}"
    local flakeFile="${projectRoot}/flake.nix"

    [[ -f "${flakeFile}" ]] || fail "flake.nix not found at ${flakeFile}"

    gawk '
        /runtimeDeps[[:space:]]*=/ { inDeps=1; depth=0 }
        inDeps {
            line = $0

            # Track bracket depth to find end of runtimeDeps expression
            n = split($0, chars, "")
            for (i=1; i<=n; i++) {
                if (chars[i] == "[") depth++
                else if (chars[i] == "]") depth--
            }

            # Extract pkgs.X references (excluding utility namespaces)
            remaining = line
            while (match(remaining, /pkgs\.([a-zA-Z][a-zA-Z0-9_-]*)/, m)) {
                pkg = m[1]
                if (pkg != "lib" && pkg != "stdenv") {
                    print "pkg:" pkg
                }
                remaining = substr(remaining, RSTART + RLENGTH)
            }

            # Extract local XxxPkg variable references (e.g. rayvnPkg, mrldPkg)
            remaining = line
            while (match(remaining, /([a-zA-Z][a-zA-Z0-9_]*)Pkg/, m)) {
                print "local:" m[1] "Pkg"
                remaining = substr(remaining, RSTART + RLENGTH)
            }

            # End of runtimeDeps: bracket depth balanced and semicolon present
            if (depth == 0 && $0 ~ /;/) inDeps = 0
        }
    ' "${flakeFile}"
}
