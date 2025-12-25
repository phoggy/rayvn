#!/usr/bin/env bash

# Linux Compatibility Test
# Runs full Docker-based test suite to verify Linux compatibility

set -euo pipefail

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is required but not installed"
    echo "See https://docs.docker.com/get-docker/"
    exit 1
fi

# Get the directory containing this script
script_dir="$(dirname "${BASH_SOURCE[0]}")"
linux_compat_dir="${script_dir}/linux-compat"

# Check if linux-compat directory exists
if [[ ! -d "${linux_compat_dir}" ]]; then
    echo "Error: linux-compat directory not found at ${linux_compat_dir}"
    exit 1
fi

# Change to linux-compat directory and run tests
cd "${linux_compat_dir}"

# Check if Docker image exists, build if needed
if ! docker image inspect linux-compat-test:latest &> /dev/null; then
    echo "Docker image not found, building..."
    make build
fi

# Run the tests
exec make test
