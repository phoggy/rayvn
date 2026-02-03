#!/bin/bash

# Linux Compatibility Test Runner
# Runs tests for rayvn, valt, and wardn on Linux to verify cross-platform compatibility

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
declare -i total_tests=0
declare -i passed_tests=0
declare -i failed_tests=0
declare -a failed_projects=()

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Linux Compatibility Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check bash version (required 5.2+)
bash_major="${BASH_VERSINFO[0]}"
bash_minor="${BASH_VERSINFO[1]}"
bash_patch="${BASH_VERSINFO[2]}"
bash_version="${bash_major}.${bash_minor}.${bash_patch}"

echo -e "${YELLOW}Bash Version Check:${NC}"
if (( bash_major > 5 || (bash_major == 5 && bash_minor >= 2) )); then
    echo -e "  ${GREEN}✓ Bash ${bash_version} (requires 5.2+)${NC}"
else
    echo -e "  ${RED}✗ Bash ${bash_version} - INCOMPATIBLE (requires 5.2+)${NC}"
    echo -e "${RED}ERROR: rayvn requires bash 5.2+ for \${...; } command substitution syntax${NC}"
    echo -e "${YELLOW}See REQUIREMENTS.md for upgrade instructions${NC}"
    exit 1
fi
echo ""

# Display system information
echo -e "${YELLOW}System Information:${NC}"
echo "  OS: ${ cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'; }"
echo "  Bash: ${ bash --version | head -1; }"
echo "  Date: ${ date --version | head -1; }"
echo "  Sed: ${ sed --version | head -1; }"
echo "  Awk: ${ awk --version | head -1; }"
echo "  Base64: ${ base64 --version | head -1; }"
echo ""

# Function to run rayvn test for one or more projects
run_rayvn_test() {
    local -a projects=("$@")
    local project_list="${projects[*]}"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing: ${project_list}${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Verify all project directories exist
    for project in "${projects[@]}"; do
        local project_dir="/workspace/${project}"
        if [[ ! -d "${project_dir}" ]]; then
            echo -e "${RED}✗ Project directory not found: ${project_dir}${NC}"
            ((failed_tests+=1))
            ((total_tests+=1))
            failed_projects+=("${project}")
            return 1
        fi
    done

    # Copy all projects to writable temp directories
    for project in "${projects[@]}"; do
        local temp_dir="/tmp/${project}"
        rm -rf "${temp_dir}"
        cp -r "/workspace/${project}" "${temp_dir}"
    done

    # Add all project bin directories to PATH
    local path_dirs=""
    for project in "${projects[@]}"; do
        path_dirs="/tmp/${project}/bin:${path_dirs}"
    done
    export PATH="${path_dirs}${PATH}"

    # Change to rayvn directory to run tests
    cd "/tmp/rayvn"

    # Set environment variables for non-interactive mode
    export nonInteractive=1              # Disables spinner/terminal requirements
    export forceRayvn24BitColor=1        # Enables colors even without TTY

    # Run the test using rayvn as the test runner for all projects at once
    # Command syntax: rayvn test [project...]
    # rayvn finds projects by their executables in PATH
    ((total_tests+=1))  # note: under errexit, using ++ fails but +=1 does not!
    echo ""
    if rayvn test "${projects[@]}"; then
        echo ""
        echo -e "${GREEN}✓ All tests passed${NC}"
        ((passed_tests+=1))
    else
        local exit_code=$?
        echo ""
        echo -e "${RED}✗ Tests failed (exit code: ${exit_code})${NC}"
        ((failed_tests+=1))
        failed_projects+=("${project_list}")
    fi
    echo ""
}

# Test sed compatibility
echo -e "${YELLOW}Testing sed compatibility:${NC}"
echo -n "  Basic regex: "
if echo "test123" | sed 's/[0-9]\+/NUM/' | grep -q "testNUM"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "  POSIX character classes: "
if echo "test 123" | sed 's/[[:space:]]\+/ /' | grep -q "test 123"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi
echo ""

# Test date compatibility
echo -e "${YELLOW}Testing date compatibility:${NC}"
echo -n "  Unix timestamp formatting: "
if date -d @1234567890 "+%Y-%m-%d" 2>/dev/null | grep -q "2009-02-13"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "  Date formatting with padding: "
if date '+%B %d, %Y' | grep -qE "[A-Za-z]+ [0-9]{2}, [0-9]{4}"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi
echo ""

# Test base64 compatibility
echo -e "${YELLOW}Testing base64 compatibility:${NC}"
echo -n "  Line wrapping with -w flag: "
if echo "test" | base64 -w 65 2>/dev/null | grep -q "dGVzdAo="; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi
echo ""

# Start D-Bus session and unlock gnome-keyring (required by test-secrets)
if command -v dbus-launch &> /dev/null && command -v gnome-keyring-daemon &> /dev/null; then
    eval "$(dbus-launch --sh-syntax)"
    echo "" | gnome-keyring-daemon --unlock --components=secrets &> /dev/null || true
fi

# Collect available projects
available_projects=()
for project in rayvn valt wardn; do
    if [[ -d "/workspace/${project}" ]]; then
        available_projects+=("${project}")
    else
        echo -e "${YELLOW}⚠ ${project} not found, skipping${NC}"
    fi
done

# Run tests for all available projects at once using rayvn test
if [[ ${#available_projects[@]} -gt 0 ]]; then
    # Note: Testing all projects together with a single command
    # This runs: rayvn test rayvn valt wardn
    run_rayvn_test "${available_projects[@]}"
else
    echo -e "${RED}✗ No projects found to test${NC}"
    exit 1
fi

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Projects tested: ${available_projects[*]}"
echo -e "${GREEN}Passed: ${passed_tests}${NC}"
if ((failed_tests > 0)); then
    echo -e "${RED}Failed: ${failed_tests}${NC}"
    echo ""
    echo -e "${RED}Test output above shows details${NC}"
else
    echo -e "${GREEN}Failed: 0${NC}"
fi
echo ""

if ((failed_tests > 0)); then
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All tests passed${NC}"
    exit 0
fi
