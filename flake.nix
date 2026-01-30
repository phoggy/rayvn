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
          version = "0.1.9";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install bin/
            install -Dm755 bin/rayvn "$out/bin/rayvn"
            install -Dm755 bin/rayvn.up "$out/bin/rayvn.up"

            # Install lib/
            mkdir -p "$out/lib"
            cp lib/*.sh "$out/lib/"

            # Install templates/
            mkdir -p "$out/templates"
            cp templates/* "$out/templates/"

            # Install etc/
            mkdir -p "$out/etc"
            cp -r etc/* "$out/etc/"

            # Install rayvn.pkg
            cp rayvn.pkg "$out/"

            # Wrap rayvn with runtime dependencies on PATH
            wrapProgram "$out/bin/rayvn" \
              --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}"

            # Wrap rayvn.up — it's sourced not executed, so we create a
            # wrapper script that sets up the environment then sources the real file.
            # However, rayvn.up uses BASH_SOURCE to resolve paths, so wrapping
            # would break it. Instead, we ensure the PATH is set by the caller
            # (the wrapped rayvn binary or the devShell). We leave rayvn.up unwrapped
            # but ensure the sibling layout (bin/ and lib/ under $out/) is preserved.

            runHook postInstall
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
