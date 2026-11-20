#!/usr/bin/env bash

# Linux Compatibility Test
# Runs full Docker-based test suite to verify Linux compatibility
# REQUIRES: docker Runs all tests inside a Linux container to verify cross-platform compatibility.

source rayvn.up 'rayvn/core'

# Skips the test, unless releasing (rayvnTest_Release) a project whose tests workflow does not cover Linux
# (rayvnTest_LinuxCovered), when it must fail instead: a release must not pass untested

skipLinuxTest() {
    if (( rayvnTest_Release && ! rayvnTest_LinuxCovered )); then
        echo "Failed: the Linux tests must run for a release: $1"
        exit 1
    fi
    echo "Skipping: $1"
    exit 0
}

# Skip if already running inside a container
if [[ -f /.dockerenv ]]; then
    echo "Skipping: already running inside a container"
    exit 0
fi

# Skip if running under nix (Docker can't mount nix store paths on macOS); a release has run it outside nix first
if [[ -n ${IN_NIX_SHELL} ]]; then
    echo "Skipping: Docker cannot mount nix store paths"
    exit 0
fi

# Skip if Docker is not installed (harness checks this before running, but guard for direct invocation)
if ! command -v docker &> /dev/null; then
    skipLinuxTest "docker not installed"
fi

if ! docker info &> /dev/null; then
    skipLinuxTest "Docker daemon is not running"
fi

# Get the directory containing this script
script_dir="${ dirname "${BASH_SOURCE[0]}"; }"

linux_compat_dir="${script_dir}/linux-compat"

# Check if linux-compat directory exists
if [[ ! -d "${linux_compat_dir}" ]]; then
    fail "linux-compat directory not found at ${linux_compat_dir}"
fi

# Change to linux-compat directory and run tests
cd "${linux_compat_dir}"

# Build the image, or bring it up to date (quick when nothing changed)
docker compose build || fail

# The nix-store volume keeps the Nix store between runs. Docker copies the image's /nix into it only when it is
# created, so once the image is rebuilt with a new Nix install (e.g. after the Dockerfile changes before that step),
# the image's Nix profile points to store paths the volume does not have, and nix is not found. If so, remove the
# volume (with the stopped container that uses it), so that this run copies /nix from the image again.
nixVolume="${PWD##*/}_nix-store"
if docker volume inspect "${nixVolume}" &> /dev/null &&
   ! docker run --rm -v "${nixVolume}:/nix" linux-compat-test:latest test -x /home/testuser/.nix-profile/bin/nix; then
    echo "The Nix store volume is older than the image: removing it, to start again from the image's /nix"
    docker compose down --volumes || fail
fi

# Run the tests
linuxLogDir="${HOME}/.config/rayvn/linux-tests"
docker compose up --abort-on-container-exit --exit-code-from linux-test
result=$?

# If Docker stopped while the tests ran (e.g. Docker Desktop was quit), say so rather than showing the logs, which
# would only mislead: the tests did not fail, the container went away (docker compose says only "unexpected EOF").
# rayvn release shows the "Failed: " line (see _linuxTestFailure).

if (( result != 0 )) && ! docker info &> /dev/null; then
    echo "Failed: Docker stopped while the Linux tests ran (was Docker Desktop quit?)"
    exit 1
fi

# On failure, show any test logs collected from the container
if (( result != 0 )) && [[ -d "${linuxLogDir}" ]]; then
    echo
    echo "=== Failed linux test logs ==="
    for logFile in "${linuxLogDir}"/*.log; do
        [[ -f "${logFile}" ]] || continue
        echo
        echo "--- ${ basename "${logFile}"; } ---"
        cat "${logFile}"
    done
fi

exit ${result}
