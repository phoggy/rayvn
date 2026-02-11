#!/usr/bin/env bash

# Linux Compatibility Test
# Runs full Docker-based test suite to verify Linux compatibility

source rayvn.up 'rayvn/core'

# Skip if already running inside a container
if [[ -f /.dockerenv ]]; then
    echo "Skipping: already running inside a container"
    exit 0
fi

# Skip if running under nix (Docker can't mount nix store paths on macOS)
if [[ -n ${IN_NIX_SHELL} ]]; then
    echo "Skipping: Docker cannot mount nix store paths"
    exit 0
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    fail "Docker is required but not installed. See https://docs.docker.com/get-docker/"
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
