![My Logo](etc/rayvn.png)

# rayvn
/ˈreɪ.vən/

A bash shared library manager and a set of shared libraries.

### Prerequisites

Requires [Nix](https://nixos.org/). To install on Mac with Apple silicon or Linux:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

To install on Mac x86:

```bash
curl -L https://nixos.org/nix/install | sh
```

Both installers create a `/nix` volume and take a few minutes to complete. Answer yes to any
prompts and allow any system dialogs that pop up. Once complete, open a new terminal before
continuing.

If you used the x86 installer, enable flakes:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

### Installation

```bash
nix profile install github:phoggy/rayvn
```

To run without installing:

```bash
nix run github:phoggy/rayvn
```

To build locally:

```bash
nix build
```

# Developing With rayvn

All dependencies are declared in the `flake.nix` file in the `runtimeDeps` list. New dependencies must be added there.

## Using rayvn within scripts

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

The `require` function can be called lazily, e.g. within a function.

Calling `require` multiple times for the same library will only load it on the first call, subsequent calls will just count the request.

To see the set of public functions available in a library:
```bash
ravyn list 'rayvn/core'
```

Private functions are any that have an underscore prefix. Private functions are always subject to change, so *should not be used!*

## Debugging rayvn applications

All rayvn applications support debug options via the `rayvn/debug` library. Use debug functions to generate diagnostic output that can be sent to a log file or separate terminal.

### Debug Options

- `--debug` - Enable debug logging, show output on exit
- `--debug-new` - Enable debug logging with cleared log file, show output on exit
- `--debug-out` - Send debug output to current terminal (uses `tty`)
- `--debug-tty /dev/ttys001` - Send debug output to specific terminal device
- `--debug-tty .` - Read tty path from `${HOME}/.debug.tty` file

### Using Debug Functions

After requiring `rayvn/debug` (automatically included with `rayvn/core`), you can use:

```bash
debug "variable value: ${myVar}"
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

## Developing rayvn projects

First `cd` to the directory where you want your project to live, then:
```bash
$ rayvn create project "my-name"
```
This will generate a skeleton project.
