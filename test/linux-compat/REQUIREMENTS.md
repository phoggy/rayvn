# System Requirements for rayvn, valt, and wardn

## Bash Version

**Minimum Required Version: Bash 5.2+**

These projects use modern bash features introduced in bash 5.2, specifically the `${...; }` command substitution syntax.

### Check Your Bash Version

```bash
bash --version
```

You should see something like:
```
GNU bash, version 5.2.0 (or higher)
```

### Platform-Specific Notes

#### macOS

Recent versions of macOS ship with bash 3.2 in `/bin/bash` for licensing reasons. You likely have a newer bash installed via Homebrew:

```bash
# Check Homebrew bash:
/usr/local/bin/bash --version  # Intel Macs
/opt/homebrew/bin/bash --version  # Apple Silicon Macs

# If you need to install/upgrade bash:
brew install bash

# Make sure your scripts use the newer bash:
which bash  # Should point to Homebrew's bash
```

#### Linux

Most modern Linux distributions ship with bash 5.0+, but some (like Ubuntu 22.04) ship with bash 5.1.16, which does **not** support the required syntax.

**Ubuntu/Debian:**
```bash
# Ubuntu 22.04 ships with bash 5.1.16 (incompatible)
# Ubuntu 24.04+ ships with bash 5.2+ (compatible)

# To upgrade on Ubuntu 22.04, compile from source:
wget https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz
tar -xzf bash-5.3.tar.gz
cd bash-5.3
./configure --prefix=/usr/local
make
sudo make install

# Verify installation:
/usr/local/bin/bash --version
```

**Fedora/RHEL/CentOS:**
```bash
# Fedora 36+ and RHEL 9+ ship with bash 5.2+
# Check with:
bash --version

# If needed, use dnf:
sudo dnf update bash
```

**Arch Linux:**
```bash
# Arch typically has the latest bash
# Update with:
sudo pacman -Syu bash
```

### Alternative: Use Docker

If you cannot upgrade bash on your Linux system, use the provided Docker test environment which includes bash 5.3:

```bash
cd linux-test
make shell  # Opens interactive shell with bash 5.3
```

## Core Utilities

The projects are compatible with both BSD and GNU versions of core utilities:
- ✓ sed (BSD and GNU)
- ✓ awk (BSD and GNU)
- ✓ date (BSD and GNU)
- ✓ base64 (BSD and GNU)
- ✓ find (BSD and GNU)

Platform detection and fallback logic ensures compatibility across macOS and Linux.

## Why This Syntax?

The `${...; }` syntax provides several benefits:
- More readable than `$(...)` for complex commands
- Allows internal formatting with spaces
- Consistent with the codebase's aesthetic

Example:
```bash
# Modern syntax (bash 5.2+):
result="${ command --flag value; }"

# Equivalent traditional syntax:
result="$(command --flag value)"
```

The additional spacing and semicolon make the code more readable, especially in complex nested scenarios.

## Migration Path

If you absolutely cannot use bash 5.2+, you would need to:
1. Replace all `${...; }` with `$(...)` throughout the codebase
2. Remove trailing semicolons and internal spaces
3. Test extensively as this affects hundreds of lines across multiple files

This is **not recommended** as it reduces code readability. Upgrading bash is the preferred solution.
