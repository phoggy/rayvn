# ${projectName}

A [rayvn](https://github.com/phoggy/rayvn) project.

## Prerequisites

Requires [Nix](https://nixos.org/).

**Mac with Apple silicon:** Download and run the [Determinate Nix installer](https://dtr.mn/determinate-nix).

**Mac x86:**

```bash
curl -L https://nixos.org/nix/install | sh
```

**Linux:**

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

## Installation

```bash
nix profile add github:phoggy/${projectName}
```

To install a specific version:

```bash
nix profile add github:phoggy/${projectName}/v0.1.0
```

To upgrade to the latest version:

```bash
nix profile upgrade ${projectName}
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
