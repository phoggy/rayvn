#!/usr/local/bin/bash

# Test runner wrapper script for rayvn projects
# Usage: test-runner.sh [project...]

set -euo pipefail

# Get list of projects to test (defaults to all available)
if [[ $# -gt 0 ]]; then
    projects=("$@")
else
    # Auto-detect available projects
    projects=()
    for project in rayvn valt wardn; do
        if [[ -d "/workspace/${project}" ]]; then
            projects+=("${project}")
        fi
    done
fi

# Ensure rayvn is in the list
if [[ ! " ${projects[*]} " =~ " rayvn " ]]; then
    projects=("rayvn" "${projects[@]}")
fi

# Copy projects to writable temp directories
for project in "${projects[@]}"; do
    temp_dir="/tmp/${project}"
    rm -rf "${temp_dir}"
    if [[ -d "/workspace/${project}" ]]; then
        cp -r "/workspace/${project}" "${temp_dir}"
    else
        echo "Warning: /workspace/${project} not found, skipping"
    fi
done

# Build PATH with all project bin directories
path_dirs=""
for project in "${projects[@]}"; do
    if [[ -d "/tmp/${project}/bin" ]]; then
        path_dirs="/tmp/${project}/bin:${path_dirs}"
    fi
done
export PATH="${path_dirs}${PATH}"

# Change to rayvn directory
cd /tmp/rayvn

# Set environment variables for non-interactive mode
export nonInteractive=1
export forceRayvn24BitColor=1

# Run rayvn test
rayvn test "${projects[@]}"
