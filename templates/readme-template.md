# ${projectName}

A [rayvn](https://github.com/phoggy/rayvn) project.

## Prerequisites

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

## Installation

```bash
nix profile install github:phoggy/${projectName}
```

To run without installing:

```bash
nix run github:phoggy/${projectName}
```

To build locally:

```bash
nix build
```

All dependencies are declared in the `flake.nix` file in the `runtimeDeps` list. New dependencies must be added there.

## Development

See the [rayvn](https://github.com/phoggy/rayvn) documentation for development details.
