{
  description = "rayvn - Shared bash library system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Runtime dependencies
        runtimeDeps = [
          pkgs.bash
          pkgs.gawk
          pkgs.gh
        ];

        rayvn = pkgs.stdenv.mkDerivation {
          pname = "rayvn";
          version = "0.2.4";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install bin/
            install -Dm755 bin/rayvn "$out/bin/rayvn"
            install -Dm755 bin/rayvn.up "$out/bin/rayvn.up"

            # Install lib/
            mkdir -p "$out/share/rayvn/lib"
            cp lib/*.sh "$out/share/rayvn/lib/"

            # Install templates/
            mkdir -p "$out/share/rayvn/templates"
            cp templates/* "$out/share/rayvn/templates/"

            # Install etc/
            mkdir -p "$out/share/rayvn/etc"
            cp -r etc/* "$out/share/rayvn/etc/"

            # Install rayvn.pkg with version metadata
            # Remove existing version properties, then append current values from flake
            sed '/^projectVersion=/d; /^projectReleaseDate=/d; /^projectFlake=/d; /^projectBuildRev=/d; /^projectNixpkgsRev=/d' \
                rayvn.pkg > "$out/share/rayvn/rayvn.pkg"
            cat >> "$out/share/rayvn/rayvn.pkg" <<EOF

# Version metadata (added by Nix build)
projectVersion='$version'
projectReleaseDate='$(date "+%Y-%m-%d %H:%M:%S %Z")'
projectFlake='github:phoggy/rayvn/v$version'
projectBuildRev='${self.shortRev or "dev"}'
projectNixpkgsRev='${nixpkgs.shortRev}'
EOF

            # Wrap rayvn with runtime dependencies on PATH.
            # Include $out/bin so that 'source rayvn.up' (PATH lookup) finds
            # rayvn.up in the same store path, and rayvn.up can resolve the
            # project root via BASH_SOURCE.
            wrapProgram "$out/bin/rayvn" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimeDeps}"

            # Wrap rayvn.up — it's sourced not executed, so we create a
            # wrapper script that sets up the environment then sources the real file.
            # However, rayvn.up uses BASH_SOURCE to resolve paths, so wrapping
            # would break it. Instead, we ensure the PATH is set by the caller
            # (the wrapped rayvn binary or the devShell). We leave rayvn.up unwrapped
            # but ensure the sibling layout (bin/ and lib/ under $out/) is preserved.

            runHook postInstall
          '';

          # patchShebangs rewrites #!/usr/bin/env bash to the non-interactive
          # bash, which lacks builtins like compgen. Restore the shebangs so
          # they resolve via PATH, where the wrapper provides bash-interactive.
          postFixup = ''
            for f in "$out/bin/.rayvn-wrapped" "$out/bin/rayvn.up" "$out/share/rayvn/lib/"*.sh; do
              if [ -f "$f" ]; then
                sed -i "1s|^#\\!.*/bin/bash.*|#!/usr/bin/env bash|" "$f"
              fi
            done
          '';

          meta = with pkgs.lib; {
            description = "Shared bash library system for managing executables and libraries";
            homepage = "https://github.com/phoggy/rayvn";
            license = licenses.gpl3Only;
            platforms = platforms.unix;
          };
        };
      in
      {
        packages = {
          default = rayvn;
          rayvn = rayvn;
        };

        apps = {
          default = {
            type = "app";
            program = "${rayvn}/bin/rayvn";
          };
          rayvn = {
            type = "app";
            program = "${rayvn}/bin/rayvn";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ [
            pkgs.shellcheck
          ];
          shellHook = ''
            export PATH="${self}/bin:$PATH"
            echo "rayvn dev shell ready"
          '';
        };
      }
    );
}
