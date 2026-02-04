#!/usr/bin/env bash

# Linux Compatibility Test
# Runs full Docker-based test suite to verify Linux compatibility

source rayvn.up 'rayvn/core'

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    fail "Docker is required but not installed. See https://docs.docker.com/get-docker/"
fi

# Get the directory containing this script
script_dir="${ dirname "${BASH_SOURCE[0]}"; }"

# If running from Nix store, use rayvnRootDir instead
# (Docker can't mount /nix/store paths on macOS)
if [[ "${script_dir}" == /nix/store/* ]]; then
    script_dir="${rayvnRootDir}/test"
fi

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
exec docker compose up --build --abort-on-container-exit
