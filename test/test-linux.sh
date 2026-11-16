#!/usr/bin/env bash

# Linux Compatibility Test
# Runs full Docker-based test suite to verify Linux compatibility
# REQUIRES: docker Runs all tests inside a Linux container to verify cross-platform compatibility.

source rayvn.up 'rayvn/core'

# Skips the test, unless releasing (rayvnTest_Release) a project whose Linux workflow does not cover Linux
# (rayvnTest_LinuxCovered), when it must fail instead: a release must not pass untested

skipLinuxTest() {
    (( rayvnTest_Release && ! rayvnTest_LinuxCovered )) && fail "the Linux tests must run for a release: $1"
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

# Check if Docker image exists, build if needed
if ! docker image inspect linux-compat-test:latest &> /dev/null; then
    echo "Docker image not found, building..."
    docker compose build || fail
fi

# Run the tests
linuxLogDir="${HOME}/.config/rayvn/linux-tests"
docker compose up --build --abort-on-container-exit --exit-code-from linux-test
result=$?

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
