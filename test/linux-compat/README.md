# Linux Compatibility Test Suite

This test suite is part of the **rayvn** project and is located at `rayvn/test/linux-compat/`.

Automated testing environment for verifying that **rayvn**, **valt**, and **wardn** work correctly on Linux (GNU coreutils) as well as macOS (BSD coreutils).

## Overview

This Docker-based test suite ensures cross-platform compatibility by running tests in a real Linux environment (Ubuntu 22.04) with:
- **Bash 5.3+** (required for `${...; }` command substitution syntax)
- GNU versions of core utilities:
  - `sed`
  - `awk`
  - `date`
  - `base64`
  - `find`

## Requirements

### Bash Version Requirement

**rayvn**, **valt**, and **wardn** require **Bash 5.2 or later** due to the use of modern command substitution syntax:

```bash
# Modern syntax (requires bash 5.2+):
result="${ command; }"

# This syntax is more readable and used throughout the codebase
```

**On macOS:** Built-in bash is usually sufficient (check with `bash --version`)
**On Linux:** You may need to upgrade bash:
```bash
# Check your bash version:
bash --version

# If you have bash < 5.2, upgrade it (method varies by distro)
# Or use this Docker environment which includes bash 5.3
```

The Docker test environment automatically installs bash 5.3 from source to ensure compatibility.

## Quick Start

### Prerequisites

