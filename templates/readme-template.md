# ${projectName}

A [rayvn](https://github.com/phoggy/rayvn) project.

## Installation

${projectName} can be installed with [Homebrew](https://brew.sh) or [Nix](https://nixos.org/): see
[Install with Homebrew](#install-with-homebrew) or [Install with Nix](#install-with-nix) below.

## Development

See the [rayvn](https://github.com/phoggy/rayvn) documentation for development details.

## Install with Homebrew

If you don't have Homebrew yet, install it first (see [Installing Homebrew](#installing-homebrew)), then:

```bash
brew tap rayvn-central/tap
brew trust --tap rayvn-central/tap
brew install ${projectName}
```

Homebrew installs formulae from taps other than its own only once you trust them, hence `brew trust`.

To upgrade to the latest version:

```bash
brew upgrade ${projectName}
```

### Installing Homebrew

**Mac and Linux:**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

On a Mac, this also installs Apple's Command Line Tools if they are missing; or download and run the `.pkg` installer
from [Homebrew's latest release](https://github.com/Homebrew/brew/releases/latest) instead. On Linux, first install the
tools it needs, e.g. on Debian or Ubuntu: `sudo apt-get install build-essential procps curl file git`.

**Windows:** Homebrew runs in Windows' own Linux environment, WSL. In PowerShell as administrator, run `wsl --install`,
restart, open Ubuntu from the Start menu, and follow the Linux step above inside it (see
[Install WSL](https://learn.microsoft.com/windows/wsl/install)). Windows files are under `/mnt/c` there.

When it finishes, the installer shows **Next steps**: run the commands it gives to add `brew` to your PATH, then open a
new terminal before continuing.

To remove Homebrew later, see [How do I uninstall Homebrew?](https://docs.brew.sh/FAQ#how-do-i-uninstall-homebrew).

## Install with Nix

If you don't have Nix yet, install it first (see [Installing Nix](#installing-nix)), then:

```bash
nix profile add github:${githubOwner}/${projectName}
```

To install a specific version:

```bash
nix profile add github:${githubOwner}/${projectName}/v0.1.0
```

To upgrade to the latest version:

```bash
nix profile upgrade ${projectName}
```

To run without installing:

```bash
nix run github:${githubOwner}/${projectName}
```

To build locally:

```bash
nix build
```

All dependencies are declared in the `flake.nix` file in the `runtimeDeps` list. New dependencies must be added there.

### Installing Nix

**Mac with Apple silicon:** Download and run the [Determinate Nix installer](https://dtr.mn/determinate-nix).

**Mac x86:**

```bash
curl -L https://nixos.org/nix/install | sh
```

**Linux:**

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

**Windows:** Nix runs in Windows' own Linux environment, WSL. In PowerShell as administrator, run `wsl --install`,
restart, open Ubuntu from the Start menu, and follow the Linux step above inside it (see
[Install WSL](https://learn.microsoft.com/windows/wsl/install)). Windows files are under `/mnt/c` there.

All installers create a `/nix` volume and take a few minutes to complete. Answer yes to any prompts and allow any
system dialogs that pop up. Once complete, open a new terminal before continuing.

If you used the Mac x86 installer, enable flakes:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

To remove Nix later: after the Determinate installer, run `/nix/nix-installer uninstall`; after the Mac x86 one, see
[Uninstalling Nix](https://nix.dev/manual/nix/latest/installation/uninstall).
