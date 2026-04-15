

![rayvn](etc/rayvn6.png)
# rayvn

A shared library ecosystem for bash 5.3+.

## First Look

A minimal rayvn script:

```bash
#!/usr/bin/env rayvn-bash

usage() {
    show "Usage:" bold "greet NAME"
    bye "$@"
}

main() {
    init "$@"
    show primary "Hello, " bold "${greetName}" success "!"
}

init() {
    declare -g name
    while (( $# )); do
        case "$1" in
            -h | --help) usage ;;
            *) name="$1" ;;
        esac
        shift
    done
    [[ -n ${name} ]] || usage "NAME is required"
}

source rayvn.up
main "$@"
```

- `#!/usr/bin/env rayvn-bash` ensures bash 5.3+ regardless of system defaults.
- `source rayvn.up` bootstraps rayvn; `rayvn/core` library is always loaded automatically.
- All functions are defined before `source rayvn.up` so the file is fully parsed before `main` runs.
- Pass library names to load additional libraries: `source rayvn.up 'rayvn/spinner' 'rayvn/prompt'`.

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
The `rayvn/core` library is loaded by default. For convenience, `rayvn.up` accepts a list of library names to immediately `require`:
```bash
source rayvn.up 'rayvn/prompt'
```

`rayvn.up` automatically detects other rayvn projects via `PATH`, so:

```bash
source rayvn.up 'valt/archive' 

```
works if the `valt` project is in `PATH`. If a project is not in `PATH`, it can be added explicitly:

```bash
source rayvn.up 'myproject/mylibrary' --add myproject=/path/to/project
```

The `require` function can be called lazily, e.g. within a function.

Calling `require` multiple times for the same library will only load it on the first call, subsequent calls will just count the request.

To see public functions across all rayvn libraries, or in a specific one:
```bash
rayvn functions rayvn             # all libraries in the rayvn project
rayvn functions rayvn/core        # only rayvn/core
rayvn functions rayvn/core --all  # include private functions
```

Private functions have an underscore prefix and are **always** *subject to change*.

## Debugging rayvn applications

All rayvn applications support debug options via the `rayvn/debug` library. Use debug functions to generate diagnostic output that can be sent to a log file or separate terminal.

### Debug Options

| `--debug` | Enable debug logging, show log on exit |
| `--debug-new` | Enable debug logging with cleared log file, show log on exit |
| `--debug-out` | Send debug output to current terminal (uses `tty`) |
| `--debug-tty /dev/ttys001` | Send debug output to specific terminal device |
| `--debug-tty .` | Read tty path from `${HOME}/.debug.tty` file |

### Using Debug Functions

The debug options are processed by the `setDebug` function in `rayvn/core`. You can then use e.g.:

```bash
debug "processing item ${i} of ${total}"
debugVars myVar myArray myMap 
debugTraceOn # set -x directed to debug output
cmd1
cmd2
debugTraceOff # set +x
```

Debug output is only generated when debug mode is enabled via the command-line options.

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

The [BashSupport Pro](https://plugins.jetbrains.com/plugin/13841-bashsupport-pro) plugin is strongly
recommended — it provides full bash language support including syntax highlighting, code completion,
refactoring, and ShellCheck integration. It is far superior to the built-in shell script support.

After installing BashSupport Pro, register `rayvn-bash` as a recognized hashbang:

**Settings → Editor → File Types → Shell Script → Hashbangs** → add `rayvn-bash`

Then configure shared library sources and usage using your rayvn install location:

**Settings → Languages & Frameworks → BashSupport Pro → Shell Script Libraries**

- In **Library Sources**, add the `rayvn/lib` directory.
- In **Library Usage**, add the `rayvn/bin` and `rayvn/test` directories.

Do the same for any other rayvn projects you create or install.


### VS Code

VS Code doesn't support custom hashbang registration, but you can associate extensionless files in `bin/`
directories with the Shell Script language by adding this to your `settings.json`
(**File → Preferences → Settings → Open Settings JSON**):

```json
{
    "files.associations": {
        "*/bin/*": "shellscript"
    }
}
```

For linting, install the [ShellCheck extension](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck). It will use the `#!/usr/bin/env rayvn-bash` shebang to infer bash dialect automatically once the file is recognized as a shell script.

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
