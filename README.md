

![rayvn](etc/rayvn6.png)
# rayvn

A shared library ecosystem for bash 5.3+.

## First Look

```bash
#!/usr/bin/env rayvn-bash    # ensures bash 5.3+

# Boot rayvn & require two shared libraries ('rayvn/core' is automatic)

source rayvn.up 'rayvn/prompt' 'rayvn/spinner'

# Display styled text using the current theme and an extra newline

show primary "Hello" bold "Bold New" secondary "World" success glue "!" nl

# Display a header and subhead

header "Example 1" primary "using libraries 'rayvn/core' 'rayvn/prompt' 'rayvn/spinner'"

# Ask user to choose a spinner type

local types selectedIndex spinnerId
spinnerTypes types
choose 'What type of spinner would you like to see?' types selectedIndex || bye

# Start the chosen spinner, pretend to do some work and stop spinner

echo
startSpinner spinnerId "Doing something" ${types[selectedIndex]}
sleep 4
stopSpinner spinnerId " ${successCheckMark}"

# View themes (limited to 10 visible at a time), and change the current one if desired

require 'rayvn/theme'
echo
setTheme 10 || bye

# Generate a random 6 word passphrase using a library from the valt project (must be in PATH)

require 'valt/password'
header 2 "Generating a new passphrase"
generatePassphrase 6
```

## Installation

**With Homebrew:**

```bash
brew tap rayvn-central/brew
brew install rayvn
```

**With Nix:**

```bash
nix profile add github:phoggy/rayvn
```

To install a specific version:

```bash
nix profile add github:phoggy/rayvn/v0.2.4
```

To upgrade to the latest version:

```bash
nix profile upgrade rayvn
```

To run without installing:

```bash
nix run github:phoggy/rayvn
```

## Optional: RAM-backed Temp Storage

By default, rayvn uses a mode-600 temp directory for secure temporary files. For improved security,
RAM-backed temp storage can be configured to keep sensitive files out of persistent storage entirely.

On **Linux**, `/dev/shm` is used automatically — nothing to configure.

On **macOS 10.15+**, an optional tmpfs mount can be set up:

```bash
rayvn-tmp status     # show current strategy and instructions
rayvn-tmp install    # install LaunchDaemon to auto-mount at boot (requires sudo)
rayvn-tmp uninstall  # remove the LaunchDaemon (requires sudo)
```

## Developing With rayvn

rayvn provides two tools for working with projects:

- **[CLI](https://rayvn.ink/rayvn/cli)** — scaffolding, testing, linting, releasing, and more.
- **[API](https://rayvn.ink/rayvn/api)** — shared libraries your scripts can `require`.

> **Note:** the`rayvn build`, `rayvn test --nix`, and `rayvn release` CLI commands require Nix. See [Installing Nix](#installing-nix).

### Creating a project

`cd` to the desired parent directory, then:

```bash
rayvn new project my-name          # creates the project, a GitHub repo, and clones it
rayvn new project my-name --local  # local git repo only, no GitHub
```

From within the project, scaffold new components:

```bash
rayvn new script my-script    # adds bin/my-script
rayvn new library my-lib      # adds lib/my-lib.sh
rayvn new test my-test        # adds test/test-my-test.sh
```

All generated files are automatically staged in git.

## Using rayvn within scripts

All rayvn scripts use `#!/usr/bin/env rayvn-bash` as their shebang. `rayvn-bash` is a POSIX sh
wrapper that locates a suitable bash 5.3+ on the system (checking common locations and `PATH`,
with caching), then re-execs the script with it. This ensures scripts always run under the correct
bash version regardless of what `/bin/bash` or the shell's `PATH` provides.

The following line in your script will activate rayvn:
```bash
source rayvn.up
```

After that line executes, your script now has a `require` function which can then be used to load any installed shared library.
Nearly all scripts will want to include the `rayvn/core` library:
```bash
require 'rayvn/core'
```

For convenience, `rayvn.up` accepts a list of library names to immediately `require`:
```bash
source rayvn.up 'rayvn/core'
```

`rayvn.up` automatically detects other rayvn projects via `PATH`. If a project is not in `PATH`,
it can be added explicitly:
```bash
source rayvn.up 'rayvn/core' --add myproject=/path/to/project
```

The `require` function can be called lazily, e.g. within a function.

Calling `require` multiple times for the same library will only load it on the first call, subsequent calls will just count the request.

To see public functions across all rayvn libraries, or in a specific one:
```bash
rayvn functions rayvn             # all libraries in the rayvn project
rayvn functions rayvn/core        # only rayvn/core
rayvn functions rayvn/core --all  # include private functions
```

Private functions have an underscore prefix and are always *subject to change*.

## Debugging rayvn applications

All rayvn applications support debug options via the `rayvn/debug` library. Use debug functions to generate diagnostic output that can be sent to a log file or separate terminal.

### Debug Options

- `--debug` Enable debug logging, show log on exit
- `--debug-new` Enable debug logging with cleared log file, show log on exit
- `--debug-out` Send debug output to current terminal (uses `tty`)
- `--debug-tty /dev/ttys001` Send debug output to specific terminal device
- `--debug-tty .` Read tty path from `${HOME}/.debug.tty` file

### Using Debug Functions

After requiring `rayvn/debug` (automatically included with `rayvn/core`), you can use:

```bash
debugVars myVar1 myVar2
debug "processing item ${i} of ${total}"

```

Debug output is only generated when debug mode is enabled via command-line options.

### Example

Direct TTY specification:
```bash
# Terminal 1: Find your TTY
$ tty
/dev/ttys001

# Terminal 2: Run your script with debug output to Terminal 1
$ my-rayvn-app --debug-tty /dev/ttys001
```

Using .debug.tty file:
```bash
# Terminal 1: Write your tty to the file
$ tty > ~/.debug.tty

# Terminal 2: Run your script
$ my-rayvn-app --debug-tty .
```

## IDE Configuration

### IntelliJ IDEA

To enable bash syntax highlighting and tooling for rayvn scripts, add `rayvn-bash` as a recognized hashbang:

**Settings → Editor → File Types → Shell Script → Hashbangs** → add `rayvn-bash`

## Installing Nix

*Mac with Apple silicon:* Download and run the [Determinate Nix installer](https://dtr.mn/determinate-nix).

*Mac x86:*
```bash
curl -L https://nixos.org/nix/install | sh
```

*Linux:*
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

All installers create a `/nix` volume and take a few minutes to complete. Answer yes to any
prompts and allow any system dialogs that pop up. Once complete, open a new terminal before
continuing.

If you used the Mac x86 installer, enable flakes:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```
