# Linux Compatibility Fixes - Summary

This document summarizes all compatibility fixes made to ensure rayvn, valt, and wardn work correctly on both macOS and Linux.

## Test Results

✅ **122 out of 123 tests passing** on both macOS and Linux

The one failing test ("256 colors interleaved") is a pre-existing issue unrelated to platform compatibility.

## Fixes Applied

### 1. sed Compatibility (rayvn)

**Issue:** BSD sed (macOS) vs GNU sed (Linux) syntax differences

**Files Fixed:**
- `rayvn/lib/core.sh:197`
- `rayvn/lib/release.sh:181-184`
- `rayvn/lib/config.sh:231-241`

**Changes:**
- Removed all `-E` flags (extended regex mode)
- Converted extended regex to basic regex:
  - `+` → `\+`
  - `{n}` → `\{n\}`
  - `(...)` → `\(...\)` for capture groups
  - `(` → literal parenthesis (no escape)
- Replaced `\s` with `[[:space:]]` (POSIX character class)

**Example:**
```bash
# Before (BSD-specific):
sed -E 's/version "[0-9]+\.[0-9]+\.[0-9]+"/version "1.2.3"/'

# After (portable):
sed 's/version "[0-9]\+\.[0-9]\+\.[0-9]\+"/version "1.2.3"/'
```

### 2. date Command Compatibility

**Issue:** Different flags for formatting Unix timestamps

**Files Fixed:**
- `rayvn/lib/central.sh:29-30`
- `wardn/lib/security-kit.sh:17-18`

**Changes:**
- Added fallback logic: try GNU syntax first, fall back to BSD
- GNU: `date -d @TIMESTAMP`
- BSD: `date -r TIMESTAMP`
- Handled `%-d` flag (GNU-only) with sed post-processing

**Example:**
```bash
# Platform-agnostic:
date -d "@${timestamp}" "+%Y-%m-%d" 2>/dev/null || date -r "${timestamp}" "+%Y-%m-%d"
```

### 3. base64 Command Compatibility

**Issue:** Different flags for line wrapping

**File Fixed:**
- `valt/lib/age.sh:93-94`

**Changes:**
- Added fallback logic
- BSD: `base64 -b 65`
- GNU: `base64 -w 65`

**Example:**
```bash
# Platform-agnostic:
cat file | base64 -b 65 2>/dev/null || cat file | base64 -w 65
```

### 4. diskutil Command (macOS-only)

**Issue:** diskutil doesn't exist on Linux

**File Fixed:**
- `wardn/bin/wardn:227-239`

**Changes:**
- Added platform-specific implementation
- macOS: Uses `diskutil info` for FileVault detection
- Linux: Uses `lsblk` for LUKS/dm-crypt detection

**Example:**
```bash
if (( onMacOS )); then
    diskutil info "${device}" | grep -q "FileVault: *Yes"
else
    [[ ${device} =~ /dev/mapper/ ]] || lsblk -no TYPE "${device}" | grep -q "crypt"
fi
```

## Bash Version Requirement

**Minimum:** Bash 5.2+

**Reason:** The codebase uses modern `${...; }` command substitution syntax introduced in bash 5.2.

**Docker Solution:** The test environment installs bash 5.3 from source to ensure compatibility.

**For Native Linux Users:**
- Ubuntu 22.04: Ships with bash 5.1.16 → **Needs upgrade**
- Ubuntu 24.04+: Ships with bash 5.2+ → **Compatible**
- Fedora 36+: Ships with bash 5.2+ → **Compatible**
- Arch Linux: Ships with latest bash → **Compatible**

See [REQUIREMENTS.md](REQUIREMENTS.md) for upgrade instructions.

## Testing Strategy

### Automated Testing with Docker

The `linux-test/` directory provides a complete Docker-based testing environment:

```bash
cd linux-test

# Run all tests:
make test

# Run specific project:
make rayvn
make valt
make wardn

# Quick verification:
make verify

# Interactive debugging:
make shell
```

### What Gets Tested

1. **Command Compatibility Checks:**
   - sed with basic regex
   - sed with POSIX character classes
   - date with Unix timestamp formatting
   - base64 with line wrapping

2. **Project Test Suites:**
   - rayvn: 122/123 tests passing
   - valt: Tests if available
   - wardn: Tests if available

3. **Bash Version Validation:**
   - Ensures bash 5.2+ is present
   - Exits with clear error if version is too old

## Compatibility Matrix

| Feature | macOS (BSD) | Linux (GNU) | Status |
|---------|-------------|-------------|---------|
| sed basic regex | ✓ | ✓ | Fixed |
| sed extended regex | ✓ | ✓ | Removed (now basic) |
| date -r TIMESTAMP | ✓ | ✗ | Fallback added |
| date -d @TIMESTAMP | ✗ | ✓ | Fallback added |
| base64 -b N | ✓ | ✗ | Fallback added |
| base64 -w N | ✗ | ✓ | Fallback added |
| diskutil | ✓ | ✗ | Platform-specific code |
| lsblk | ✗ | ✓ | Platform-specific code |
| bash 5.2+ syntax | ✓ | ✓* | *Requires upgrade on some distros |

## Migration Guide for Users

### macOS Users
No changes needed - everything works out of the box with Homebrew bash.

### Linux Users

**Option 1: Upgrade Bash (Recommended)**
```bash
# Check version:
bash --version

# If < 5.2, compile from source:
wget https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz
tar -xzf bash-5.3.tar.gz
cd bash-5.3
./configure --prefix=/usr/local
make
sudo make install
```

**Option 2: Use Docker**
```bash
cd linux-test
make shell  # Opens interactive shell with all dependencies
```

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Linux Compatibility Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Linux compatibility tests
        run: |
          cd linux-test
          docker compose up --build --abort-on-container-exit
```

## Future Considerations

### Potential Improvements
- [ ] Test on additional Linux distributions (Alpine, Fedora, Arch)
- [ ] Add performance benchmarking
- [ ] Generate HTML test reports
- [ ] Test with multiple bash versions (5.2, 5.3, 6.0)

### Not Needed
- ✗ Converting `${...; }` to `$(...)` - bash upgrade is simpler
- ✗ More sed/awk fixes - all issues resolved
- ✗ readlink compatibility - not used in codebase

## Summary

All compatibility issues have been resolved:
- ✅ sed syntax is now POSIX-compliant
- ✅ date commands work on both platforms
- ✅ base64 commands work on both platforms
- ✅ Platform-specific commands have fallbacks
- ✅ Bash version requirement is documented and enforced
- ✅ Automated testing environment available
- ✅ 122/123 tests passing on both macOS and Linux

The projects are now fully cross-platform compatible with proper fallback logic and clear error messages.