- Docker installed ([Get Docker](https://docs.docker.com/get-docker/))
- Docker Compose installed (included with Docker Desktop)

### Running Tests

#### Using rayvn test command (recommended)

```bash
# From anywhere with rayvn in PATH
rayvn test linux-compat
```

This will automatically build the Docker image on first run if needed.

#### Using make directly

From the `rayvn/test/linux-compat/` directory:

```bash
# Run full test suite with compatibility checks
make test

# Run all project tests (rayvn, valt, wardn)
make all

# Run individual project tests
make rayvn
make valt
make wardn

# Clean rebuild
make rebuild

# Interactive shell for debugging
make shell

# Quick verification of command compatibility
make verify
```

## Directory Structure

```
linux-test/
├── Dockerfile           # Linux test environment definition
├── docker-compose.yml   # Orchestration configuration
├── Makefile            # Convenient test commands
├── run-tests.sh        # Full test suite with compatibility checks
├── test-runner.sh      # Wrapper for running rayvn test command
├── README.md           # This file
└── REQUIREMENTS.md     # Detailed bash version requirements
```

## What Gets Tested

### 1. **Command Compatibility Checks**
- `sed` with basic regex (e.g., `\+` instead of `+`)
- `sed` with POSIX character classes (e.g., `[[:space:]]`)
- `date` with Unix timestamp formatting (`-d @TIMESTAMP`)
- `date` with padding options
- `base64` with line wrapping (`-w` flag)

### 2. **Project Tests**
All projects are tested using the `rayvn test` command, which discovers and runs tests for:
- **rayvn**: Core rayvn library tests (rayvn-up, config, show)
- **valt**: valt-specific tests (if available)
- **wardn**: wardn-specific tests (if available)

Projects are auto-detected via their executables in PATH. Tests run in non-interactive mode using the `rayvnTest_NonInteractive` environment variable to disable spinner/terminal requirements.

## How It Works

1. **Dockerfile** creates an Ubuntu 22.04 container with:
   - Bash 5.3 compiled from source (required for `${...; }` syntax)
   - GNU coreutils (sed, awk, date, etc.)
   - Bitwarden CLI (auto-installed from latest GitHub release for wardn tests)
   - Git and other essential tools
   - Non-root user for safer test execution
   - test-runner.sh script baked into the image

2. **docker-compose.yml** orchestrates the test environment:
   - Mounts rayvn, valt, and wardn as read-only volumes
   - Sets up proper environment variables
   - Executes the test runner script

3. **run-tests.sh** executes the full test suite:
   - Displays system information
   - Runs compatibility checks for key commands
   - Executes `rayvn test` for all available projects
   - Reports comprehensive results

4. **test-runner.sh** provides a simple wrapper:
   - Copies projects to /tmp for writable access
   - Sets up PATH with all project bin directories
   - Sets `rayvnTest_NonInteractive=1` to disable spinner/TTY requirements
   - Runs `rayvn test` with specified projects

## Test Output

The test runner provides:
- ✓ Green checkmarks for passing tests
- ✗ Red X marks for failing tests
- ⚠ Yellow warnings for skipped tests
- Detailed summary at the end

Example output:
```
========================================
Linux Compatibility Test Suite
========================================

Bash Version Check:
  ✓ Bash 5.3.0 (requires 5.2+)

System Information:
  OS: Ubuntu 22.04.5 LTS
  Bash: GNU bash, version 5.3.0
  Date: date (GNU coreutils) 8.32
  Sed: sed (GNU sed) 4.8
  Awk: GNU Awk 5.1.0
  Base64: base64 (GNU coreutils) 8.32

Testing sed compatibility:
  Basic regex: ✓
  POSIX character classes: ✓

Testing date compatibility:
  Unix timestamp formatting: ✓
  Date formatting with padding: ✓

Testing base64 compatibility:
  Line wrapping with -w flag: ✓

========================================
Testing: rayvn valt wardn
========================================

rayvn test rayvn-up  log at /home/testuser/.rayvn/tests/rayvn-rayvn-up.log
rayvn test config    log at /home/testuser/.rayvn/tests/rayvn-config.log
rayvn test show      log at /home/testuser/.rayvn/tests/rayvn-show.log
valt (no tests)
wardn (no tests)

✓ All tests passed

========================================
Test Summary
========================================

Projects tested: rayvn valt wardn
Passed: 1
Failed: 0

✓ All tests passed
```

## Development Workflow

### Making Changes

1. Edit your code on macOS
2. Run `make test` to test on Linux
3. Fix any compatibility issues
4. Repeat until all tests pass

### Testing Specific Projects

```bash
# Test only rayvn
make rayvn

# Test only valt
make valt

# Test only wardn
make wardn

# Test all projects
make all
```

### Interactive Testing

For debugging or manual testing:

```bash
# Start an interactive shell in the Linux container
make shell

# Inside the container, projects are available at /workspace:
cd /workspace/rayvn
ls -la

# Test specific commands:
date -d @1234567890 "+%Y-%m-%d"
echo "test" | sed 's/[0-9]\+/NUM/'

# Run rayvn test manually:
cp -r /workspace/rayvn /tmp/rayvn
cd /tmp/rayvn
export PATH="/tmp/rayvn/bin:$PATH"
export rayvnTest_NonInteractive=1
rayvn test rayvn
```

## Non-Interactive Mode

The test suite runs in non-interactive mode using the `rayvnTest_NonInteractive` environment variable. When set, this:

- Disables the spinner animation (which requires a TTY)
- Disables terminal control features (`stty` commands)
- Allows tests to run in Docker containers without pseudo-TTY allocation
- Sets `isInteractive=0` in rayvn/core.sh

This is automatically set by both test-runner.sh and run-tests.sh, but you can also set it manually:

```bash
export rayvnTest_NonInteractive=1
rayvn test rayvn
```

## Compatibility Fixes Implemented

### sed
- ✓ Removed all `-E` flags (extended regex)
- ✓ Converted to basic regex: `+` → `\+`, `{n}` → `\{n\}`, `(...)` → `\(...\)`
- ✓ Replaced `\s` with `[[:space:]]`

### date
- ✓ Added fallback: `date -d @TIMESTAMP` (GNU) || `date -r TIMESTAMP` (BSD)
- ✓ Added fallback for `%-d` flag: try GNU, fall back to sed stripping

### base64
- ✓ Added fallback: `base64 -b 65` (BSD) || `base64 -w 65` (GNU)

### diskutil (macOS-only)
- ✓ Added Linux alternative using `lsblk` for encryption detection

### Bitwarden CLI (for wardn)
- ✓ Automatically downloads and installs latest CLI release from GitHub
- ✓ Uses GitHub API to fetch the most recent `cli-v*` tagged release
- ✓ Installed during Docker image build

## Troubleshooting

### Tests fail in container but pass on macOS
- Check the specific error message
- Verify the command syntax is portable
- Test the failing command interactively: `make shell`
- Check if you need to set `rayvnTest_NonInteractive=1` for non-TTY environments

### Container won't start
```bash
# Clean up and rebuild
make rebuild
```

### Need to see more verbose output
```bash
# Run with explicit bash debugging
docker compose run --rm linux-test bash -x run-tests.sh

# Or debug test-runner.sh
docker compose run --rm linux-test bash -x test-runner.sh rayvn
```

### Permission denied errors
If you see "Permission denied" when running test-runner.sh, the image needs to be rebuilt:
```bash
make rebuild
```

## CI/CD Integration

This Docker setup can be integrated into CI/CD pipelines:

### GitHub Actions Example
```yaml
name: Linux Compatibility Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Linux tests
        run: |
          cd linux-test
          docker compose up --build --abort-on-container-exit
```

## Important Notes

- **Bash 5.2+ Required**: See [REQUIREMENTS.md](REQUIREMENTS.md) for detailed system requirements
- **Bash 5.3** is compiled from source during the Docker build (adds a few minutes to first build)
- **Bitwarden CLI** is automatically installed from the latest GitHub release
- Projects are mounted as **read-only** to prevent accidental modifications
- Tests copy projects to `/tmp` for writable access during test execution
- Tests run as a non-root user for security
- The container is ephemeral - it's destroyed after each run
- **rayvnTest_NonInteractive mode** allows tests to run without TTY/spinner requirements
- All tests use the `rayvn test` command for consistent test discovery and execution

## Future Enhancements

Potential improvements:
- [ ] Test on multiple Linux distributions (Alpine, Fedora, Arch)
- [ ] Add performance benchmarking
- [ ] Generate HTML test reports
- [ ] Test with different bash versions
- [ ] Add pre-commit hook for automatic testing
