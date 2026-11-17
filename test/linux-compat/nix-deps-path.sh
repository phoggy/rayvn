#!/usr/bin/env bash

# Outputs a PATH suffix (colon separated, starting with a colon) of the Nix store bin directories from the dev shells
# of the given projects, checked out in NIX_DEPS_ROOT/PROJECT (in the container, copied to /tmp/PROJECT). Appending it
# to PATH makes the projects' tools (jq, age, minisign, phraze, typst, ...) available while the system's own commands
# (sed, gawk, date, ...), which these tests are meant to exercise, still come first. The tools are listed only in each
# project's flake.nix, so new ones need no change here. In the container, Nix keeps what it fetches or builds in the
# nix-store volume, so only the first run waits. Used by the container's runners and by .github/workflows/tests.yml.
#
# Usage: PATH="${PATH}${ nix-deps-path.sh PROJECT...; }"
#
# NIX_DEPS_ROOT is the directory holding the project checkouts (default: /tmp).

set -uo pipefail

declare -A seen=()
suffix=''

for project in "$@"; do
    flake="${NIX_DEPS_ROOT:-/tmp}/${project}"
    [[ -f "${flake}/flake.nix" ]] || continue
    log="/tmp/nix-develop-${project}.log"
    echo "Preparing ${project} dependencies with Nix (only slow the first time)..." >&2
    if ! devPath="${ nix develop "path:${flake}" --command printenv PATH 2> "${log}"; }"; then
        echo "nix develop failed for ${project}:" >&2
        tail -20 "${log}" >&2
        exit 1
    fi
    IFS=: read -r -a dirs <<< "${devPath}"
    for dir in "${dirs[@]}"; do
        [[ ${dir} == /nix/store/* && -z ${seen[${dir}]:-} ]] || continue
        seen[${dir}]=1
        suffix+=":${dir}"
    done
done

echo "${suffix}"
