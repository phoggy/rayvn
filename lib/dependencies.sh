#!/usr/bin/env bash

# Project dependency checking and brew formula generation.
# Use via: require 'rayvn/dependencies'

# ◇ Check that all required dependencies for a project are available in PATH, printing install hints and failing if
#   any are missing. Silently skips if the project root or flake.nix is not accessible.
#
# · ARGS
#
#   projectName (string)  Name of the rayvn project to check.
#
# · ENV VARS (from rayvn.pkg)
#
#   nixBinaryMap    Map of nix pkg name → binary name overrides. [R/W]
#   nixBrewMap      Map of nix pkg name → brew formula overrides. [R/W]
#   nixBrewExclude  Array of nix pkg names to skip brew checks for. [R/W]
#   gemDeps         Map of gem name → binary name for Ruby gem dependencies. [R/W]

checkProjectDependencies() {
    local projectName="$1"

    # Find the project root (silently skip if flake.nix not accessible)
    local projectRoot=''
    _depsProjectRoot "${projectName}" projectRoot || return 0

    # Load overrides from rayvn.pkg (nixBinaryMap for correct binary names, nixBrewMap for install hints)
    local pkgFile="${projectRoot}/rayvn.pkg"
    unset nixBinaryMap nixBrewMap nixBrewExclude gemDeps
    [[ -f "${pkgFile}" ]] && sourceConfigFile "${pkgFile}"

    # Check each dep
    local missing=() nixN binN
    local entry type name
    while IFS=: read -r type name; do
        case "${type}" in
            pkg)
                nixN="${name}"
                memberOf "${nixN}" nixBrewExclude && continue
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
            if [[ ${binN} == "${nixN}" ]]; then
                show bold "${projectName}" "missing required dependency:" primary "${binN}" >&2
            else
                show bold "${projectName}" "missing required dependency:" primary "${binN}" "(${nixN} for nix)" >&2
            fi
            echo
            show "  brew envs:" primary "brew install ${formula}" >&2
            show "   nix envs:" primary "nix profile install github:phoggy/${projectName}" >&2
            echo
        done
        fail "required dependencies not found"
    fi

    checkGemDependencies "${projectName}" "${projectRoot}"
}

# ◇ Check that all Ruby gem dependencies for a project are available in PATH, printing install hints and failing
#   if any are missing. Reads gemDeps from rayvn.pkg. Silently succeeds if no gemDeps are declared.
#
# · ARGS
#
#   projectName (string)  Name of the rayvn project to check.
#   projectRoot (string)  Root path of the project; defaults to ${projectName}Home or PWD.
#
# · ENV VARS (from rayvn.pkg)
#
#   gemDeps  Map of gem package name → binary name (e.g. [bundler]='bundle'). [R/W]

checkGemDependencies() {
    local projectName="$1"
    local projectRoot="${2:-}"

    if [[ -z ${projectRoot} ]]; then
        local homeVar="${projectName//-/_}Home"
        projectRoot="${!homeVar:-${PWD}}"
    fi

    local pkgFile="${projectRoot}/rayvn.pkg"
    [[ -f "${pkgFile}" ]] || return 0

    unset gemDeps
    sourceConfigFile "${pkgFile}"
    (( ${#gemDeps[@]} )) || return 0

    local missing=() gemName binName
    for gemName in "${!gemDeps[@]}"; do
        binName="${gemDeps[${gemName}]}"
        command -v "${binName}" &>/dev/null || missing+=("${gemName}:${binName}")
    done

    if (( ${#missing[@]} )); then
        local entry gemAvailable=0
        command -v gem &>/dev/null && gemAvailable=1
        for entry in "${missing[@]}"; do
            gemName="${entry%%:*}"
            binName="${entry##*:}"
            show bold "${projectName}" "missing required dependency:" primary "${binName}" >&2
            echo
            if (( gemAvailable )); then
                show "  brew envs:" primary "gem install ${gemName}" >&2
            else
                show "  brew envs:" primary "brew install ruby" dim "(then: gem install ${gemName})" >&2
            fi
            show "   nix envs:" primary "nix profile install github:phoggy/${projectName}" >&2
            echo
        done
        fail "required gem dependencies not found"
    fi
}

# ◇ Outputs 'depends_on' formula lines for a project's brew dependencies. Reads flake.nix deps and applies name
#   mappings and exclusions from rayvn.pkg.
#
# · ARGS
#
#   projectName (string)  Name of the rayvn project (e.g. "valt", "wardn").
#   projectRoot (string)  Root path of the project; defaults to ${projectName}Home or PWD.

getBrewDependencies() {
    local projectName="$1"
    local projectRoot="${2:-}"

    if [[ -z ${projectRoot} ]]; then
        local homeVar="${projectName//-/_}Home"
        projectRoot="${!homeVar}"
        [[ -n ${projectRoot} ]] || projectRoot="${PWD}"
    fi

    local pkgFile="${projectRoot}/rayvn.pkg"
    unset nixBrewMap nixBrewExclude nixPkgTapOverrides
    [[ -f "${pkgFile}" ]] && sourceConfigFile "${pkgFile}"

    local type name
    while IFS=: read -r type name; do
        case "${type}" in
            pkg)
                local nixName="${name}"
                memberOf "${nixName}" nixBrewExclude && continue
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

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'rayvn/dependencies' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_rayvn_dependencies() {
    require 'rayvn/config'
}

# Find the project root containing flake.nix, setting the result via nameref.
# Returns 1 (silently skip) if flake.nix is not accessible.
# Args: projectName projectRootRef
_depsProjectRoot() {
    local projectName="$1"
    local -n _rootRef="$2"

    local homeVar="${projectName//-/_}Home"
    local candidateRoot="${!homeVar}"
    [[ -n ${candidateRoot} ]] || candidateRoot="${PWD}"

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
    local projectRoot="$1"
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
            while (match(remaining, /pkgs\.([a-zA-Z][a-zA-Z0-9_-]*)/, m)) { # lint-ok
                pkg = m[1]
                if (pkg != "lib" && pkg != "stdenv") {
                    print "pkg:" pkg
                }
                remaining = substr(remaining, RSTART + RLENGTH)
            }

            # Extract local XxxPkg variable references (e.g. rayvnPkg, mrldPkg)
            remaining = line
            while (match(remaining, /([a-zA-Z][a-zA-Z0-9_]*)Pkg/, m)) { # lint-ok
                print "local:" m[1] "Pkg"
                remaining = substr(remaining, RSTART + RLENGTH)
            }

            # End of runtimeDeps: bracket depth balanced and semicolon present
            if (depth == 0 && $0 ~ /;/) inDeps = 0
        }
    ' "${flakeFile}"
}
