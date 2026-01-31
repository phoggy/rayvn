# ${projectName}

A [rayvn](https://github.com/phoggy/rayvn) project.

## Prerequisites

Requires [Nix](https://nixos.org/). To install:

```bash
curl -L https://nixos.org/nix/install | sh
```

## Installation

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
